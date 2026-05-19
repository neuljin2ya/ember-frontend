"""
Gemini API 기반 일기 주제 요약 서비스

입력: 일기 원문 (str)
출력: 50자 이내 한국어 주제 요약 (str)

사용 모델: gemini-2.0-flash (무료 티어)
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
GEMINI_MODEL = "gemini-2.0-flash"
GEMINI_URL = (
    f"https://generativelanguage.googleapis.com/v1beta/models/"
    f"{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
)

SUMMARY_PROMPT = """당신은 일기 요약 전문가입니다.

아래 일기를 읽고 핵심 주제를 한국어 한 문장으로 요약해주세요.

## 규칙
- 반드시 50자 이내
- 일기에서 가장 중요한 사건이나 감정을 포함할 것
- "~한 하루", "~에 대한 일기" 같은 뻔한 표현 금지
- 구체적인 행동이나 감정이 드러나게 작성
- 따옴표, 번호, 부가 설명 없이 요약문만 출력

## 좋은 예시
- 즉흥으로 부산 가서 회 먹고 밤바다 보며 자유를 느낀 날
- 후배 실수를 감싸주고 돌아오며 리더의 무게를 생각함
- 오랜 친구와 가치관 차이를 느끼고 관계의 본질을 고민함

## 나쁜 예시
- 오늘 하루에 대한 일기 (너무 막연함)
- 여러 가지 일이 있었던 하루 (구체성 없음)
- 일상을 보낸 하루 (아무 정보 없음)

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
                "temperature": 0.4,
                "maxOutputTokens": 80,
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
