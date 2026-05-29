# Backend 팀 산출물 업로드 폴더

Ember 백엔드 (Spring Boot 3.x + PostgreSQL/Supabase + FastAPI AI 서버 연계).

## 발표 방어 핵심

백엔드는 발표에서 "안전하고 신뢰할 수 있는 소개팅 앱"이라는 이미지를 기술적으로 뒷받침하는 영역입니다. 단순 CRUD 서버가 아니라 신고, 차단, 콘텐츠 검열, AI 연동, MQ 장애 격리, 관리자 운영 지표까지 연결되어 있으므로 심층 질의가 나오면 아래 근거를 우선 제시하면 됩니다.

| 방어 주제 | 구현 근거 | 설명 포인트 |
|---|---|---|
| 외부 연락처 유도 방지 | `content/service/ContentScanService.java`, `content/client/ContentScanClient.java`, `report/domain/ContactDetection.java`, `admin/controller/report/AdminContactDetectionController.java` | 일기/채팅 제출 시 금칙어, URL 화이트리스트, FastAPI 콘텐츠 스캔으로 차단하고, `contact_detections` 도메인과 관리자 조치 API는 운영 추적 기반으로 준비되어 있습니다. |
| 신고 우선순위와 SLA | `report/service/ReportPriorityCalculator.java`, `admin/controller/report/AdminReportController.java` | 신고를 단순 접수 순서가 아니라 심각도, 누적 이력, SLA 기준으로 정렬해 운영자가 먼저 봐야 할 사건을 놓치지 않게 합니다. |
| AI 장애 격리 | `messaging/outbox/OutboxRelay.java`, `messaging/outbox/OutboxEventProcessor.java`, `monitoring/controller/AdminMonitoringController.java` | AI 분석은 MQ/Outbox로 분리하고, 실패/재시도/상태 조회 API를 두어 메인 서비스가 AI 장애에 직접 묶이지 않게 했습니다. |
| 추천 결과 안정성 | `matching/service/MatchingService.java`, `matching/controller/MatchingController.java` | Redis fresh/stale 캐시와 `X-Degraded` 헤더를 사용해 추천 생성이 지연되어도 사용자는 가능한 결과를 받을 수 있습니다. |
| 데이터 정합성 | `matching/repository/MatchingRepository.java`, `exchange/repository/ExchangeRoomRepository.java`, `src/main/resources/db/migration/` | 매칭 수락, 교환방 생성처럼 중복 생성 위험이 있는 경로에는 잠금과 DB 제약을 사용합니다. |
| 관리자 운영성 | `admin/controller/analytics/AdminAnalyticsController.java`, `monitoring/controller/AdminMonitoringController.java` | 신고, 매칭, 리텐션, AI, Redis, Outbox, MQ 상태를 관리자가 직접 확인할 수 있는 API 표면을 제공합니다. |

## 주요 폴더 안내

| 폴더 | 역할 | 발표 대비 사용법 |
|---|---|---|
| `src/main/java/com/ember/ember/admin/` | 관리자 API, 회원/신고/콘텐츠/분석/운영 기능 | 운영자가 어떤 화면과 API로 위험을 관리하는지 설명할 때 사용합니다. |
| `src/main/java/com/ember/ember/content/` | 금칙어, URL 화이트리스트, AI 콘텐츠 스캔 연계 | "외부 연락처, 불건전 콘텐츠를 어떻게 줄였나" 질문에 대한 구현 근거입니다. |
| `src/main/java/com/ember/ember/report/` | 신고, 차단, 외부 연락처 감지, 우선순위 계산 | 안전성, 신뢰, 운영 대응 속도 방어의 핵심 코드입니다. |
| `src/main/java/com/ember/ember/matching/` | 추천 후보, 매칭 수락, 추천 캐시, degraded 응답 | 기존 스와이프 앱과 다른 추천 구조 및 장애 대응을 설명할 때 사용합니다. |
| `src/main/java/com/ember/ember/messaging/` | RabbitMQ, Outbox, AI 분석 이벤트 발행/처리 | AI 서버와의 비동기 결합, 재시도, DLQ 방식을 설명할 때 사용합니다. |
| `src/main/java/com/ember/ember/monitoring/` | AI/MQ/Outbox/Redis 상태 모니터링 | "운영 중 문제가 나면 어떻게 알 수 있나"에 답하는 근거입니다. |
| `src/main/resources/db/migration/` | Flyway 기반 DB 변경 이력 | ERD와 실제 DB 스키마의 버전 추적 근거입니다. |

## 자동 필터링 매핑 (Phase A-6 정합 확인)

진도표의 **"키워드 기반 자동 필터링"** 은 아래 구성으로 이미 구현되어 있음.
별도의 자동 필터링 모듈을 신설하지 않고 기존 자산을 재사용한다.

| 필터링 요소 | 구현 위치 | 관리자 API |
|---|---|---|
| 금칙어(BannedWord) 단어 매칭 | `com.ember.ember.content.service.BannedWordCacheService` + `ContentScanService` (로컬 Set + Redis 캐시, DB fallback) | `BannedWordAdminController` (CRUD) |
| URL 화이트리스트(UrlWhitelist) 검사 | `com.ember.ember.content.service.UrlWhitelistCacheService` + `ContentScanService` (정규식 URL 추출 + 화이트리스트 대조) | `UrlWhitelistAdminController` (CRUD) |
| FastAPI 원격 검열 (AI) | `content/client/ContentScanClient` → `/api/content/scan` (3초 타임아웃, Silent Fail 시 로컬 검사만으로 판단) | 상태 조회는 `AI 운영 관리 API` |
| 외부 연락처 감지(contact_detections) | `report/domain/ContactDetection` (Phase A-3.5 신설, 관리자 조회/조치 API 구현) | `AdminContactDetectionController` (§5.10~5.11) |
| 캐시 무효화 이벤트 | `BannedWordChangedEvent` / `UrlWhitelistChangedEvent` + `ModerationCacheEvictionListener` (TransactionalEventListener) | 관리자 CRUD 시 자동 발행 |

### 검열 플로우 요약
1. 일기/채팅 메시지 제출
2. `ContentScanService.scan(text)` 호출
3. FastAPI 원격 검열(3s 타임아웃) → 정상이면 결과 기반 판단
4. 타임아웃/오류 → **Silent Fail** (WARN 로그), 로컬 검사만으로 판단 (무조건 허용 아님)
5. 로컬: 금칙어 Set 매칭 + URL 추출 후 화이트리스트 대조
6. 차단 사유는 `ContentScanResult.BlockedReason` (BANNED_WORD / URL_NOT_WHITELISTED / AI_POLICY)

### 관리자 캐시 관리
- Redis 키: `BANNED_WORDS:ALL`, `URL_WHITELIST`
- TTL: 1시간. CRUD 시 TransactionalEventListener 가 즉시 무효화.
- 캐시 miss → DB fallback (`BannedWordRepository`, `UrlWhitelistRepository`).

---

## Phase A 진척 (2026-04-23 KST)

| 단계 | 브랜치 | PR | 상태 |
|---|---|---|---|
| A-1 관리자 계정·활동 로그 | feature/backend-admin-accounts-v0.5 | 이전 머지 완료 | ✅ |
| A-2 회원 관리 | feature/backend-user-management-v0.5 | 이전 머지 완료 | ✅ |
| A-3 신고·차단 파이프라인 (우선순위/SLA/패턴) | feature/backend-report-pipeline-v0.5 | [#60](https://github.com/gc-code1piece/main/pull/60) | ✅ |
| A-4 콘텐츠 관리 (주제/예제/가이드/흐름) | feature/backend-content-admin-v0.5 | [#61](https://github.com/gc-code1piece/main/pull/61) | ✅ |
| A-3.5 외부 연락처 감지 | feature/backend-contact-detection-v0.5 | [#62](https://github.com/gc-code1piece/main/pull/62) | ✅ |
| A-5 프런트 v0.5 실 API 연동 (1차) | feature/frontend-admin-v0.5-integration | [#63](https://github.com/gc-code1piece/main/pull/63) | ✅ |
| A-6 자동 필터링 정합 확인 | chore/backend-auto-filter-mapping | (본 PR) | 🟢 |

## 명세서 정본
- 마스터 인덱스: `docs/md/프로젝트_문서_마스터인덱스.md`
- 관리자 기능명세서 v3.0: `docs/md/features/version3.0/관리자/관리자_기능명세서_요약본_v3_0.md`
- 관리자 API 통합 요약본 v2.3: `docs/md/api/admin/version2.3/관리자_API_통합_요약본_v2_3.md`
- ERD 명세서 v2.4 계열: `docs/md/erd/`
- 외부 연락처 AI 자동 탐지, Rollup 집계, 일부 분석 SQL 개선은 마스터 인덱스의 미해소 이슈로 구분해 설명합니다.
