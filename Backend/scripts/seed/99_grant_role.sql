-- =============================================================================
-- 99_grant_role.sql — 본인(:tester_id)을 ROLE_USER · onboarding_step=2 로 승격
-- ---------------------------------------------------------------------------
-- /api/dev/register 로 만든 본인 계정은 기본 ROLE_GUEST, onboarding_step=0 입니다.
-- 매칭/탐색/일기/채팅 API 는 ROLE_USER + onboarding_step=2 가 필요하므로
-- 시드 후 이 스크립트를 한 번 더 실행해 즉시 사용 가능한 상태로 만듭니다.
--
-- 추가로 본인 프로필을 임의 값으로 채워 둡니다 (UI 노출 검증용).
--
-- 사용:
--   psql ... -v tester_id=123 -f 99_grant_role.sql
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

UPDATE users
   SET real_name                = COALESCE(real_name, '테스터'),
       nickname                 = COALESCE(nickname, 'tester_' || :tester_id),
       birth_date               = COALESCE(birth_date, DATE '1996-01-01'),
       gender                   = COALESCE(gender, 'MALE'),
       sido                     = COALESCE(sido, '서울특별시'),
       sigungu                  = COALESCE(sigungu, '서초구'),
       school                   = COALESCE(school, '서울대학교'),
       status                   = 'ACTIVE',
       role                     = 'ROLE_USER',
       onboarding_step          = 2,
       last_login_at            = NOW(),
       last_nickname_changed_at = COALESCE(last_nickname_changed_at, NOW()),
       tutorial_completed_at    = COALESCE(tutorial_completed_at, NOW()),
       modified_at              = NOW()
 WHERE id = :tester_id;

\echo '--- 본인 계정 최종 상태 ---'
SELECT id, email, nickname, status, role, onboarding_step,
       sido, sigungu, school
  FROM users WHERE id = :tester_id;

COMMIT;

\echo '✅ 99_grant_role.sql — 본인 계정을 ROLE_USER로 승격 완료'
\echo ''
\echo '👉 이제 새 토큰을 발급받아 사용하세요:'
\echo '   GET http://localhost:8080/api/dev/token?userId=:tester_id'
