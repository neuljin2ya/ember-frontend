-- V12: 분석 API Phase B-1.2~B-1.7 보조 인덱스
-- 근거: docs/md/architecture/analytics/Ember_분석API_데이터설계서_v0.2.md §3.7.5 / §4.3
--       §3.4.5 / §3.5.5 / §3.6.3
-- 범위: B-1.2 사용자 퍼널·코호트 / B-1.3 키워드 TopN / B-1.4 세그먼트 / B-1.5 여정 / B-1.6 AI / B-1.7 매칭 다양성
-- 주의: V11 에서 이미 추가된 인덱스는 중복 생성하지 않는다 (IF NOT EXISTS 방어).

-- [M2] 매칭 다양성·재추천 self-join (§3.7.5)
-- (from_user_id, to_user_id, created_at) 복합 인덱스 — 14일 이내 재추천 조회 최적화.
-- 필터 순서: from_user_id → to_user_id → created_at (<, >= 범위)
CREATE INDEX IF NOT EXISTS ix_matchings_from_to_created
    ON matchings(from_user_id, to_user_id, created_at DESC);

-- 후보별 등장 빈도 집계 (candidate_dist CTE)
CREATE INDEX IF NOT EXISTS ix_matchings_to_created
    ON matchings(to_user_id, created_at);

-- [L1] 라이프스타일 분석 이력 (§3.6 AI 성능 DB Fallback)
-- analyzed_at 기준 기간 필터 + 일별 버킷 집계용
CREATE INDEX IF NOT EXISTS ix_lifestyle_log_analyzed_at
    ON lifestyle_analysis_log(analyzed_at);

-- [E2] 교환방 시작 시점 추정 (§3.5 여정 분포 Fallback)
-- user_a/user_b 기준 MIN(created_at) 서브쿼리 최적화용 (V11 에 userA/userB_created 가 있지만
-- 여정 Fallback 은 created_at ASC 스캔이 잦아 기존 인덱스가 충분 — 추가 인덱스 없음)

-- [U2] users 퍼널 단계 탐색 (§3.2 사용자 퍼널)
-- first_match/first_exchange/first_couple EXISTS 서브쿼리 최적화.
-- matchings (from_user_id, status), (to_user_id, status) 가 이미 V1 baseline/V11 으로 커버되므로 추가 없음.
-- couples, exchange_rooms 의 user_a/user_b 인덱스는 V1 baseline + V11 에 존재.

-- 주석: user_activity_events (event_type, occurred_at) 는 V11 이미 존재.
--       추가 인덱스는 데이터 성장 시 pg_stat_statements 분석 후 CONCURRENTLY 재배포 예정 (v0.2 §4.8).
