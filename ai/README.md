# AI 팀 산출물 업로드 폴더

Ember AI 서버는 FastAPI 기반으로 동작하며, 백엔드의 사용자 경험을 직접 막지 않도록 HTTP 내부 API와 RabbitMQ 비동기 소비자를 함께 사용합니다. 발표에서는 "AI 모델을 붙였다"보다 "어떤 판단을 AI가 맡고, 어떤 실패는 백엔드가 흡수하도록 설계했는가"를 중심으로 설명하면 좋습니다.

## 핵심 역할

| 영역 | 주요 파일 | 설명 |
|---|---|---|
| 일기 감정/성향 분석 | `services/kcelectra_service.py`, `workers/mq_consumer.py` | KcELECTRA 기반 분석 결과를 일기 분석 파이프라인에 제공합니다. |
| 문장 임베딩/유사도 | `services/kosimcse_service.py`, `services/matching_score_service.py`, `api/matching.py` | KoSimCSE 임베딩과 키워드 점수 계산으로 매칭 보조 점수를 제공합니다. |
| 교환일기 리포트 | `services/exchange_report_service.py`, `workers/mq_consumer.py` | 두 사용자의 교환일기 내용을 묶어 관계 온도, 공통 키워드, 요약 정보를 생성합니다. |
| 라이프스타일 리포트 | `services/lifestyle_service.py`, `workers/mq_consumer.py` | 여러 일기에서 생활 패턴과 감정 태그를 집계합니다. |
| 콘텐츠 스캔 | `api/content_scan.py` | 전화번호, 카카오톡, 이메일, SNS, URL, 짧은 링크 등 외부 연락처 유도 패턴을 탐지합니다. |
| 관측/운영 지표 | `observability/metrics.py`, `observability/logging.py` | MQ 처리, DLQ 이동, 추론 실패 같은 운영 신호를 수집합니다. |

## 백엔드 연동 구조

| 연동 방식 | 경로 | 방어 포인트 |
|---|---|---|
| 내부 HTTP API | `api/content_scan.py`, `api/matching.py`, `api/deps.py` | `X-Internal-Key` 헤더로 Spring Boot 백엔드와의 내부 호출을 검증합니다. |
| RabbitMQ Consumer | `workers/mq_consumer.py` | 일기 분석, 교환일기 리포트, 라이프스타일 분석, 사용자 벡터 생성 큐를 분리해 병목과 실패를 격리합니다. |
| RabbitMQ Publisher | `workers/mq_publisher.py` | 분석 결과를 내구성 있는 메시지로 되돌려 보내 후속 처리를 안정화합니다. |
| Health/Ready/Warmup | `main.py` | 모델 로딩 상태와 서버 준비 상태를 운영에서 점검할 수 있게 합니다. |

## 발표 시 강조할 점

- AI는 핵심 UX를 보조하지만, 메인 백엔드가 AI 장애에 직접 종속되지 않도록 MQ 기반 비동기 파이프라인으로 분리했습니다.
- 콘텐츠 스캔은 정규식만의 단순 필터가 아니라 한국어 숫자 표현 정규화, 외부 연락처 유형 분류, 내부 API 키 검증을 포함합니다.
- 모델별 책임을 분리했습니다. KcELECTRA는 감정/성향 분석, KoSimCSE는 임베딩과 의미 유사도, 서비스 계층은 매칭 점수와 리포트 생성을 담당합니다.
- 운영자는 백엔드의 `AdminMonitoringController`와 AI 서버의 metrics/logging을 통해 MQ, DLQ, 추론 실패를 추적할 수 있습니다.

## 실행

```bash
cd ai
uvicorn main:app --reload
```

RabbitMQ 기반 소비자를 함께 검증할 때는 백엔드의 MQ 설정과 `.env` 계열 환경 변수가 맞는지 먼저 확인합니다.
