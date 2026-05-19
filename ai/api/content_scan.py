"""
콘텐츠 스캔 API 엔드포인트.

POST /api/content/scan
  - X-Internal-Key 헤더 검증 (Spring → FastAPI 내부 통신)
  - 외부 연락처 정규식 탐지 (전화번호, 카카오ID, 이메일, 인스타그램, 텔레그램, URL, 단축 URL)
  - DB 직접 접근 없음 (설계서 9.§ 보안 규칙)
  - 금칙어 검사는 Spring 측 localRegexScan이 담당; FastAPI는 정규식 패턴만 적용

설계서 3.4절: Spring이 동기 HTTP로 호출, 3초 타임아웃 적용

v2 (M8) 우회 방어 강화:
  1. 정규화 전처리 — "010 . 1234 . 5678", "010 - 1234 - 5678" 등 구분자 우회 차단
  2. 한글 숫자 변환 — "공일공일이삼사오육칠팔" → "01012345678"
  3. 단축 URL 패턴 신설 — bit.ly / tinyurl / naver.me / me2.do / t.co / goo.gl 등
  4. 원문 + 정규화본 양방향 매칭 후 중복 제거
"""
from __future__ import annotations

import re
import structlog
from fastapi import APIRouter, Header, HTTPException, status
from pydantic import BaseModel

from api.deps import verify_internal_key
from config import INTERNAL_API_KEY

logger = structlog.get_logger(__name__)

router = APIRouter()


# ── 외부 연락처 탐지 정규식 패턴 ─────────────────────────────────────────────
# 각 패턴 키는 blockedReasons의 category 값으로 사용된다.
PATTERNS: dict[str, re.Pattern[str]] = {
    # 한국 휴대전화 번호 (010, 011, 016, 017, 018, 019)
    # M8 강화: 구분자에 [-\s.,_] 모두 허용 + 단어 경계 제거 (한글 사이 매칭 가능)
    "EXTERNAL_CONTACT_PHONE": re.compile(
        r"01[016789][\-\s.,_]?\d{3,4}[\-\s.,_]?\d{4}"
    ),
    # 카카오톡 ID 유도 표현
    "EXTERNAL_CONTACT_KAKAO": re.compile(
        r"(?:카톡|카카오톡|카카오|kakao)[\s:ID아디]*[A-Za-z0-9_]{3,}",
        re.IGNORECASE,
    ),
    # 이메일 주소
    "EXTERNAL_CONTACT_EMAIL": re.compile(
        r"[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[A-Za-z]{2,}"
    ),
    # 인스타그램 계정 유도 표현 또는 @handle
    "EXTERNAL_CONTACT_INSTAGRAM": re.compile(
        r"(?:인스타|instagram)[\s]*@?[A-Za-z0-9._]{3,30}",
        re.IGNORECASE,
    ),
    # 텔레그램 링크
    "EXTERNAL_CONTACT_TELEGRAM": re.compile(
        r"(?:t\.me|telegram\.me)/[A-Za-z0-9_]{3,}",
        re.IGNORECASE,
    ),
    # 일반 URL (https?://)
    "EXTERNAL_CONTACT_URL": re.compile(
        r"https?://[^\s]+"
    ),
    # 단축 URL (M8 신규) — bit.ly / tinyurl / naver.me / me2.do / t.co / goo.gl / han.gl / buly.kr
    "EXTERNAL_CONTACT_SHORTLINK": re.compile(
        r"(?:bit\.ly|tinyurl\.com|naver\.me|me2\.do|t\.co|goo\.gl|han\.gl|buly\.kr)/[A-Za-z0-9_\-]+",
        re.IGNORECASE,
    ),
}


# ── M8: 우회 방어 — 정규화 전처리 ────────────────────────────────────────────

# 공백 / 구분자 / 특수문자 (단, URL 핵심 . 와 / 는 제외하지 않으면 도메인이 깨지므로 별도 처리)
# 전화번호 / 카카오 ID 우회 차단을 위한 일반 정규화 — 알파벳·숫자·한글·@·.·/ 외 모두 제거
_NORMALIZE_PATTERN: re.Pattern[str] = re.compile(r"[^\w가-힣@./:]+")

# 한글 숫자 → 아라비아 숫자 매핑 (전화번호 우회 차단)
_KOR_DIGIT_MAP: dict[str, str] = {
    "공": "0", "영": "0", "빵": "0",
    "일": "1", "이": "2", "삼": "3", "사": "4", "오": "5",
    "육": "6", "칠": "7", "팔": "8", "구": "9",
}

# 010 시작 한글 숫자 11자리(첫자 + 10자 = 11자) 시퀀스를 잡는다.
# 휴대폰 번호 정확히 11자만 매칭하도록 9~10자로 제한 → "이야" 같은 일반 어미가 변환 대상이
# 되지 않도록 false positive 차단. 한글 사이 공백은 \s* 로 허용.
_KOR_PHONE_PATTERN: re.Pattern[str] = re.compile(
    r"(?:공|영|빵)(?:\s*[일이삼사오육칠팔구공영빵]){9,10}"
)


def _convert_korean_digits(text: str) -> str:
    """
    텍스트 내 한글 숫자 전화번호 시퀀스를 아라비아 숫자로 변환한다.

    예:
      "공일공 일이삼사 오육칠팔" → "01012345678"
      "내 전화번호는 공일공일이삼사오육칠팔이야" → "내 전화번호는 01012345678이야"

    한글 숫자가 7자 미만으로 짧게 등장하는 경우는 일반 텍스트에 자주 등장하는
    "이", "오" 같은 글자와 충돌하므로 변환 대상에서 제외 (false positive 방지).
    """
    def _replace(match: re.Match[str]) -> str:
        seq = match.group(0)
        return "".join(_KOR_DIGIT_MAP.get(c, "") for c in seq if c.strip())

    return _KOR_PHONE_PATTERN.sub(_replace, text)


def _normalize_for_scan(text: str) -> str:
    """
    구분자/공백 우회 패턴을 차단하기 위한 정규화 전처리.

    - 한글 숫자 → 아라비아 숫자
    - 공백·하이픈·점·언더스코어 외 특수문자 제거 (단 @, ., /, : 는 URL/이메일 보존을 위해 유지)
    - 공백 자체는 제거 (전화번호 "010 1234 5678" → "01012345678")

    예:
      "010 - 1234 - 5678"  → "01012345678"
      "010 . 1234 . 5678"  → "010.1234.5678"   # . 는 보존되지만 PHONE 정규식이 이미 \d{3,4} 매칭하므로 처리됨
      "카 톡 ID hello123"  → "카톡IDhello123"
    """
    converted = _convert_korean_digits(text)
    # 1차: 모든 공백 제거 → 공백 분리 우회 차단
    no_space = re.sub(r"\s+", "", converted)
    # 2차: 알파벳·숫자·한글·@·.·/·: 만 보존 (다른 특수문자 제거)
    return _NORMALIZE_PATTERN.sub("", no_space)


# ── 요청/응답 스키마 ──────────────────────────────────────────────────────────

class ScanRequest(BaseModel):
    """콘텐츠 스캔 요청 바디."""
    content: str


class BlockedReason(BaseModel):
    """개별 차단 사유."""
    category: str
    matchedToken: str


class ScanResponse(BaseModel):
    """콘텐츠 스캔 응답."""
    allowed: bool
    blockedReasons: list[BlockedReason]


# ── 내부 API 키 검증 의존성 ───────────────────────────────────────────────────

def verify_internal_key(x_internal_key: str = Header(..., alias="X-Internal-Key")) -> None:
    """
    X-Internal-Key 헤더 검증.
    Spring → FastAPI 내부 통신에만 허용. 불일치 시 401 반환.
    """
    if x_internal_key != INTERNAL_API_KEY:
        logger.warning("내부 API 키 불일치 — 접근 거부")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="유효하지 않은 내부 API 키입니다.",
        )


# ── 매칭 헬퍼 ────────────────────────────────────────────────────────────────

def _findall_for(pattern: re.Pattern[str], text: str) -> list[str]:
    """
    pattern.findall 결과를 항상 문자열 리스트로 정규화.
    그룹이 있는 패턴이면 첫 그룹, 그룹이 없으면 전체 매칭을 반환.
    """
    raw_matches = pattern.findall(text)
    out: list[str] = []
    for m in raw_matches:
        token = m if isinstance(m, str) else (m[0] if m else "")
        if token:
            out.append(token)
    return out


# ── 엔드포인트 ────────────────────────────────────────────────────────────────

@router.post(
    "/content/scan",
    response_model=ScanResponse,
    summary="콘텐츠 스캔 (외부 연락처 탐지, M8 우회 방어 강화)",
    description=(
        "일기 본문에서 외부 연락처 유도 패턴(전화번호, 카카오 ID, 이메일, 인스타그램, "
        "텔레그램, 일반 URL, 단축 URL)을 정규식으로 탐지한다. DB 직접 접근 없음.\n\n"
        "**M8 우회 방어 강화**\n"
        "- 정규화 전처리: 공백/하이픈/점 등 구분자 우회 차단 (\"010 - 1234 - 5678\" 등)\n"
        "- 한글 숫자 변환: \"공일공일이삼사오육칠팔\" → \"01012345678\"\n"
        "- 단축 URL 패턴 신설 (bit.ly / tinyurl / naver.me / me2.do / t.co 등)\n"
        "- 원문 + 정규화본 양방향 매칭 후 중복 제거"
    ),
)
def scan_content(
    body: ScanRequest,
    x_internal_key: str = Header(..., alias="X-Internal-Key"),
) -> ScanResponse:
    """
    콘텐츠 스캔 처리 로직 (v2 — M8).

    1. X-Internal-Key 헤더 검증
    2. 원문 + 정규화본(_normalize_for_scan) 두 가지 텍스트 생성
    3. 각 정규식 패턴을 두 텍스트 모두에 적용 → 매칭 수집
    4. (category, matchedToken) 중복 제거 후 BlockedReason 목록 구성
    5. 매칭 결과 1건 이상이면 allowed=False
    """
    # 내부 API 키 검증
    verify_internal_key(x_internal_key)

    raw_content = body.content
    normalized = _normalize_for_scan(raw_content)

    seen_pairs: set[tuple[str, str]] = set()
    blocked_reasons: list[BlockedReason] = []

    for category, pattern in PATTERNS.items():
        for source_label, source_text in (("raw", raw_content), ("normalized", normalized)):
            for token in _findall_for(pattern, source_text):
                key = (category, token)
                if key in seen_pairs:
                    continue
                seen_pairs.add(key)
                blocked_reasons.append(
                    BlockedReason(category=category, matchedToken=token)
                )
                logger.debug(
                    "콘텐츠 스캔 탐지",
                    category=category,
                    token=token,
                    source=source_label,
                )

    allowed = len(blocked_reasons) == 0

    if not allowed:
        logger.info(
            "콘텐츠 스캔 차단",
            reasons_count=len(blocked_reasons),
            first_category=blocked_reasons[0].category,
        )
    else:
        logger.debug("콘텐츠 스캔 통과")

    return ScanResponse(allowed=allowed, blockedReasons=blocked_reasons)
