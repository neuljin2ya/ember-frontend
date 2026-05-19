"""
KcELECTRA 기반 일기 분석 서비스 — Multi-Head 분류기 버전

입력: 일기 원문 (str)
출력: AnalysisResult (summary + category + tags 33개)

태그 체계 (33차원):
  - 감정 16개 (이진: 0/1)
  - 생활성향 3축 (삼진: -1/0/+1 → 6개 태그)
  - 관계성향 4축 (삼진: -1/0/+1 → 8개 태그)
  - 톤 3개 (이진: 0/1)

MQ Consumer (workers/mq_consumer.py) 에서 호출하는 인터페이스:
  await kcelectra_service.analyze_diary(content) → AnalysisResult
"""
from __future__ import annotations

import logging
import re

import numpy as np
import torch

from config import MIN_CONTENT_LENGTH
from models import get_kcelectra, EMOTION_TAGS, LIFESTYLE_AXES, RELATIONSHIP_AXES, TONE_TAGS
from schemas.messages import AnalysisResult, AnalysisTag
from services.gemini_summary_service import generate_summary

logger = logging.getLogger(__name__)

# ── 삼진 태그 → 레이블 매핑 ──────────────────────────────────────────────────

LIFESTYLE_LABELS = {
    "계획성": {-1: "즉흥적", 0: "계획성 중립", 1: "계획적"},
    "도전성": {-1: "안정추구", 0: "도전성 중립", 1: "도전적"},
    "활동성": {-1: "집콕선호", 0: "활동성 중립", 1: "활동적"},
}

RELATIONSHIP_LABELS = {
    "갈등대응방식": {-1: "갈등회피", 0: "갈등대응 중립", 1: "갈등직면"},
    "표현방향": {-1: "상대배려중심", 0: "표현방향 중립", 1: "자기표현중심"},
    "친밀속도": {-1: "점진적친밀형", 0: "친밀속도 중립", 1: "초고속친밀형"},
    "갈등해결방식": {-1: "해결보단공감", 0: "갈등해결 중립", 1: "공감보단해결"},
}

# ── 카테고리 분류 (규칙 기반) ─────────────────────────────────────────────────

CATEGORY_KEYWORDS = {
    "TRAVEL": ["여행", "관광", "해외", "비행기", "호텔", "숙소", "배낭", "일정"],
    "FOOD": ["맛집", "요리", "음식", "레시피", "먹방", "카페", "디저트", "식당"],
    "RELATIONSHIP": ["연애", "이별", "고백", "사랑", "데이트", "짝사랑", "커플"],
    "WORK": ["회사", "업무", "프로젝트", "직장", "팀장", "회의", "야근", "출근", "퇴근"],
}


def _classify_category(content: str) -> str:
    """키워드 매칭 기반 카테고리 분류. 매칭 없으면 DAILY."""
    scores = {}
    for cat, keywords in CATEGORY_KEYWORDS.items():
        scores[cat] = sum(1 for kw in keywords if kw in content)
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "DAILY"


# ── warmup (main.py lifespan 호환) ───────────────────────────────────────────

def warmup_anchors() -> None:
    """main.py lifespan에서 호출. Multi-Head 모델은 앵커 불필요, 모델 로드만 확인."""
    get_kcelectra()
    logger.info("KcELECTRA Multi-Head 모델 warmup 완료")


# ── 메인 분석 함수 ────────────────────────────────────────────────────────────

async def analyze_diary(content: str) -> AnalysisResult:
    """
    일기 본문 → Multi-Head 분류기 추론 → AnalysisResult 반환.

    MQ Consumer와의 인터페이스 유지:
      - 입력: content (str)
      - 출력: AnalysisResult(summary, category, tags)
      - 에러: ValueError (길이 부족)
    """
    # 1. 길이 검증
    if len(content) < MIN_CONTENT_LENGTH:
        raise ValueError(
            f"일기 본문이 최소 글자 수({MIN_CONTENT_LENGTH}자)에 미달합니다. "
            f"현재 길이: {len(content)}자"
        )

    # 2. 토크나이징 + 추론
    tok, mdl = get_kcelectra()
    encoding = tok(
        content, max_length=512, padding='max_length',
        truncation=True, return_tensors='pt'
    )

    with torch.no_grad():
        e_logits, l_logits, r_logits, t_logits = mdl(
            encoding['input_ids'], encoding['attention_mask']
        )

    # 3. 감정 태그 (이진, threshold=0.5)
    e_probs = torch.sigmoid(e_logits).cpu().numpy()[0]
    tags: list[AnalysisTag] = []

    for i, tag_name in enumerate(EMOTION_TAGS):
        score = float(e_probs[i])
        if score > 0.5:
            tags.append(AnalysisTag(type="EMOTION", label=tag_name, score=round(score, 4)))

    # 4. 생활성향 (삼진 → 레이블 변환)
    l_probs = torch.softmax(l_logits, dim=-1).cpu().numpy()[0]
    for i, axis in enumerate(LIFESTYLE_AXES):
        pred_class = int(l_probs[i].argmax())
        value = pred_class - 1  # 0,1,2 → -1,0,+1
        label = LIFESTYLE_LABELS[axis][value]
        confidence = float(l_probs[i][pred_class])
        tags.append(AnalysisTag(type="LIFESTYLE", label=label, score=round(confidence, 4)))

    # 5. 관계성향 (삼진 → 레이블 변환)
    r_probs = torch.softmax(r_logits, dim=-1).cpu().numpy()[0]
    for i, axis in enumerate(RELATIONSHIP_AXES):
        pred_class = int(r_probs[i].argmax())
        value = pred_class - 1
        label = RELATIONSHIP_LABELS[axis][value]
        confidence = float(r_probs[i][pred_class])
        tags.append(AnalysisTag(type="RELATIONSHIP_STYLE", label=label, score=round(confidence, 4)))

    # 6. 톤 태그 (이진, threshold=0.5)
    t_probs = torch.sigmoid(t_logits).cpu().numpy()[0]
    for i, tag_name in enumerate(TONE_TAGS):
        score = float(t_probs[i])
        if score > 0.5:
            tags.append(AnalysisTag(type="TONE", label=tag_name, score=round(score, 4)))

    # 7. summary (Gemini API) + category (규칙 기반)
    summary = await generate_summary(content)
    category = _classify_category(content)

    return AnalysisResult(
        summary=summary,
        category=category,
        tags=tags,
    )
