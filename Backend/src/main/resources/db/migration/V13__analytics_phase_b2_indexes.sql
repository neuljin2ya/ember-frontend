-- V13: 분석 API Phase B-2 (일기/교환 패턴 + 생존분석) 보조 인덱스
-- 근거: docs/md/architecture/analytics/Ember_분석API_데이터설계서_v0.2.md §3.8~§3.14 (신규 예정)
-- 범위: B-2.1 시간 히트맵 / B-2.2 길이·품질 / B-2.3 감정 추이 / B-2.4 주제 참여
--       B-2.5 응답률 / B-2.6 턴→채팅 퍼널 / B-2.7 Kaplan-Meier 생존분석
-- 주의: V11/V12 에서 추가된 인덱스는 중복 생성하지 않는다 (IF NOT EXISTS 방어).

-- [X1] 교환일기 턴 퍼널 (§3.13) — exchange_diaries
-- (room_id, turn_number) 복합 — 방별 턴 순서 스캔 최적화.
CREATE INDEX IF NOT EXISTS ix_exchange_diaries_room_turn
    ON exchange_diaries(room_id, turn_number);

-- [X2] 교환일기 응답 지연시간 (§3.12) — submitted_at 기준 p50/p90 계산
CREATE INDEX IF NOT EXISTS ix_exchange_diaries_room_submitted
    ON exchange_diaries(room_id, submitted_at)
    WHERE submitted_at IS NOT NULL;

-- [S1] Kaplan-Meier 생존분석 (§3.14) — users 이탈 이벤트 시점 조회
-- deactivated_at 기준 이탈 사용자 + 비활성 이탈 판정용 last_login_at 복합.
CREATE INDEX IF NOT EXISTS ix_users_deactivated_created
    ON users(deactivated_at, created_at)
    WHERE deleted_at IS NULL AND deactivated_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS ix_users_last_login_active
    ON users(last_login_at)
    WHERE deleted_at IS NULL AND status = 'ACTIVE';

-- [D2] 일기 시간 히트맵 (§3.8) — 기존 ix_diaries_created_completed 재사용.
-- [D3] 일기 길이 분포 (§3.9) — content LENGTH 계산은 seq scan 불가피.
--       데이터량 증가 시 diary_stats materialized view 도입 검토 (§4.5).
-- [D4] 주제 참여 (§3.11) — diaries(topic_id, created_at) 추가 검토되나
--       초기엔 ix_diaries_created_completed 로 커버 가능.

-- 주석: diary_keywords 는 V11 의 ix_diary_keywords_tagtype_label + ix_diary_keywords_diary 조합으로
--       감정 시계열 TopN 집계(§3.10) 충분. 추가 인덱스 없음.
