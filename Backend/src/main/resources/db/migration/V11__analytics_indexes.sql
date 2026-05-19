-- V11: 분석 API (§18) 전용 인덱스
-- 목적: Ember 분석 API 7종 P95 < 2s 달성 근거 인덱스 선적용.
-- 근거: docs/md/architecture/analytics/Ember_분석API_데이터설계서_v0.2.md §4.3 (인덱스 전략) + 부록 B.
-- 참고: Flyway는 기본적으로 마이그레이션을 트랜잭션으로 감싸지만, PostgreSQL CONCURRENTLY는
--       트랜잭션 밖에서만 실행되므로 이 파일은 동시성 인덱스 대신 일반 인덱스를 사용한다.
--       초기 스키마에선 데이터량이 작아 문제 없음. 운영 스케일 진입 시점에 별도 V/R 스크립트
--       (--Transactional:false)로 CONCURRENTLY 재적용 예정. (§4.4.6 Runbook 참조)

-- [M1] 매칭 퍼널 (§3.1) — matchings 단일 테이블로 매핑
CREATE INDEX IF NOT EXISTS ix_matchings_created_from_status
    ON matchings(created_at, from_user_id, status);

CREATE INDEX IF NOT EXISTS ix_matchings_matched_status
    ON matchings(matched_at, status) WHERE matched_at IS NOT NULL;

-- [E1] 교환일기 (§3.1) — exchange_rooms
CREATE INDEX IF NOT EXISTS ix_exchange_rooms_userA_created
    ON exchange_rooms(user_a_id, created_at);

CREATE INDEX IF NOT EXISTS ix_exchange_rooms_userB_created
    ON exchange_rooms(user_b_id, created_at);

CREATE INDEX IF NOT EXISTS ix_exchange_rooms_status_created
    ON exchange_rooms(status, created_at);

-- [C1] 커플 (§3.1) — couples
CREATE INDEX IF NOT EXISTS ix_couples_confirmed_status
    ON couples(confirmed_at, status);

-- [U1] 사용자 퍼널 (§3.2) — users
-- deleted_at 기반 soft delete + status=ACTIVE 만 조회하는 쿼리 최적화
CREATE INDEX IF NOT EXISTS ix_users_created_active
    ON users(created_at)
    WHERE deleted_at IS NULL AND status = 'ACTIVE';

CREATE INDEX IF NOT EXISTS ix_users_segment_active
    ON users(gender, sido, birth_date)
    WHERE deleted_at IS NULL AND status = 'ACTIVE';

-- [K1] 키워드 분석 (§3.3) — diary_keywords
-- tag_type + label 조합이 TopN 집계의 GROUP BY 키
CREATE INDEX IF NOT EXISTS ix_diary_keywords_tagtype_label
    ON diary_keywords(tag_type, label);

CREATE INDEX IF NOT EXISTS ix_diary_keywords_diary
    ON diary_keywords(diary_id);

-- [D1] 일기 (§3.3) — 완료된 일기만 조회
CREATE INDEX IF NOT EXISTS ix_diaries_created_completed
    ON diaries(created_at)
    WHERE analysis_status = 'COMPLETED';

-- [V1] 활동 이벤트 (§3.5) — 이벤트 유형별 시계열
-- (user_id, occurred_at) 인덱스는 JPA @Index로 이미 생성됨 (idx_activity_user_occurred)
-- 여기선 event_type 기반 조회 최적화만 추가
CREATE INDEX IF NOT EXISTS ix_uae_event_type_occurred
    ON user_activity_events(event_type, occurred_at);

-- 주석: Rollup 테이블(§4.5)과 Range 월 파티션(§4.4)은 V12 이후 스프린트에서 점진 적용.
