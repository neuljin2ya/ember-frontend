-- =============================================================================
-- 04_messaging_scenario.sql — 메시지 송수신 시나리오 한 묶음
-- ---------------------------------------------------------------------------
-- 본인(:tester_id) ↔ 더미 파트너(seed_partner@dev.local) 사이에
-- 다음을 한 번에 만들어 둡니다.
--   1) matchings (MATCHED)            — 본인이 파트너 일기를 보고 매칭 신청한 결과
--   2) exchange_rooms (CHAT_CONNECTED) — 4턴 완료 후 채팅 연결까지 끝난 상태
--   3) chat_rooms (ACTIVE)             — 본인이 진입 가능한 채팅방
--   4) messages 4건                    — 두 사람이 번갈아 보낸 메시지
--
-- 사용:
--   psql ... -v tester_id=123 -f 04_messaging_scenario.sql
--
-- 멱등성은 00_reset.sql 에 위임합니다. 재실행 전 00_reset.sql 을 먼저 실행하세요.
-- =============================================================================

\set ON_ERROR_STOP on

-- ── 변수 캡처: \gset 으로 파트너 / 일기 id 를 psql 변수에 담음 ────────────────
SELECT id AS partner_id FROM users WHERE email = 'seed_partner@dev.local' \gset
SELECT id AS partner_diary_id FROM diaries WHERE user_id = :partner_id ORDER BY date DESC LIMIT 1 \gset

BEGIN;

-- 1) matching 생성 (PENDING → 바로 MATCHED 처리)
INSERT INTO matchings (from_user_id, to_user_id, diary_id, status, matched_at, created_at, modified_at)
VALUES (:tester_id, :partner_id, :partner_diary_id, 'MATCHED',
        NOW() - INTERVAL '7 day', NOW() - INTERVAL '7 day', NOW() - INTERVAL '1 hour')
RETURNING id AS matching_id \gset

-- 일기를 교환됨으로 표시
UPDATE diaries SET is_exchanged = TRUE WHERE id = :partner_diary_id;

-- 2) exchange_room 생성 (4턴 모두 완료, 채팅 연결까지 끝난 상태)
INSERT INTO exchange_rooms (
    room_uuid, user_a_id, user_b_id, matching_id,
    current_turn_user_id, turn_count, round_count, status,
    deadline_at, next_step_deadline_at,
    created_at, modified_at
)
VALUES (
    gen_random_uuid(), :tester_id, :partner_id, :matching_id,
    :partner_id, 4, 1, 'CHAT_CONNECTED',
    NOW() + INTERVAL '48 hour', NULL,
    NOW() - INTERVAL '7 day', NOW() - INTERVAL '2 hour'
)
RETURNING id AS exchange_id \gset

-- 3) chat_room 생성
INSERT INTO chat_rooms (
    room_uuid, user_a_id, user_b_id, exchange_room_id,
    status, created_at, modified_at
)
VALUES (
    gen_random_uuid(), :tester_id, :partner_id, :exchange_id,
    'ACTIVE', NOW() - INTERVAL '2 hour', NOW() - INTERVAL '5 minute'
)
RETURNING id AS chat_id \gset

-- exchange_room 에 chat_room_id 역참조 세팅
UPDATE exchange_rooms SET chat_room_id = :chat_id WHERE id = :exchange_id;

-- 4) 메시지 4건
INSERT INTO messages (
    chat_room_id, sender_id, content, type, sequence_id,
    is_read, read_at, is_flagged, created_at, modified_at
)
VALUES
    (:chat_id, :partner_id, '안녕하세요! 일기 잘 읽었어요. 글이 정말 따뜻하더라구요.', 'TEXT', 1,
     TRUE,  NOW() - INTERVAL '110 minute', FALSE,
     NOW() - INTERVAL '115 minute', NOW() - INTERVAL '110 minute'),
    (:chat_id, :tester_id,  '감사합니다 :) 저도 일기 잘 봤어요. 책 좋아하시는 것 같아서 반가웠어요!', 'TEXT', 2,
     TRUE,  NOW() - INTERVAL '100 minute', FALSE,
     NOW() - INTERVAL '105 minute', NOW() - INTERVAL '100 minute'),
    (:chat_id, :partner_id, '최근에 읽으신 책 중에 추천해 주실 만한 게 있을까요?', 'TEXT', 3,
     TRUE,  NOW() - INTERVAL '60 minute',  FALSE,
     NOW() - INTERVAL '65 minute',  NOW() - INTERVAL '60 minute'),
    (:chat_id, :partner_id, '에세이 좋아하시면 정말 좋아하실 것 같아요!', 'TEXT', 4,
     FALSE, NULL,                          FALSE,
     NOW() - INTERVAL '5 minute',  NOW() - INTERVAL '5 minute');

\echo '--- 시나리오 생성 결과 ---'
\echo '  파트너 user_id   :' :partner_id
\echo '  파트너 일기 id   :' :partner_diary_id
\echo '  matching_id     :' :matching_id
\echo '  exchange_id     :' :exchange_id
\echo '  chat_room_id    :' :chat_id

\echo '--- 본인이 참여 중인 채팅방 ---'
SELECT cr.id, cr.room_uuid, cr.status,
       ua.nickname AS user_a, ub.nickname AS user_b
  FROM chat_rooms cr
  JOIN users ua ON ua.id = cr.user_a_id
  JOIN users ub ON ub.id = cr.user_b_id
 WHERE cr.user_a_id = :tester_id OR cr.user_b_id = :tester_id;

\echo '--- 채팅방 메시지 ---'
SELECT m.sequence_id, u.nickname AS sender, m.type, m.is_read,
       LEFT(m.content, 40) AS preview, m.created_at
  FROM messages m
  LEFT JOIN users u ON u.id = m.sender_id
  JOIN chat_rooms cr ON cr.id = m.chat_room_id
 WHERE cr.user_a_id = :tester_id OR cr.user_b_id = :tester_id
 ORDER BY m.sequence_id;

COMMIT;

\echo '✅ 04_messaging_scenario.sql — 메시지 시나리오 시드 완료'
