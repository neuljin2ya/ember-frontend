# DB Migration 안내

이 폴더는 Ember 백엔드의 Flyway 마이그레이션 이력을 관리합니다. 발표에서 ERD와 실제 구현의 정합성을 방어할 때 가장 먼저 확인할 위치입니다.

## 발표 방어 포인트

| 주제 | 관련 파일 | 설명 |
|---|---|---|
| AI 파이프라인 인프라 | `V2__ai_pipeline_infrastructure.sql`, `V3__matching_user_vectors.sql`, `V5__lifestyle_pipeline_m6.sql` | AI 분석 요청, 사용자 벡터, 라이프스타일 분석 결과를 DB에 남길 수 있도록 기반 테이블을 분리했습니다. |
| 신고/SLA/우선순위 | `V8__reports_sla_and_priority.sql` | 신고 처리에서 우선순위와 SLA 방어 논리를 DB 구조로 뒷받침합니다. |
| 콘텐츠 운영 | `V9__content_admin_tables.sql` | 금칙어, URL 화이트리스트, 콘텐츠 운영 정책을 관리자 기능과 연결합니다. |
| 외부 연락처 감지 | `V10__contact_detections.sql` | 앱 밖 대화 유도 탐지를 운영 이력으로 남길 수 있는 테이블 기반을 제공합니다. 자동 적재 연결은 현재 구현 범위와 개선 과제를 구분해 설명합니다. |
| 분석 성능 | `V11__analytics_indexes.sql`, `V12__analytics_phase_b1_indexes.sql`, `V13__analytics_phase_b2_indexes.sql` | 관리자 분석 대시보드 조회를 위해 인덱스를 보강합니다. Rollup 테이블 고도화는 마스터 인덱스의 후속 과제입니다. |
| 운영/권한/자동화 | `V18__admin_rbac_tables.sql`, `V20__admin_system_tables.sql`, `V21__admin_automation_tables.sql` | 관리자 권한, 시스템 상태, 운영 자동화 기능의 스키마 근거입니다. |

## 확인 순서

1. 명세서의 ERD 버전과 이 폴더의 Flyway 버전을 비교합니다.
2. 발표 중 질문이 나오면 테이블명만 말하지 말고 "왜 별도 테이블로 분리했는지"를 설명합니다.
3. 운영성 질문은 `reports`, `contact_detections`, `outbox_events`, `processed_messages`, 관리자 RBAC 계열 테이블을 함께 연결해 답변합니다.
