# Ember — 교환일기 소개팅앱

100자 이상의 일기 한 편을 매개로 매칭하고, **4턴 교환일기**를 주고받은 뒤 채팅으로 이어지는
국내 최초의 글 기반 소개팅 서비스입니다.

- **Mobile**: Flutter (Android / iOS / Web)
- **Admin**: Next.js 14 (App Router)
- **Backend**: Spring Boot 3.x + JPA + Flyway
- **AI**: FastAPI + KcELECTRA(일기 분석) + KoSimCSE(매칭 임베딩)
- **DB / Cache / MQ**: PostgreSQL · Redis · RabbitMQ

---

## 📋 사전 요구 사항

| 도구 | 버전 | 비고 |
|---|---|---|
| Docker Desktop | 최신 | PG · Redis · RabbitMQ 컨테이너용 |
| JDK | **21** | `java -version`으로 확인 |
| Node.js | 18 이상 | 관리자 웹 (`Frontend/admin`) |
| Flutter | 3.x | 사용자 앱 (`Frontend/`) |
| Python | 3.10 이상 | AI 서버 (`ai/`) |

> Windows 환경 기본 가이드. PowerShell 또는 Git Bash 어느 쪽이든 동작합니다.

---

## 📁 폴더 구조

```
gc-dating-app/
├── Frontend/                  ← Flutter 사용자 앱 (PR #175 머지로 추가됨)
│   └── admin/                 ← Next.js 관리자 웹
├── Backend/                   ← Spring Boot 백엔드
│   ├── src/
│   ├── scripts/
│   │   └── seed/              ← 🌱 테스트 시드 SQL (README 참조)
│   └── build.gradle.kts
├── ai/                        ← FastAPI AI 서버 (KcELECTRA / KoSimCSE)
├── docs/                      ← 명세서·ERD (gitignore, Vault 미러링)
├── docker-compose.local.yml   ← 로컬 PG · Redis · RabbitMQ
└── docker-compose.yml         ← prod 풀스택
```

---

## 🚀 로컬 실행 가이드

### ① 인프라 컨테이너 기동

```powershell
cd C:\Users\kik32\workspace\gc-dating-app
docker compose -f docker-compose.local.yml up -d

# 확인 — 컨테이너 3개가 healthy 또는 Up 상태여야 합니다
docker ps
```

| 컨테이너 | 포트 | 용도 |
|---|---|---|
| `ember-local-postgres` | `5432` | DB (`ember` / `ember` / `ember1234`) |
| `ember-local-redis`    | `6379` | 캐시 · 세션 · 시퀀스 |
| `ember-local-rabbitmq` | `5672`, `15672` (관리 UI) | AI 비동기 파이프라인 |

> **재기동이 필요하면**: `docker compose -f docker-compose.local.yml restart`
> **데이터 초기화가 필요하면**: `docker compose -f docker-compose.local.yml down -v` (볼륨까지 삭제)

### ② 백엔드 (Spring Boot)

```powershell
cd Backend
./gradlew bootRun
```

부팅 완료 후 다음이 노출됩니다:

- **API 베이스**: http://localhost:8080
- **Swagger UI**: http://localhost:8080/swagger-ui/index.html (PR #166 이후 prod에서도 노출 — `/swagger-ui.html` 은 403, **`/swagger-ui/index.html` 이 진짜 경로**)
- **헬스 체크**: http://localhost:8080/actuator/health
- **메트릭**: http://localhost:8080/actuator/prometheus

스키마는 Hibernate `ddl-auto:update` + Flyway가 자동 생성합니다. 첫 부팅 시 1~2분 소요.

### ③ AI 서버 (FastAPI)

```powershell
cd ai
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

- **AI API 베이스**: http://localhost:8000
- 메시지/일기 작성·리액션 같은 기능은 AI 서버가 꺼져 있어도 동작합니다 (분석/매칭 점수만 반영 보류).
- AI 없이 전체 흐름만 검증하고 싶다면 `POST /api/dev/ai/simulate/{diaryId}` 로 결과를 강제 주입 가능.

### ④ Flutter 사용자 앱

```powershell
cd Frontend
flutter pub get
flutter run -d chrome        # 또는 -d windows / -d android
```

- 카카오 로그인 또는 **개발용 회원가입**(`/api/dev/register`)으로 진입 가능
- API 베이스 URL은 `lib/core/config/` 또는 `pubspec.yaml`의 설정을 참조

### ⑤ 관리자 웹 (Next.js)

```powershell
cd Frontend/admin
npm install
npm run dev
```

- **Admin URL**: http://localhost:3000
- 관리자 시드 계정: `V6__admin_accounts_seed.sql` 마이그레이션으로 자동 생성됨

---

## 🌱 테스트 데이터 시드 (백엔드/프론트 합동 테스트용)

프론트엔드 측에서 **로그인 → 메시지 송수신 → 교환일기 추천**까지 즉시 테스트할 수 있도록
DB에 더미 데이터를 주입하는 SQL 묶음을 제공합니다.

### 무엇이 만들어지는가

- 본인(테스터) 1명 → `POST /api/dev/register`로 즉석 발급한 계정을 ROLE_USER로 승격
- 더미 사용자 6명 (대화 상대 1명 + 교환일기 추천 후보 5명)
- 더미들의 일기 6편 (`EXCHANGE_ONLY` · `COMPLETED` · `diary_keywords` 5종 태그 포함)
- 본인 ↔ 더미 파트너 사이 `matching`(MATCHED) → `exchange_room`(CHAT_CONNECTED) → `chat_room`(ACTIVE) → 메시지 4건

### 실행 흐름

```powershell
# 1) 본인 회원가입 — userId 메모
curl -X POST http://localhost:8080/api/dev/register

# 2) 시드 SQL 한 번에 실행
./Backend/scripts/seed/run_all.ps1 -TesterId <위에서_받은_userId>

# 3) 본인 토큰 재발급 (ROLE_USER 반영된 새 토큰)
curl "http://localhost:8080/api/dev/token?userId=<userId>"
```

상세 가이드: [Backend/scripts/seed/README.md](Backend/scripts/seed/README.md)

### 테스트 가능한 시나리오 (로컬 실측 검증 완료)

| 시나리오 | 호출 API | 기대 결과 / 검증 노트 |
|---|---|---|
| 본인 프로필 | `GET /api/users/me` | ✅ 닉네임·이상형 키워드 3개 노출 (실측 OK) |
| 채팅방 목록 | `GET /api/chat-rooms` | ✅ 채팅방 1개 (씨앗파트너), 마지막 메시지·안 읽음 1건 노출 (실측 OK) |
| 메시지 조회 | `GET /api/chat-rooms/{roomId}/messages` | 4개 메시지 (sequence_id 1~4) |
| 메시지 전송 (REST) | `POST /api/chat-rooms/{roomId}/messages` | sequence_id 5번부터 누적 |
| 메시지 전송 (WS) | WebSocket `/ws` STOMP `/pub/chat/send` | 실시간 브로드캐스트 |
| 탐색 추천 | `GET /api/diaries/explore?sort=latest` | ⚠️ 추천 후보 카드 — `user_vectors` / AI 임베딩 의존이라 AI 서버 미기동 시 M004 가능 |
| 일기 상세 | `GET /api/diaries/{diaryId}/detail` | 더미 일기 본문 노출 |
| 매칭 추천 | `GET /api/matching/recommendations` | AI 매칭 점수 기반 추천 |
| 매칭 신청 | `POST /api/matching/{diaryId}/select` | matching 레코드 생성 |
| 교환일기 작성 | `POST /api/exchange-rooms/{roomId}/diaries` | exchange_diaries 1건 |
| 교환일기 리액션 | `POST /api/exchange-rooms/{roomId}/diaries/{diaryId}/reaction` | reaction 컬럼 업데이트 |

---

## 🔗 주요 URL 모음

| 환경 | URL | 비고 |
|---|---|---|
| 사용자 앱 (Web 빌드) | http://localhost:* (flutter가 출력) | `flutter run -d chrome` |
| 관리자 웹 | http://localhost:3000 | `npm run dev` |
| 백엔드 API | http://localhost:8080 | |
| Swagger UI | http://localhost:8080/swagger-ui/index.html | 203개 엔드포인트 — definition: admin / all / auth / user |
| OpenAPI JSON | http://localhost:8080/v3/api-docs | |
| AI 서버 | http://localhost:8000 | FastAPI `/docs` 자동 생성 |
| RabbitMQ 관리 UI | http://localhost:15672 | `guest` / `guest` |
| PG (도커 외부) | `postgresql://ember:ember1234@localhost:5432/ember` | |

---

## 🛠️ 트러블슈팅

| 증상 | 원인 / 해결 |
|---|---|
| `gradlew bootRun` 이 5분째 멈춰 있어요 | 첫 빌드는 의존성 다운로드로 3~5분 정상. 두 번째부터는 30초 이내. |
| 백엔드가 PG 연결 실패 | `docker ps` 로 `ember-local-postgres` 가 떠 있는지 확인. 포트 충돌 시 5432를 점유한 프로세스 종료. |
| `flutter run` 에서 패키지 미발견 | `cd Frontend && flutter clean && flutter pub get` |
| Swagger UI 가 404 | PR #168~#169 머지 이전 코드라면 Nginx 프록시 미설정 — `git pull` 로 main 동기화 |
| 메시지 전송 시 NPE | PR #165 머지 이전 → `git pull` 후 재빌드 |
| AI 분석 결과가 영영 PENDING | RabbitMQ Outbox self-deadlock 이슈. PR #164 머지 이후라면 해결됨. |
| 시드 SQL 실행 시 `tester_id 변수 없음` | psql 명령에 `-v tester_id=<숫자>` 누락 |
| 시드 SQL 의 `ai_consent_log` INSERT 에러 | 백엔드 한 번도 부팅 안 한 상태 — 부팅으로 테이블 생성 필요 |

---

## 협업 규칙 (브랜치 & PR)

### 브랜치 사용 규칙
- `main` 브랜치는 **직접 커밋 금지**
- 작업할 때는 **항상 새 브랜치 생성**

브랜치 이름 예시:
```
feature/ai-작업내용
feature/backend-작업내용
feature/frontend-작업내용
fix/backend-버그내용
```

### 작업 위치
- AI 팀 → `ai/` 폴더에서 작업
- 백엔드 팀 → `Backend/` 폴더에서 작업
- 프론트엔드 팀 → `Frontend/` 폴더에서 작업

### Pull Request(PR) 규칙
1. 작업 완료 후 `main` 브랜치로 **Pull Request 생성**
2. PR에는 어떤 작업을 했는지 **짧은 코멘트**
3. PR 후 merge 버튼 눌러서 승인
4. AI 영역 변경 시 PR 본문에 `⚠️ AI팀 공유` 섹션 명시

### 주의사항
- `main` 브랜치에 직접 push X
- `docs/` 폴더는 `.gitignore` — 명세서는 Obsidian Vault 미러링

### 작업 흐름 요약
```
git pull origin main → 브랜치 생성 → 작업 → 커밋 → push → PR 생성 → 승인 → main에 merge
```
