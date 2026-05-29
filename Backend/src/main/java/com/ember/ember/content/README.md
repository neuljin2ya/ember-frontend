# Content 패키지 안내

이 패키지는 Ember의 콘텐츠 운영, 금칙어/URL 정책, FastAPI 콘텐츠 스캔 연계를 담당합니다. 발표에서 "소개팅 앱의 안전성과 신뢰를 어떻게 구현했는가"를 설명할 때 사용하는 핵심 폴더입니다.

## 구성

| 하위 폴더/파일 | 역할 | 발표 방어 포인트 |
|---|---|---|
| `service/ContentScanService.java` | 일기/채팅 제출 시 로컬 정책과 FastAPI 스캔 결과를 종합 판단 | 외부 연락처 패턴, 금칙어, 비허용 URL을 한 경로에서 판단합니다. |
| `client/ContentScanClient.java` | FastAPI `/api/content/scan` 호출 | 원격 AI 스캔은 3초 타임아웃을 두고, 실패 시 로컬 검사를 유지합니다. |
| `service/BannedWordCacheService.java` | 금칙어 캐시/DB fallback | 운영 정책 조회 비용을 줄이고 Redis 장애 시 DB fallback으로 방어합니다. |
| `service/UrlWhitelistCacheService.java` | URL 화이트리스트 캐시/DB fallback | 허용 URL만 통과시키는 정책을 빠르게 적용합니다. |
| `listener/ModerationCacheEvictionListener.java` | 금칙어/URL 변경 이벤트 기반 캐시 무효화 | 관리자가 정책을 바꾸면 캐시가 즉시 갱신되도록 합니다. |
| `domain/`, `repository/` | 예시 일기, 교환일기 가이드 등 콘텐츠 운영 데이터 | 사용자에게 안전하고 자연스러운 작성 흐름을 제공하는 운영 자산입니다. |

## 질의 대응 예시

- "AI 검열이 실패하면 위험 콘텐츠가 통과하나요?"
  원격 AI 스캔 실패가 곧 전체 허용은 아닙니다. `ContentScanService`가 로컬 금칙어와 URL 화이트리스트 검사를 계속 수행합니다.

- "연락처 우회 표현은 어떻게 보나요?"
  FastAPI `api/content_scan.py`가 한국어 숫자 표현과 SNS/이메일/전화번호 패턴을 정규화해 탐지하고, 백엔드는 일기/채팅 제출 단계에서 차단 결과를 반영합니다. `contact_detections` 자동 적재와 confidence 산출은 후속 보강 과제로 분리해 설명합니다.

- "운영 중 정책 변경은 느리지 않나요?"
  관리자 CRUD 이후 이벤트 기반으로 Redis 캐시를 무효화해 최신 정책을 빠르게 반영합니다.
