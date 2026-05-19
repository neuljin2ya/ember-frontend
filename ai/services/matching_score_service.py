"""
매칭 점수 계산 — Semantic Matrix + Temperature Scaling 버전

알고리즘:
  1. 이상형 키워드 10개 설명문을 KoSimCSE로 임베딩
  2. 33개 원천 태그를 KoSimCSE로 임베딩
  3. 10×33 Semantic Matrix 생성 (코사인 유사도)
  4. 행별 Min-Max 정규화 + Temperature 2.0
  5. 후보 유저의 33차원 프로필 벡터와 코사인 유사도 → 키워드별 점수
  6. 이상형 1순위×3 + 2순위×2 + 3순위×1 가중합산 → 최종 점수

기존 api/matching.py 라우터와의 호환:
  - compute_matching_score() 함수 시그니처를 기존과 동일하게 유지
  - MatchingScore 데이터클래스의 필드명도 기존 ScoreBreakdown과 호환
"""
from __future__ import annotations

import logging
from dataclasses import dataclass
from functools import lru_cache
from typing import Optional

import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

from services import kosimcse_service

logger = logging.getLogger(__name__)

# ── 이상형 키워드 + 설명문 (v2 확정) ─────────────────────────────────────────

IDEAL_KEYWORDS = [
    "안정적인 사람", "긍정적인 사람", "따뜻한 사람", "공감적인 사람", "다정한 사람",
    "솔직한 사람", "성실한 사람", "도전적인 사람", "자유로운 사람", "깊이 있는 사람"
]

IDEAL_DESCRIPTIONS = [
    "매일 편안하고 안정적인 감정을 느끼며, 불안이나 걱정보다는 신뢰와 평온함이 일상에 가득한 사람",
    "즐거움과 기대, 설렘을 자주 느끼고, 일상에서 긍정적인 에너지와 뿌듯함을 표현하는 사람",
    "감성적이고 상대를 배려하며, 편안함과 신뢰를 바탕으로 따뜻한 감정을 전하는 사람",
    "타인의 슬픔과 외로움, 걱정에 함께 공감하며, 상대의 감정을 이해하고 배려하는 사람",
    "상대를 배려하면서 천천히 가까워지고, 편안함과 신뢰 속에서 감성적으로 다가오는 사람",
    "직설적으로 자기 생각을 표현하고, 갈등 상황에서도 회피하지 않고 솔직하게 맞서는 사람",
    "계획적이고 진지하며, 꾸준히 목표를 세우고 성실하게 실행하며 신뢰를 쌓아가는 사람",
    "도전적이고 활동적이며, 새로운 경험에 대한 기대와 설렘을 자주 느끼는 사람",
    "즉흥적이고 활동적이며, 계획에 얽매이지 않고 자유롭게 즐거움과 설렘을 추구하는 사람",
    "진지하고 편안한 분위기 속에서 신뢰를 바탕으로 자기 내면을 깊이 성찰하며, 갈등보다는 조용한 공감을 선호하고 슬픔도 담담하게 받아들이는 사람"
]

# 33개 원천 태그 (프로필 벡터 차원 순서)
RAW_TAGS = [
    "즐거움", "뿌듯함", "신뢰", "편안함", "걱정", "긴장", "놀람", "당황",
    "슬픔", "외로움", "거부감", "불쾌감", "짜증", "억울함", "기대", "설렘",
    "즉흥적인", "계획적인", "안정추구형", "도전적인", "집콕선호", "활동적인",
    "갈등회피", "갈등직면", "상대배려중심", "자기표현중심", "점진적친밀형", "초고속친밀형",
    "해결보단공감", "공감보단해결",
    "진지한", "직설적인", "감성적인"
]

TEMPERATURE = 2.0

# 이상형 순위별 가중치
RANK_WEIGHTS = [3.0, 2.0, 1.0, 0.5]


# ── Semantic Matrix (앱 시작 시 1회 생성, 캐시) ──────────────────────────────

@lru_cache(maxsize=1)
def _get_semantic_matrix() -> np.ndarray:
    """
    10×33 Semantic Matrix 생성:
      1. 이상형 설명문 10개 임베딩
      2. 원천 태그 33개 임베딩
      3. 코사인 유사도 행렬
      4. 행별 Min-Max 정규화 + Temperature Scaling
    """
    # KoSimCSE 임베딩
    ideal_vecs = [kosimcse_service.embed_vec_cached(desc) for desc in IDEAL_DESCRIPTIONS]
    tag_vecs = [kosimcse_service.embed_vec_cached(tag) for tag in RAW_TAGS]

    ideal_mat = np.stack(ideal_vecs)  # (10, 768)
    tag_mat = np.stack(tag_vecs)      # (33, 768)

    # 코사인 유사도 행렬 (10×33)
    raw_matrix = cosine_similarity(ideal_mat, tag_mat)

    # 행별 Min-Max 정규화 + Temperature Scaling
    enhanced = np.zeros_like(raw_matrix)
    for i in range(raw_matrix.shape[0]):
        row = raw_matrix[i]
        row_min, row_max = row.min(), row.max()
        if row_max - row_min > 0:
            normalized = (row - row_min) / (row_max - row_min)
        else:
            normalized = np.zeros_like(row)
        enhanced[i] = np.power(normalized, TEMPERATURE)

    logger.info("Semantic Matrix 생성 완료 (10×33, temp=%.1f)", TEMPERATURE)
    return enhanced


def warmup_semantic_matrix() -> None:
    """main.py lifespan에서 호출하여 Semantic Matrix를 미리 생성."""
    _get_semantic_matrix()


# ── 프로필 벡터 기반 키워드별 점수 계산 ───────────────────────────────────────

def compute_keyword_scores(profile_vec: np.ndarray) -> dict[str, float]:
    """
    33차원 프로필 벡터 → 10개 이상형 키워드별 매칭 점수 (0~100%).

    Args:
        profile_vec: 33차원 누적 프로필 벡터 (각 값 0.0~1.0)

    Returns:
        {"안정적인 사람": 72.5, "긍정적인 사람": 65.3, ...}
    """
    sm = _get_semantic_matrix()
    scores = {}
    for i, kw in enumerate(IDEAL_KEYWORDS):
        sim = cosine_similarity([sm[i]], [profile_vec])[0][0]
        scores[kw] = round(sim * 100, 1)
    return scores


# ── 결과 컨테이너 (기존 ScoreBreakdown 호환) ─────────────────────────────────

@dataclass(frozen=True)
class MatchingScore:
    """매칭 점수 결과 (기존 api/matching.py 응답과 호환)."""
    matching_score: float
    keyword_overlap: float        # 이상형 키워드 매칭률 (가중합산 기반)
    keyword_semantic: float       # 사용하지 않음 (호환 필드, 0.0)
    cosine_similarity: float      # 최종 가중합산 점수 (0~1)
    cosine_raw: float             # 사용하지 않음 (호환 필드, 0.0)
    cosine_available: bool        # 항상 True (Semantic Matrix 기반)


# ── 메인 점수 계산 (기존 api/matching.py 호출 시그니처 유지) ──────────────────

def compute_matching_score(
    user_normalized_vec: Optional[np.ndarray],
    ideal_keywords: list[str],
    candidate_embedding_b64: Optional[str],
    candidate_keywords: list[str],
) -> MatchingScore:
    """
    기존 api/matching.py의 호출 시그니처를 유지하면서
    내부는 Semantic Matrix + 가중합산 알고리즘으로 교체.

    실제로 사용하는 파라미터:
      - ideal_keywords: 기준 사용자의 이상형 키워드 (최대 3개)
      - candidate_keywords: 후보의 personality 키워드 목록

    candidate_keywords를 33차원 프로필 벡터로 변환하여 매칭 점수 산출.

    NOTE: 실서비스에서는 Spring이 후보의 누적 프로필 벡터를 전달해야 함.
          현재는 candidate_keywords(텍스트)를 받아서 프로필을 즉석 생성하는
          임시 로직. 추후 Spring에서 프로필 벡터를 직접 전달하면 교체 필요.
    """
    sm = _get_semantic_matrix()

    # 후보의 personality_keywords → 간이 프로필 벡터 생성
    # (실서비스에서는 DB에서 누적 프로필 벡터를 조회하여 전달)
    candidate_profile = _keywords_to_profile(candidate_keywords)

    # 이상형 키워드별 점수 산출
    all_scores = compute_keyword_scores(candidate_profile)

    # 이상형 순위별 가중합산
    weighted_sum = 0.0
    weight_total = 0.0
    keyword_hits = 0

    for rank, kw in enumerate(ideal_keywords):
        if kw not in all_scores:
            continue
        w = RANK_WEIGHTS[rank] if rank < len(RANK_WEIGHTS) else 0.5
        score = all_scores[kw]
        weighted_sum += score * w
        weight_total += w
        if score >= 50.0:  # 50% 이상이면 "매칭됨"으로 간주
            keyword_hits += 1

    final_score = weighted_sum / weight_total / 100.0 if weight_total > 0 else 0.0
    keyword_overlap = keyword_hits / len(ideal_keywords) if ideal_keywords else 0.0

    return MatchingScore(
        matching_score=round(min(max(final_score, 0.0), 1.0), 6),
        keyword_overlap=round(keyword_overlap, 6),
        keyword_semantic=0.0,          # 호환 필드
        cosine_similarity=round(final_score, 6),
        cosine_raw=0.0,                # 호환 필드
        cosine_available=True,
    )


# ── 임시: 키워드 목록 → 간이 33차원 프로필 벡터 ──────────────────────────────

def _keywords_to_profile(keywords: list[str]) -> np.ndarray:
    """
    후보의 personality_keywords(텍스트 목록)를 33차원 프로필 벡터로 변환.

    임시 로직: 키워드가 RAW_TAGS에 포함되면 해당 차원을 1.0으로 설정.
    포함되지 않으면 KoSimCSE로 가장 유사한 태그를 찾아 매핑.

    실서비스에서는 Spring이 유저의 누적 프로필 벡터를 직접 전달하므로
    이 함수는 사용되지 않음.
    """
    profile = np.full(len(RAW_TAGS), 0.1)

    for kw in keywords:
        # 정확히 일치하는 태그가 있으면 활성화
        if kw in RAW_TAGS:
            profile[RAW_TAGS.index(kw)] = 0.9
            continue

        # 유사 태그 매핑 (간이)
        kw_vec = kosimcse_service.embed_vec_cached(kw)
        best_idx = -1
        best_sim = -1.0
        for j, tag in enumerate(RAW_TAGS):
            tag_vec = kosimcse_service.embed_vec_cached(tag)
            sim = float(np.dot(kw_vec, tag_vec))
            if sim > best_sim:
                best_sim = sim
                best_idx = j
        if best_idx >= 0 and best_sim > 0.4:
            profile[best_idx] = max(profile[best_idx], 0.7)

    return profile
