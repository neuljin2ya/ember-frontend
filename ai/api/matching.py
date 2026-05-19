"""
매칭 계산 API 엔드포인트.

POST /api/matching/calculate
  - Spring 에서 기준 사용자 임베딩 + 이상형 키워드 + 후보 목록(임베딩 + 퍼스널리티 키워드) 수신
  - 점수 계산은 services/matching_score_service.py 의 v2 알고리즘에 위임 (M8)
  - X-Internal-Key 헤더 검증 (공통 deps.verify_internal_key)
  - FastAPI DB 직접 쓰기 금지 원칙 준수 (설계서 9.3§)

POST /api/matching/embed
  - 텍스트 목록 → KoSimCSE float16 임베딩 → Base64 반환
  - Spring lazy 생성: 기준 사용자 user_vector 없을 때 이상형 키워드 임베딩 요청
"""
from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, HTTPException, status

from api.deps import verify_internal_key
from schemas.matching import (
    CandidatePayload,
    CandidateScore,
    EmbedRequest,
    EmbedResponse,
    MatchingCalculateRequest,
    MatchingCalculateResponse,
    ScoreBreakdown,
)
from services import kosimcse_service, matching_score_service

logger = structlog.get_logger(__name__)

router = APIRouter(dependencies=[Depends(verify_internal_key)])


# ── 엔드포인트 ────────────────────────────────────────────────────────────────

@router.post(
    "/matching/calculate",
    response_model=MatchingCalculateResponse,
    summary="매칭 점수 계산 (v2 — M8 변별력 강화)",
    description=(
        "기준 사용자와 후보 목록에 대해 매칭 점수를 계산한다.\n\n"
        "**v2 알고리즘 (M8)**\n"
        "- keyword_score = max(Jaccard, 0.85 × semantic)  (의미 유사 키워드 반영)\n"
        "- cosine_score = stretch_cosine((cos+1)/2)        (한국어 분포 기반 0.5~0.95 → 0~1 stretch)\n"
        "- final = 0.55 × keyword_score + 0.45 × cosine_score\n"
        "- 코사인 결손 시 keyword 항 단독 (가중치 확장)\n\n"
        "기준 사용자 임베딩(userEmbedding)이 null 이면 idealKeywords 를 join → KoSimCSE 임베딩 동적 생성."
    ),
)
def calculate_matching(
    body: MatchingCalculateRequest,
) -> MatchingCalculateResponse:
    """
    매칭 점수 계산 처리 로직.

    Steps:
      1. X-Internal-Key 헤더 검증 (router-level Depends)
      2. 기준 사용자 임베딩 확보:
         a. userEmbedding 있으면 사용
         b. 없고 idealKeywords 있으면 join → KoSimCSE 임베딩 동적 생성
         c. 둘 다 없으면 keyword 항만으로 점수 산출 (cosine 항 0)
      3. 기준 사용자 임베딩을 1회 디코드 + L2 정규화 → 후보 비교에 재사용
      4. 각 후보에 대해 matching_score_service.compute_matching_score() 호출
      5. matchingScore 내림차순 정렬 후 반환
    """
    logger.info(
        "매칭 계산 요청 (v2)",
        userId=body.userId,
        candidateCount=len(body.candidates),
        hasUserEmbedding=body.userEmbedding is not None,
        idealKeywordCount=len(body.idealKeywords),
    )

    # ── 기준 사용자 임베딩 확보 ──────────────────────────────────────────────
    user_embedding_b64: str | None = body.userEmbedding

    if user_embedding_b64 is None and body.idealKeywords:
        # 이상형 키워드 join → KoSimCSE 임베딩 동적 생성
        joined_text = " ".join(body.idealKeywords)
        logger.info(
            "기준 사용자 임베딩 동적 생성",
            userId=body.userId,
            keywordCount=len(body.idealKeywords),
        )
        user_embedding_b64 = kosimcse_service.embed_to_base64(joined_text)
    elif user_embedding_b64 is None:
        logger.warning(
            "기준 사용자 임베딩 + 이상형 키워드 모두 없음 — keyword 항만으로 점수 산출",
            userId=body.userId,
        )

    # ── 기준 사용자 정규화 벡터 1회 디코드 (후보 비교에 재사용) ───────────────
    user_normalized_vec = (
        kosimcse_service.base64_to_normalized_vec(user_embedding_b64)
        if user_embedding_b64
        else None
    )

    # ── 후보별 점수 계산 ─────────────────────────────────────────────────────
    scores: list[CandidateScore] = []

    for candidate in body.candidates:
        try:
            score_result = matching_score_service.compute_matching_score(
                user_normalized_vec=user_normalized_vec,
                ideal_keywords=body.idealKeywords,
                candidate_embedding_b64=candidate.embedding,
                candidate_keywords=candidate.personalityKeywords,
            )
        except Exception as e:
            # 개별 후보 계산 실패 시 해당 후보 스킵 (전체 중단 방지)
            logger.warning(
                "후보 점수 계산 실패 — 스킵",
                candidateId=candidate.userId,
                error=str(e),
            )
            continue

        scores.append(
            CandidateScore(
                userId=candidate.userId,
                matchingScore=score_result.matching_score,
                breakdown=ScoreBreakdown(
                    keywordOverlap=score_result.keyword_overlap,
                    cosineSimilarity=score_result.cosine_similarity,
                    keywordSemantic=score_result.keyword_semantic,
                    cosineRaw=score_result.cosine_raw,
                    cosineAvailable=score_result.cosine_available,
                ),
            )
        )

    # matchingScore 내림차순 정렬
    scores.sort(key=lambda s: s.matchingScore, reverse=True)

    logger.info(
        "매칭 계산 완료 (v2)",
        userId=body.userId,
        scoredCount=len(scores),
        topScore=scores[0].matchingScore if scores else None,
        bottomScore=scores[-1].matchingScore if scores else None,
    )

    return MatchingCalculateResponse(scores=scores)


@router.post(
    "/matching/embed",
    response_model=EmbedResponse,
    summary="KoSimCSE 텍스트 임베딩",
    description=(
        "텍스트 목록을 KoSimCSE로 임베딩해 Base64 인코딩 float16 bytes 목록을 반환한다.\n\n"
        "Spring이 기준 사용자의 user_vector가 없을 때 이상형 키워드 임베딩을 위해 호출."
    ),
)
def embed_texts(
    body: EmbedRequest,
) -> EmbedResponse:
    """
    KoSimCSE 임베딩 처리 로직.

    Steps:
      1. X-Internal-Key 헤더 검증 (router-level Depends)
      2. 각 텍스트를 KoSimCSE mean pooling 임베딩
      3. float32 → float16 → Base64 인코딩 후 반환
    """
    if not body.texts:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="texts 목록이 비어있습니다.",
        )

    logger.info("임베딩 요청", count=len(body.texts))

    try:
        embeddings_b64 = kosimcse_service.embed_batch_to_base64(body.texts)
    except Exception as e:
        logger.error("임베딩 실패", error=str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"임베딩 처리 중 오류가 발생했습니다: {e}",
        )

    logger.info("임베딩 완료", count=len(embeddings_b64))
    return EmbedResponse(embeddings=embeddings_b64)
