"""
Gemini API 기반 일기 주제 요약 서비스

입력: 일기 원문 (str)
출력: 50자 이내 한국어 주제 요약 (str)

사용 모델: gemini-2.5-flash (유료 티어, Cloud Console 키)
Fallback: API 실패 시 기존 규칙 기반 요약(앞부분 자르기)으로 대체
"""
from __future__ import annotations

import os
import logging
import re
import aiohttp

logger = logging.getLogger(__name__)

# ── Gemini API 설정 ──────────────────────────────────────────────────────────

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/v1beta/models/"
    f"{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
)

SUMMARY_PROMPT = """아래 일기의 핵심 내용을 한국어 한 문장(30~50자)으로 요약하세요.

규칙:
1. 반드시 30자 이상 50자 이하의 완전한 문장으로 작성
2. 구체적인 행동과 감정을 모두 포함할 것
3. "~한 하루", "~에 대한 일기" 같은 막연한 표현 절대 금지
4. 따옴표나 부가 설명 없이 요약문만 출력

좋은 예시:
- 즉흥으로 부산행 KTX 타고 회 먹으며 자유를 만끽한 날
- 후배의 실수를 감싸주며 리더로서의 책임감을 되새김
- 오래된 친구와 가치관 차이를 느끼며 관계를 돌아봄
- 볼더링 첫 도전에서 벽을 넘으며 성취감과 짜릿함을 느낌

일기:
{content}"""


# ── Fallback: 규칙 기반 요약 ──────────────────────────────────────────────────

_SENTENCE_SPLIT = re.compile(r"(?<=[.!?。])\s+")


def _fallback_summary(content: str, max_chars: int = 50) -> str:
    """Gemini API 실패 시 기존 방식 — 본문 앞부분 1~2문장 50자 이내 추출."""
    trimmed = content.strip()
    if not trimmed:
        return ""
    sentences = _SENTENCE_SPLIT.split(trimmed)
    sentences = [s.strip() for s in sentences if s.strip()]
    if not sentences:
        return trimmed[:max_chars]

    candidate = sentences[0]
    if len(candidate) < 10 and len(sentences) > 1:
        candidate = f"{candidate} {sentences[1]}".strip()

    if len(candidate) <= max_chars:
        return candidate

    cut = candidate[:max_chars]
    last_space = cut.rfind(" ")
    if last_space >= int(max_chars * 0.6):
        return cut[:last_space]
    return cut


# ── Gemini API 호출 ──────────────────────────────────────────────────────────

async def generate_summary(content: str, max_chars: int = 50) -> str:
    """
    Gemini API로 일기 주제 요약 생성.

    성공 시: Gemini가 생성한 50자 이내 요약문 반환
    실패 시: fallback(앞부분 자르기) 반환 — 서비스 중단 방지
    """
    try:
        payload = {
            "contents": [
                {
                    "parts": [
                        {"text": SUMMARY_PROMPT.format(content=content)}
                    ]
                }
            ],
            "generationConfig": {
                "temperature": 0.7,
                "maxOutputTokens": 200,
                "thinkingConfig": {"thinkingBudget": 0},
            },
        }

        async with aiohttp.ClientSession() as session:
            async with session.post(
                GEMINI_URL,
                json=payload,
                timeout=aiohttp.ClientTimeout(total=10),
            ) as resp:
                if resp.status != 200:
                    error_text = await resp.text()
                    logger.warning(
                        "Gemini API 호출 실패 — fallback 사용 (status=%s, error=%s)",
                        resp.status,
                        error_text[:200],
                    )
                    return _fallback_summary(content, max_chars)

                data = await resp.json()

        # 응답 파싱
        summary = (
            data.get("candidates", [{}])[0]
            .get("content", {})
            .get("parts", [{}])[0]
            .get("text", "")
            .strip()
        )

        # 후처리: 따옴표 제거 + 줄바꿈 제거
        summary = summary.strip('"\'""''')
        summary = summary.replace("\n", " ").strip()

        if not summary:
            logger.warning("Gemini 응답이 비어있음 — fallback 사용")
            return _fallback_summary(content, max_chars)

        # 50자 초과 시 자르기
        if len(summary) > max_chars:
            summary = summary[:max_chars]

        logger.info("Gemini 요약 생성 완료 (len=%d)", len(summary))
        return summary

    except Exception as exc:
        logger.warning(
            "Gemini API 예외 발생 — fallback 사용: %s", exc,
        )
        return _fallback_summary(content, max_chars)
