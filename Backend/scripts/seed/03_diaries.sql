-- =============================================================================
-- 03_diaries.sql — 각 더미의 일기 (교환 추천용)
-- ---------------------------------------------------------------------------
-- - 추천 후보 5명(candidate1~5)의 오늘자 일기 5편 (visibility=EXCHANGE_ONLY, COMPLETED)
-- - 메시지 상대(partner)의 일기 1편 (매칭 기준이 된 일기 — 04_messaging_scenario.sql 에서 사용)
-- - 본문은 모두 100자 이상 (스펙 4.1: 최소 100자)
--
-- 사용:
--   psql ... -v tester_id=123 -f 03_diaries.sql
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- ── 일기 INSERT (멱등) ─────────────────────────────────────────────────────────
INSERT INTO diaries (
    user_id, title, content, date, status, analysis_status,
    summary, category, visibility, is_exchanged,
    created_at, modified_at
)
SELECT u.id, v.title, v.content, v.diary_date, 'ANALYZED', 'COMPLETED',
       v.summary, v.category, 'EXCHANGE_ONLY', FALSE,
       NOW() - (v.hours_ago || ' hour')::INTERVAL,
       NOW() - (v.hours_ago || ' hour')::INTERVAL
  FROM users u
  JOIN (VALUES
    ('seed_partner@dev.local',
     '오늘의 작은 행복',
     '아침에 일찍 일어나서 동네 공원을 산책했다. 공기가 차가웠지만 햇살이 따뜻해서 기분이 좋았다. 카페에 들러 따뜻한 라떼 한 잔을 마시면서 책을 읽었고, 오랜만에 여유로운 주말을 보내는 기분이 들었다. 작지만 이런 일상이 모여 삶을 풍요롭게 만든다는 걸 느꼈다.',
     CURRENT_DATE - INTERVAL '5 day', 'AI 요약: 일상의 여유와 소소한 행복을 담은 따뜻한 일기', 'DAILY', 120),

    ('seed_candidate1@dev.local',
     '책 한 권의 위로',
     '요즘 일이 많아서 마음이 자주 무거웠는데, 어제 도서관에서 빌린 에세이를 읽으면서 많은 위로를 받았다. 작가가 자신의 불완전함을 솔직하게 풀어내는 글이 마치 내 이야기처럼 다가왔다. 우리가 완벽하지 않아도 괜찮다는 메시지가 오래도록 마음에 남는다.',
     CURRENT_DATE, 'AI 요약: 책에서 위로받은 차분한 내면 성찰', 'EMOTION', 2),

    ('seed_candidate2@dev.local',
     '친구들과의 깜짝 모임',
     '오늘 갑작스럽게 친구들에게 연락이 와서 즉흥적으로 모였다. 평소엔 계획적으로 만나야 직성이 풀리는데, 오늘처럼 무계획으로 만나는 시간도 꽤 즐겁다는 걸 깨달았다. 우스운 얘기로 한참 웃고 떠들면서 스트레스가 풀렸다. 다음에도 이런 즉흥적 모임을 자주 해야겠다.',
     CURRENT_DATE, 'AI 요약: 친구와의 즉흥적 만남에서 얻은 웃음', 'RELATIONSHIP', 4),

    ('seed_candidate3@dev.local',
     '러닝 30분의 기록',
     '오랜만에 한강에서 러닝을 했다. 30분 동안 천천히 페이스를 유지하며 뛰었는데, 끝나고 나서 느껴지는 성취감이 정말 좋았다. 운동은 결국 자기 자신과의 약속이라는 생각이 들었다. 다음 주에는 거리를 5km까지 늘려보고 싶다는 작은 목표가 생겼다.',
     CURRENT_DATE, 'AI 요약: 러닝을 통한 성취감과 자기 약속', 'GROWTH', 6),

    ('seed_candidate4@dev.local',
     '엄마와의 통화',
     '주말 저녁에 엄마와 오랜 통화를 했다. 일주일 동안 있었던 일들을 시시콜콜 풀어놓는데도 엄마는 끝까지 다 들어주셨다. 통화를 끊고 나서 괜히 마음이 따뜻해졌고, 다음에 집에 갈 때는 좋아하시는 빵을 사가야겠다는 생각이 들었다. 가족이 주는 안정감은 그 무엇과도 바꿀 수 없다.',
     CURRENT_DATE, 'AI 요약: 가족 통화에서 느낀 따뜻함과 안정감', 'RELATIONSHIP', 8),

    ('seed_candidate5@dev.local',
     '혼자만의 시간',
     '오늘은 일부러 약속을 잡지 않고 혼자만의 시간을 가졌다. 좋아하는 영화 한 편을 보고, 한참 멍하니 창밖을 바라봤다. 사람들과의 시간도 좋지만, 가끔은 이런 고요한 시간이 진짜 내 마음을 마주하게 해준다. 혼자 있어도 외롭지 않은 사람이 되고 싶다는 생각을 했다.',
     CURRENT_DATE, 'AI 요약: 혼자 있는 시간에서 찾은 평온', 'EMOTION', 10)
  ) AS v(email, title, content, diary_date, summary, category, hours_ago)
    ON v.email = u.email
ON CONFLICT (user_id, date) DO UPDATE
  SET content         = EXCLUDED.content,
      title           = EXCLUDED.title,
      status          = EXCLUDED.status,
      analysis_status = EXCLUDED.analysis_status,
      summary         = EXCLUDED.summary,
      category        = EXCLUDED.category,
      visibility      = EXCLUDED.visibility,
      modified_at     = NOW();

-- ── diary_keywords 시드 ──────────────────────────────────────────────────────
-- 실제 컬럼: (diary_id, tag_type, label, score) — AI 분석 결과 태그 직접 주입.
-- tag_type 값: EMOTION / LIFESTYLE / TONE / RELATIONSHIP_STYLE (DevController 시뮬레이션 기준)
INSERT INTO diary_keywords (diary_id, tag_type, label, score, created_at, modified_at)
SELECT d.id, t.tag_type, t.label, t.score, NOW(), NOW()
  FROM diaries d
  JOIN users   u ON u.id = d.user_id
 CROSS JOIN (VALUES
    ('EMOTION',            '따뜻함',           0.850),
    ('EMOTION',            '여유로움',         0.780),
    ('LIFESTYLE',          '계획적',           0.720),
    ('TONE',               '감성적',           0.750),
    ('RELATIONSHIP_STYLE', '대화형 갈등대응',  0.700)
 ) AS t(tag_type, label, score)
 WHERE u.email LIKE 'seed_%@dev.local'
   AND NOT EXISTS (
       SELECT 1 FROM diary_keywords dk
        WHERE dk.diary_id = d.id AND dk.label = t.label
   );

\echo '--- 시드된 일기 ---'
SELECT d.id, u.nickname, LEFT(d.title, 20) AS title, d.date, d.status,
       d.analysis_status, d.visibility, d.is_exchanged
  FROM diaries d
  JOIN users   u ON u.id = d.user_id
 WHERE u.email LIKE 'seed_%@dev.local'
 ORDER BY u.id, d.date DESC;

COMMIT;

\echo '✅ 03_diaries.sql — 더미 일기 6편 시드 완료'
