-- =============================================================================
-- 01_dummy_users.sql — 더미 사용자 6명 생성
-- ---------------------------------------------------------------------------
-- 본인(:tester_id)과 메시지를 주고 받을 상대 1명 + 교환일기 추천 후보 5명.
-- 모두 ROLE_USER · onboarding_step=2 · ACTIVE 상태로 셋업.
--
-- 사용:
--   psql ... -v tester_id=123 -f 01_dummy_users.sql
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ── 더미 사용자 6명 INSERT (멱등) ──────────────────────────────────────────────
INSERT INTO users (
    email, real_name, nickname, birth_date, gender,
    sido, sigungu, school,
    status, role, onboarding_step,
    last_login_at, last_nickname_changed_at, tutorial_completed_at,
    created_at, modified_at
)
VALUES
    ('seed_partner@dev.local',    '김파트', '씨앗파트너',   '1997-03-12', 'FEMALE',
     '서울특별시', '강남구',   '연세대학교',
     'ACTIVE', 'ROLE_USER', 2,
     NOW() - INTERVAL '1 hour', NOW() - INTERVAL '5 day', NOW() - INTERVAL '4 day',
     NOW() - INTERVAL '10 day', NOW() - INTERVAL '1 hour'),

    ('seed_candidate1@dev.local', '이추천', '추천후보01',  '1996-07-25', 'FEMALE',
     '서울특별시', '마포구',   '서울대학교',
     'ACTIVE', 'ROLE_USER', 2,
     NOW() - INTERVAL '2 hour', NOW() - INTERVAL '7 day', NOW() - INTERVAL '6 day',
     NOW() - INTERVAL '14 day', NOW() - INTERVAL '2 hour'),

    ('seed_candidate2@dev.local', '박추천', '추천후보02',  '1998-11-03', 'FEMALE',
     '경기도',     '성남시 분당구', '고려대학교',
     'ACTIVE', 'ROLE_USER', 2,
     NOW() - INTERVAL '3 hour', NOW() - INTERVAL '9 day', NOW() - INTERVAL '8 day',
     NOW() - INTERVAL '18 day', NOW() - INTERVAL '3 hour'),

    ('seed_candidate3@dev.local', '최추천', '추천후보03',  '1995-05-18', 'FEMALE',
     '부산광역시', '해운대구', '부산대학교',
     'ACTIVE', 'ROLE_USER', 2,
     NOW() - INTERVAL '4 hour', NOW() - INTERVAL '11 day', NOW() - INTERVAL '10 day',
     NOW() - INTERVAL '22 day', NOW() - INTERVAL '4 hour'),

    ('seed_candidate4@dev.local', '정추천', '추천후보04',  '1999-02-09', 'FEMALE',
     '서울특별시', '용산구',   '한양대학교',
     'ACTIVE', 'ROLE_USER', 2,
     NOW() - INTERVAL '5 hour', NOW() - INTERVAL '13 day', NOW() - INTERVAL '12 day',
     NOW() - INTERVAL '26 day', NOW() - INTERVAL '5 hour'),

    ('seed_candidate5@dev.local', '한추천', '추천후보05',  '1996-12-30', 'FEMALE',
     '인천광역시', '연수구',   '인하대학교',
     'ACTIVE', 'ROLE_USER', 2,
     NOW() - INTERVAL '6 hour', NOW() - INTERVAL '15 day', NOW() - INTERVAL '14 day',
     NOW() - INTERVAL '30 day', NOW() - INTERVAL '6 hour')
ON CONFLICT (email) DO NOTHING;

-- 본인 정보 미리보기 (디버깅용)
\echo '--- 본인 정보 (:tester_id) ---'
SELECT id, email, nickname, status, role, onboarding_step
  FROM users WHERE id = :tester_id;

\echo '--- 더미 사용자 6명 (시드) ---'
SELECT id, email, nickname, status, role
  FROM users WHERE email LIKE 'seed_%@dev.local'
  ORDER BY id;

COMMIT;

\echo '✅ 01_dummy_users.sql — 더미 사용자 6명 생성 완료'
