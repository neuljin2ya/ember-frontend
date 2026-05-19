# Backend 테스트용 시드 SQL

프론트엔드 측이 로그인 → 메시지 송수신 → 교환일기 추천 흐름을 테스트할 수 있도록
DB에 더미 데이터를 주입하는 SQL 묶음입니다.

## 디렉터리 구조

```
Backend/scripts/seed/
├── README.md                   ← 본 파일
├── 00_reset.sql                ← 기존 더미 시드만 안전 삭제 (재실행 전 호출)
├── 01_dummy_users.sql          ← 더미 사용자 6명 (대화 상대 1명 + 추천 후보 5명)
├── 02_keywords_consents.sql    ← 키워드 마스터 + 더미들의 이상형 / AI 동의 로그
├── 03_diaries.sql              ← 각 더미의 일기 (visibility=EXCHANGE_ONLY, COMPLETED)
├── 04_messaging_scenario.sql   ← matching + exchange_room + chat_room + 메시지
└── 99_grant_role.sql           ← 본인(tester)을 ROLE_USER · onboarding_step=2로 승격
```

## 사용 흐름 (요약)

1. 백엔드 부팅 후 **본인 토큰 발급**

   ```http
   POST http://localhost:8080/api/dev/register
   ```

   응답의 `userId` 값을 메모 → 이 값이 아래 `:tester_id` 입니다.

2. 시드 SQL 실행 (도커 PG 컨테이너 안 또는 호스트 psql)

   ```powershell
   $TESTER_ID = 123  # 위에서 받은 본인 userId

   # 도커 컨테이너에서 실행하는 경우
   docker exec -i ember-local-postgres psql -U ember -d ember `
     -v tester_id=$TESTER_ID -f - < Backend/scripts/seed/00_reset.sql
   docker exec -i ember-local-postgres psql -U ember -d ember `
     -v tester_id=$TESTER_ID -f - < Backend/scripts/seed/01_dummy_users.sql
   docker exec -i ember-local-postgres psql -U ember -d ember `
     -v tester_id=$TESTER_ID -f - < Backend/scripts/seed/02_keywords_consents.sql
   docker exec -i ember-local-postgres psql -U ember -d ember `
     -v tester_id=$TESTER_ID -f - < Backend/scripts/seed/03_diaries.sql
   docker exec -i ember-local-postgres psql -U ember -d ember `
     -v tester_id=$TESTER_ID -f - < Backend/scripts/seed/04_messaging_scenario.sql
   docker exec -i ember-local-postgres psql -U ember -d ember `
     -v tester_id=$TESTER_ID -f - < Backend/scripts/seed/99_grant_role.sql
   ```

   호스트 psql이 설치돼 있다면 더 간단합니다.

   ```bash
   psql "postgresql://ember:ember1234@localhost:5432/ember" \
     -v tester_id=$TESTER_ID -f Backend/scripts/seed/01_dummy_users.sql
   # 나머지 파일도 동일 패턴
   ```

3. **테스트 토큰으로 호출**

   ```http
   GET  http://localhost:8080/api/dev/token?userId={TESTER_ID}
   ```

   응답의 `accessToken` 을 `Authorization: Bearer ...` 헤더에 넣어 Swagger UI 또는 Flutter 앱에서 사용.

## 무엇이 만들어지는가

| 항목 | 이메일 / 식별자 | 역할 | 비고 |
|---|---|---|---|
| 본인(테스터) | `dev/register`로 생성 | 메시지 송신자, 매칭 신청자 | `99_grant_role.sql`로 ROLE_USER 승격 |
| 더미 B (메시지 상대) | `seed_partner@dev.local` | 본인과 chat_room 연결, 메시지 4개 주고 받음 | 닉네임: `씨앗파트너` |
| 더미 C | `seed_candidate1@dev.local` | 추천 후보 — 일기 보유 | 닉네임: `추천후보01` |
| 더미 D | `seed_candidate2@dev.local` | 추천 후보 — 일기 보유 | 닉네임: `추천후보02` |
| 더미 E | `seed_candidate3@dev.local` | 추천 후보 — 일기 보유 | 닉네임: `추천후보03` |
| 더미 F | `seed_candidate4@dev.local` | 추천 후보 — 일기 보유 | 닉네임: `추천후보04` |
| 더미 G | `seed_candidate5@dev.local` | 추천 후보 — 일기 보유 | 닉네임: `추천후보05` |

이메일 prefix `seed_` 로 모두 식별 가능합니다. `00_reset.sql` 은 prefix 매칭으로 더미만 안전하게 정리합니다.

## 테스트 시나리오별 사용

### 시나리오 A — 메시지 송수신 (WebSocket)

`04_messaging_scenario.sql` 까지 실행 후:

1. `GET /api/chat-rooms` — 본인이 참여 중인 채팅방 1개 노출 (더미 B와) — **실측 검증 완료**
2. `GET /api/chat-rooms/{roomId}/messages` — 시드된 4개 메시지 조회
3. WebSocket 연결: `ws://localhost:8080/ws` (STOMP, Bearer JWT)
4. `SUBSCRIBE /sub/chat-rooms/{roomId}`
5. `POST /api/chat-rooms/{roomId}/messages` 또는 STOMP `SEND` — 시드 메시지 뒤에 누적

### 시나리오 B — 교환일기 추천(탐색)

`03_diaries.sql` 까지 실행 후:

1. `GET /api/diaries/explore?sort=latest` — 더미 C/D/E/F/G 의 일기 카드 5개 조회
2. 카드 클릭 → `GET /api/diaries/{diaryId}/detail` — 본문 노출
3. `POST /api/matching/{diaryId}/select` — 매칭 신청

> **주의 (실측)**: `/api/diaries/explore` 와 `/api/matching/recommendations` 는 `user_vectors` 와
> AI 임베딩(KoSimCSE) 의존도가 높습니다. AI 서버가 꺼져 있고 `user_vectors` 가 비어 있으면
> `M004` 응답이 나올 수 있어요. 매칭 점수 기반 정렬까지 보려면 `cd ai && uvicorn main:app` 으로
> AI 서버를 함께 띄우거나, 일기 단건 조회/탐색 카드 조회는 `GET /api/diaries/{diaryId}/detail` 로
> 직접 호출해 확인하세요.

### 시나리오 C — 교환일기 작성/리액션

`04_messaging_scenario.sql` 실행 후 만들어지는 exchange_room 은 이미 4턴 완료된 ARCHIVED 상태입니다.
**새로 작성 흐름**을 테스트하려면 `99_grant_role.sql` 실행 후 본인이 직접 `POST /api/matching` 호출 → 새로운 exchange_room 생성 → 일기 작성.

`POST /api/dev/exchange-rooms/{roomId}/set-deadline` 으로 만료 시간을 강제 조절할 수 있습니다.

### 시나리오 D — 교환일기 작성/리액션 (기존 방 활용)

`04_messaging_scenario.sql` 로 생성된 exchange_room 은 4턴 완료 → CHAT_CONNECTED 상태이므로
**새 일기 작성은 불가**합니다. 새 흐름은 다음 중 하나:

- `POST /api/matching/{diaryId}/select` 로 새 매칭 → 새 exchange_room
- `POST /api/dev/exchange-rooms/{roomId}/set-deadline` 로 deadline 강제 변경 후 시나리오 다시

## 자주 묻는 질문

**Q. SQL 재실행해도 안전한가?**
A. 모든 INSERT가 `ON CONFLICT DO NOTHING` 패턴이며, 더미는 email/UUID prefix 로 식별됩니다.
`00_reset.sql` 을 먼저 실행하면 깨끗한 상태로 다시 채워집니다.

**Q. `:tester_id` 를 깜빡하고 실행했다면?**
A. PSQL 이 `unrecognized variable` 에러로 실패합니다. 데이터는 변경되지 않습니다.

**Q. 마이그레이션은 안 돌려도 되나?**
A. 백엔드를 한 번이라도 부팅했다면 `ddl-auto: update` + Flyway 가 모든 테이블을 만들어 둡니다.
부팅 전이라면 먼저 `cd Backend && ./gradlew bootRun` 으로 스키마 초기화부터 하세요.
