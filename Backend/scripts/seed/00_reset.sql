-- =============================================================================
-- 00_reset.sql — 시드 더미 데이터 안전 삭제
-- ---------------------------------------------------------------------------
-- 이메일 prefix 'seed_' 로 식별되는 더미 사용자와 그 관련 데이터만 정리합니다.
-- 본인(:tester_id) 계정은 건드리지 않으나, 본인과 더미 사이의 matching /
-- exchange_room / chat_room / messages 는 함께 삭제됩니다.
--
-- 사용:
--   psql ... -v tester_id=123 -f 00_reset.sql
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1) 본인-더미 사이 messages → chat_rooms → exchange_rooms → matchings 순서로 정리
WITH dummy_users AS (
    SELECT id FROM users WHERE email LIKE 'seed_%@dev.local'
),
involved_chat_rooms AS (
    SELECT id FROM chat_rooms
    WHERE user_a_id IN (SELECT id FROM dummy_users)
       OR user_b_id IN (SELECT id FROM dummy_users)
       OR user_a_id = :tester_id
       OR user_b_id = :tester_id
),
involved_exchange_rooms AS (
    SELECT id FROM exchange_rooms
    WHERE user_a_id IN (SELECT id FROM dummy_users)
       OR user_b_id IN (SELECT id FROM dummy_users)
       OR user_a_id = :tester_id
       OR user_b_id = :tester_id
)
DELETE FROM messages WHERE chat_room_id IN (SELECT id FROM involved_chat_rooms);

DELETE FROM chat_rooms
WHERE user_a_id IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local')
   OR user_b_id IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local');

DELETE FROM exchange_diaries
WHERE room_id IN (
    SELECT id FROM exchange_rooms
    WHERE user_a_id IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local')
       OR user_b_id IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local')
);

DELETE FROM exchange_rooms
WHERE user_a_id IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local')
   OR user_b_id IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local');

DELETE FROM matchings
WHERE from_user_id IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local')
   OR to_user_id   IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local');

-- 2) 더미들의 일기 + 키워드
DELETE FROM diary_keywords
WHERE diary_id IN (
    SELECT id FROM diaries
    WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local')
);

DELETE FROM diaries
WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local');

-- 3) 더미들의 이상형 키워드 / 동의 기록
DELETE FROM user_ideal_keywords
WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local');

DELETE FROM ai_consent_log
WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'seed_%@dev.local');

-- 4) 더미 사용자 (soft delete 아닌 hard delete — 더미는 추적 가치 없음)
DELETE FROM users WHERE email LIKE 'seed_%@dev.local';

COMMIT;

\echo '✅ 00_reset.sql — 더미 시드 데이터 정리 완료'
