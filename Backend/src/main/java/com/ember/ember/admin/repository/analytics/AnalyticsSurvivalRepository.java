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
 * 사용자 이탈 생존분석 Repository — 설계서 §3.14 (B-2.7).
 *
 * Kaplan-Meier 추정법 SQL-native 구현.
 *
 * 이벤트 정의:
 *   - Death(이탈): deactivated_at IS NOT NULL OR last_login_at < NOW() - :inactivityDays * INTERVAL '1 day'
 *   - Censored: 위 두 조건 미해당 (활동중)
 *
 * 수식:
 *   duration_i = min(deactivated_at, last_login_at + Δ, NOW()) - created_at  (일 단위, 최소 1일)
 *   at_risk(t) = |{i : duration_i >= t}|
 *   events(t) = |{i : duration_i = t AND event_occurred = 1}|
 *   S(t)      = ∏_{t_i <= t} (1 - d_i / n_i)
 *   Var(S(t)) = S(t)^2 * Σ_{t_i <= t} d_i / (n_i * (n_i - d_i))      ← Greenwood
 *   SE(t)     = sqrt(Var(S(t)))
 */
@Repository
@RequiredArgsConstructor
public class AnalyticsSurvivalRepository {

    @PersistenceContext
    private final EntityManager em;

    /**
     * 코호트 전체 규모 + 이벤트/검열 집계.
     *
     * @return [cohort_size, event_count, censored_count]
     */
    public Object[] aggregateCohortStats(LocalDate periodStart,
                                         LocalDate periodEnd,
                                         int inactivityThresholdDays) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                WITH base AS (
                    SELECT u.id,
                           CASE
                               WHEN u.deactivated_at IS NOT NULL THEN 1
                               WHEN u.last_login_at IS NOT NULL
                                AND u.last_login_at < NOW() - (:inactivityDays || ' days')::interval THEN 1
                               ELSE 0
                           END AS event_occurred
                      FROM users u
                     WHERE u.created_at >= :startTs
                       AND u.created_at <  :endTs
                       AND u.deleted_at IS NULL
                )
                SELECT
                    COUNT(*)                                       AS cohort_size,
                    SUM(event_occurred)                            AS event_count,
                    SUM(CASE WHEN event_occurred = 0 THEN 1 ELSE 0 END) AS censored_count
                  FROM base
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);
        query.setParameter("inactivityDays", String.valueOf(inactivityThresholdDays));

        Object result = query.getSingleResult();
        if (result instanceof Object[] arr) return arr;
        return new Object[]{0L, 0L, 0L};
    }

    /**
     * Kaplan-Meier 생존 곡선 SQL-native 계산. 각 이벤트 시점별 at_risk/events 를 반환.
     * S(t) / stdError / CI 산출은 Service 계층에서 수행 (누적 곱 + Greenwood).
     *
     * @return [day, at_risk, events]  (day 는 이벤트가 1건 이상 발생한 시점만)
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> aggregateSurvivalPoints(LocalDate periodStart,
                                                  LocalDate periodEnd,
                                                  int inactivityThresholdDays) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                WITH survival_data AS (
                    SELECT u.id,
                           GREATEST(1, (EXTRACT(EPOCH FROM
                               COALESCE(u.deactivated_at,
                                        u.last_login_at + (:inactivityDays || ' days')::interval,
                                        NOW()) - u.created_at
                           ) / 86400.0)::int) AS duration_days,
                           CASE
                               WHEN u.deactivated_at IS NOT NULL THEN 1
                               WHEN u.last_login_at IS NOT NULL
                                AND u.last_login_at < NOW() - (:inactivityDays || ' days')::interval THEN 1
                               ELSE 0
                           END AS event_occurred
                      FROM users u
                     WHERE u.created_at >= :startTs
                       AND u.created_at <  :endTs
                       AND u.deleted_at IS NULL
                ),
                event_times AS (
                    SELECT DISTINCT duration_days AS t
                      FROM survival_data
                     WHERE event_occurred = 1
                ),
                risk_events AS (
                    SELECT et.t,
                           (SELECT COUNT(*) FROM survival_data sd WHERE sd.duration_days >= et.t)                          AS n_at_risk,
                           (SELECT COUNT(*) FROM survival_data sd WHERE sd.duration_days = et.t AND sd.event_occurred = 1) AS d_events
                      FROM event_times et
                )
                SELECT t AS day, n_at_risk, d_events
                  FROM risk_events
                 WHERE d_events > 0
                 ORDER BY t ASC
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);
        query.setParameter("inactivityDays", String.valueOf(inactivityThresholdDays));

        List<Object[]> rows = (List<Object[]>) query.getResultList();
        return rows != null ? rows : new ArrayList<>();
    }
}
