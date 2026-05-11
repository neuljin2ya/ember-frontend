-- =============================================================================
-- 02_keywords_consents.sql — 키워드 마스터 + 더미들의 이상형/AI 동의
-- ---------------------------------------------------------------------------
-- - keywords 마스터 데이터(없으면 기본 12개 주입)
-- - 본인(:tester_id)과 더미 6명에 이상형 키워드 3개씩 매핑
-- - AI 분석/매칭 동의 로그 (분석 파이프라인이 SKIPPED 되지 않도록)
--
-- 사용:
--   psql ... -v tester_id=123 -f 02_keywords_consents.sql
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ── 키워드 마스터 (이미 있으면 SKIP) ───────────────────────────────────────────
INSERT INTO keywords (label, category, weight, display_order, is_active, created_at, modified_at)
VALUES
    ('따뜻한',    'PERSONALITY', 0.80, 1,  TRUE, NOW(), NOW()),
    ('차분한',    'PERSONALITY', 0.70, 2,  TRUE, NOW(), NOW()),
    ('유머러스', 'PERSONALITY', 0.75, 3,  TRUE, NOW(), NOW()),
    ('계획적',    'LIFESTYLE',   0.70, 4,  TRUE, NOW(), NOW()),
    ('즉흥적',    'LIFESTYLE',   0.60, 5,  TRUE, NOW(), NOW()),
    ('활동적',    'LIFESTYLE',   0.70, 6,  TRUE, NOW(), NOW()),
    ('감성적',    'TONE',        0.70, 7,  TRUE, NOW(), NOW()),
    ('이성적',    'TONE',        0.70, 8,  TRUE, NOW(), NOW()),
    ('적극적 소통', 'RELATIONSHIP', 0.80, 9,  TRUE, NOW(), NOW()),
    ('애정표현 적극적', 'RELATIONSHIP', 0.75, 10, TRUE, NOW(), NOW()),
    ('독립적',    'RELATIONSHIP', 0.65, 11, TRUE, NOW(), NOW()),
    ('대화형 갈등대응', 'RELATIONSHIP', 0.70, 12, TRUE, NOW(), NOW())
ON CONFLICT (label) DO NOTHING;

-- ── 이상형 키워드 매핑 (본인 + 더미) ──────────────────────────────────────────
-- 본인 → 따뜻한, 유머러스, 감성적
INSERT INTO user_ideal_keywords (user_id, keyword_id, created_at, modified_at)
SELECT :tester_id, k.id, NOW(), NOW()
  FROM keywords k
 WHERE k.label IN ('따뜻한', '유머러스', '감성적')
ON CONFLICT (user_id, keyword_id) DO NOTHING;

-- 더미 B (씨앗파트너) → 따뜻한, 감성적, 적극적 소통 (본인과 어느 정도 교집합)
INSERT INTO user_ideal_keywords (user_id, keyword_id, created_at, modified_at)
SELECT u.id, k.id, NOW(), NOW()
  FROM users u, keywords k
 WHERE u.email = 'seed_partner@dev.local'
   AND k.label IN ('따뜻한', '감성적', '적극적 소통')
ON CONFLICT (user_id, keyword_id) DO NOTHING;

-- 추천 후보 5명 — 각자 다른 조합
INSERT INTO user_ideal_keywords (user_id, keyword_id, created_at, modified_at)
SELECT u.id, k.id, NOW(), NOW()
  FROM users u, keywords k
 WHERE u.email = 'seed_candidate1@dev.local'
   AND k.label IN ('차분한', '계획적', '이성적')
ON CONFLICT (user_id, keyword_id) DO NOTHING;

INSERT INTO user_ideal_keywords (user_id, keyword_id, created_at, modified_at)
SELECT u.id, k.id, NOW(), NOW()
  FROM users u, keywords k
 WHERE u.email = 'seed_candidate2@dev.local'
   AND k.label IN ('유머러스', '즉흥적', '대화형 갈등대응')
ON CONFLICT (user_id, keyword_id) DO NOTHING;

INSERT INTO user_ideal_keywords (user_id, keyword_id, created_at, modified_at)
SELECT u.id, k.id, NOW(), NOW()
  FROM users u, keywords k
 WHERE u.email = 'seed_candidate3@dev.local'
   AND k.label IN ('활동적', '독립적', '계획적')
ON CONFLICT (user_id, keyword_id) DO NOTHING;

INSERT INTO user_ideal_keywords (user_id, keyword_id, created_at, modified_at)
SELECT u.id, k.id, NOW(), NOW()
  FROM users u, keywords k
 WHERE u.email = 'seed_candidate4@dev.local'
   AND k.label IN ('따뜻한', '감성적', '애정표현 적극적')
ON CONFLICT (user_id, keyword_id) DO NOTHING;

INSERT INTO user_ideal_keywords (user_id, keyword_id, created_at, modified_at)
SELECT u.id, k.id, NOW(), NOW()
  FROM users u, keywords k
 WHERE u.email = 'seed_candidate5@dev.local'
   AND k.label IN ('차분한', '이성적', '독립적')
ON CONFLICT (user_id, keyword_id) DO NOTHING;

-- ── AI 동의 기록 (분석 파이프라인 정상 동작용) ────────────────────────────────
-- ai_consent_log 컬럼: (user_id, consent_type, action, acted_at, ip_address) + (created_at, modified_at)
-- action 값 = GRANTED / REVOKED. AiConsentLogRepository는 acted_at DESC로 최신 로그 1건을 조회.
-- 동일 (user_id, consent_type) 중복 GRANTED 로그가 있어도 무방하지만, 시드 실행 멱등을 위해
-- 기존 시드 로그가 있으면 건너뜁니다 (확장 시 NOT EXISTS 조건).
-- 주의: ai_consent_log 는 BaseEntity 를 상속하지 않아 created_at / modified_at 컬럼이 없습니다.
INSERT INTO ai_consent_log (user_id, consent_type, action, acted_at, ip_address)
SELECT u.id, ct.consent_type, 'GRANTED', NOW(), '127.0.0.1'
  FROM users u
 CROSS JOIN (VALUES ('AI_ANALYSIS'), ('AI_DATA_USAGE')) AS ct(consent_type)
 WHERE (u.email LIKE 'seed_%@dev.local' OR u.id = :tester_id)
   AND NOT EXISTS (
       SELECT 1 FROM ai_consent_log a
        WHERE a.user_id = u.id
          AND a.consent_type = ct.consent_type
          AND a.action = 'GRANTED'
   );

\echo '--- 이상형 키워드 매핑 현황 ---'
SELECT u.email, k.label
  FROM user_ideal_keywords uik
  JOIN users    u ON u.id = uik.user_id
  JOIN keywords k ON k.id = uik.keyword_id
 WHERE u.email LIKE 'seed_%@dev.local' OR u.id = :tester_id
 ORDER BY u.id, k.display_order;

COMMIT;

\echo '✅ 02_keywords_consents.sql — 키워드 마스터 + 이상형 + 동의 시드 완료'
