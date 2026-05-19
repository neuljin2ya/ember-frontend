package com.ember.ember.admin.repository.analytics;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 사용자 퍼널·코호트 Repository — 설계서 §3.2.
 *
 * 스키마 매핑(설계서 ↔ 실제):
 *   - matching_recommendations + matching_responses(ACCEPT) → matchings (status='MATCHED', matched_at NOT NULL)
 *   - user_profiles.completed_at → users.onboarding_step (>= profileDoneStep)
 *   - diary_exchanges → exchange_rooms (started_at 미존재 → created_at 사용)
 *   - couples.matched_at → couples.confirmed_at
 *
 * 매칭 도달 판정:
 *   해당 사용자가 from_user_id 또는 to_user_id로 등장한 matchings 레코드 중
 *   status='MATCHED' 가 하나라도 있으면 "첫 매칭 수락" 도달로 본다.
 */
@Repository
@RequiredArgsConstructor
public class AnalyticsUserFunnelRepository {

    @PersistenceContext
    private final EntityManager em;

    /**
     * cohort=signup_date 모드. 주(월요일 시작) 단위로 가입자를 그룹핑하여 5단계 집계.
     *
     * @param periodStart     포함 (KST)
     * @param periodEnd       미포함 half-open
     * @param profileDoneStep 프로필 완료로 간주할 onboarding_step 최소값 (기본 1)
     * @return [cohort_week, stage1, stage2, stage3, stage4, stage5]
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> aggregateBySignupWeek(LocalDate periodStart,
                                                LocalDate periodEnd,
                                                int profileDoneStep) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                WITH cohort AS (
                    SELECT
                        u.id,
                        DATE_TRUNC('week', u.created_at AT TIME ZONE 'Asia/Seoul')::date AS cohort_week,
                        u.onboarding_step
                      FROM users u
                     WHERE u.created_at >= :startTs
                       AND u.created_at <  :endTs
                       AND u.deleted_at IS NULL
                ),
                profile_done AS (
                    SELECT id FROM cohort WHERE onboarding_step >= :profileDoneStep
                ),
                first_match AS (
                    SELECT DISTINCT c.id
                      FROM cohort c
                     WHERE EXISTS (
                        SELECT 1 FROM matchings m
                         WHERE m.status = 'MATCHED'
                           AND m.matched_at IS NOT NULL
                           AND (m.from_user_id = c.id OR m.to_user_id = c.id)
                     )
                ),
                first_exchange AS (
                    SELECT DISTINCT c.id
                      FROM cohort c
                     WHERE EXISTS (
                        SELECT 1 FROM exchange_rooms e
                         WHERE e.user_a_id = c.id OR e.user_b_id = c.id
                     )
                ),
                first_couple AS (
                    SELECT DISTINCT c.id
                      FROM cohort c
                     WHERE EXISTS (
                        SELECT 1 FROM couples cp
                         WHERE cp.user_a_id = c.id OR cp.user_b_id = c.id
                     )
                )
                SELECT
                    c.cohort_week,
                    COUNT(DISTINCT c.id)                                      AS stage1_signup,
                    COUNT(DISTINCT CASE WHEN pd.id IS NOT NULL THEN c.id END) AS stage2_profile,
                    COUNT(DISTINCT CASE WHEN fm.id IS NOT NULL THEN c.id END) AS stage3_match,
                    COUNT(DISTINCT CASE WHEN fe.id IS NOT NULL THEN c.id END) AS stage4_exchange,
                    COUNT(DISTINCT CASE WHEN fc.id IS NOT NULL THEN c.id END) AS stage5_couple
                  FROM cohort c
                  LEFT JOIN profile_done   pd ON pd.id = c.id
                  LEFT JOIN first_match    fm ON fm.id = c.id
                  LEFT JOIN first_exchange fe ON fe.id = c.id
                  LEFT JOIN first_couple   fc ON fc.id = c.id
                 GROUP BY c.cohort_week
                 ORDER BY c.cohort_week ASC
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);
        query.setParameter("profileDoneStep", profileDoneStep);

        List<Object[]> rows = (List<Object[]>) query.getResultList();
        return rows != null ? rows : new ArrayList<>();
    }

    /**
     * cohort=first_match_date 모드. 기간 내 첫 MATCHED 성사일을 기준으로 주 단위 코호트 구성.
     * 매칭 이후의 3단계(match → exchange → couple) 퍼널만 의미 있다 — 설계서 §3.2.4.
     *
     * @return [cohort_week, stage3_match, stage4_exchange, stage5_couple]
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> aggregateByFirstMatchWeek(LocalDate periodStart,
                                                    LocalDate periodEnd) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                WITH cohort AS (
                    -- 각 사용자의 "첫 MATCHED 성사 시각" 을 계산 후 기간 필터
                    SELECT user_id, first_matched_at,
                           DATE_TRUNC('week', first_matched_at AT TIME ZONE 'Asia/Seoul')::date AS cohort_week
                      FROM (
                        SELECT CASE WHEN m.from_user_id < m.to_user_id
                                    THEN m.from_user_id ELSE m.to_user_id END AS user_id,
                               MIN(m.matched_at) AS first_matched_at
                          FROM matchings m
                         WHERE m.status = 'MATCHED' AND m.matched_at IS NOT NULL
                         GROUP BY 1
                        UNION ALL
                        SELECT CASE WHEN m.from_user_id < m.to_user_id
                                    THEN m.to_user_id ELSE m.from_user_id END AS user_id,
                               MIN(m.matched_at) AS first_matched_at
                          FROM matchings m
                         WHERE m.status = 'MATCHED' AND m.matched_at IS NOT NULL
                         GROUP BY 1
                      ) agg
                     WHERE first_matched_at >= :startTs
                       AND first_matched_at <  :endTs
                ),
                dedup_cohort AS (
                    -- 한 사용자가 양쪽 UNION 에 나올 수 있으니 MIN 으로 한 건만 남김
                    SELECT user_id, MIN(first_matched_at) AS first_matched_at,
                           MIN(cohort_week) AS cohort_week
                      FROM cohort GROUP BY user_id
                ),
                first_exchange AS (
                    SELECT DISTINCT c.user_id
                      FROM dedup_cohort c
                     WHERE EXISTS (
                        SELECT 1 FROM exchange_rooms e
                         WHERE e.user_a_id = c.user_id OR e.user_b_id = c.user_id
                     )
                ),
                first_couple AS (
                    SELECT DISTINCT c.user_id
                      FROM dedup_cohort c
                     WHERE EXISTS (
                        SELECT 1 FROM couples cp
                         WHERE cp.user_a_id = c.user_id OR cp.user_b_id = c.user_id
                     )
                )
                SELECT
                    c.cohort_week,
                    COUNT(DISTINCT c.user_id)                                     AS stage3_match,
                    COUNT(DISTINCT CASE WHEN fe.user_id IS NOT NULL THEN c.user_id END) AS stage4_exchange,
                    COUNT(DISTINCT CASE WHEN fc.user_id IS NOT NULL THEN c.user_id END) AS stage5_couple
                  FROM dedup_cohort c
                  LEFT JOIN first_exchange fe ON fe.user_id = c.user_id
                  LEFT JOIN first_couple   fc ON fc.user_id = c.user_id
                 GROUP BY c.cohort_week
                 ORDER BY c.cohort_week ASC
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        List<Object[]> rows = (List<Object[]>) query.getResultList();
        return rows != null ? rows : new ArrayList<>();
    }
}
