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
 * 세그먼트 Overview Repository — 설계서 §3.4.
 *
 * groupBy 에 따라 세그먼트 차원(gender, age_group, region_code) 를 동적으로 구성한다.
 * 설계서의 "Star CTE 패턴" 을 축소 적용 — v1 은 metric 을 단일 택일(파라미터 :metric) 로 받는다.
 *
 * metric 값:
 *   - SIGNUP : 기간 내 users.created_at 가 속한 세그먼트 signups 수
 *   - ACTIVE : 기간 내 user_activity_events 에서 발생 사용자 distinct 수
 *   - DIARY  : 기간 내 diaries(COMPLETED) / diaries(ALL) 비율
 *   - ACCEPT : 기간 내 matchings MATCHED/ALL 비율
 *
 * Universe: 모수 표기를 위해 세그먼트별 ACTIVE 사용자 수(분모) 를 함께 반환한다.
 * HAVING 으로 users<kMin 세그먼트를 필터하지 않고 전체 반환 — 서비스 계층에서 masked 처리.
 */
@Repository
@RequiredArgsConstructor
public class AnalyticsSegmentRepository {

    @PersistenceContext
    private final EntityManager em;

    /**
     * @return [gender, age_group, region_code, users_cnt, numerator, denominator]
     *         numerator/denominator 는 metric 에 따라 의미가 달라짐.
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> aggregateSegments(LocalDate periodStart,
                                            LocalDate periodEnd,
                                            String metric,
                                            boolean byGender,
                                            boolean byAge,
                                            boolean byRegion) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String genderExpr = byGender
                ? "COALESCE(u.gender::text, 'UNKNOWN')"
                : "'ALL'";
        String ageExpr = byAge
                ? """
                  CASE
                      WHEN u.birth_date IS NULL THEN 'UNKNOWN'
                      WHEN AGE(u.birth_date) < INTERVAL '20 years' THEN 'LT20'
                      WHEN AGE(u.birth_date) < INTERVAL '25 years' THEN '20-24'
                      WHEN AGE(u.birth_date) < INTERVAL '30 years' THEN '25-29'
                      WHEN AGE(u.birth_date) < INTERVAL '35 years' THEN '30-34'
                      WHEN AGE(u.birth_date) < INTERVAL '40 years' THEN '35-39'
                      ELSE '40+'
                  END"""
                : "'ALL'";
        String regionExpr = byRegion
                ? "COALESCE(u.sido, 'UNKNOWN')"
                : "'ALL'";

        // metric 별 numerator/denominator 계산 분기
        String metricBlock = switch (metric == null ? "SIGNUP" : metric.toUpperCase()) {
            case "SIGNUP" -> """
                    , metric_rows AS (
                        SELECT u.id AS user_id,
                               1 AS numerator_flag,
                               1 AS denominator_flag
                          FROM users u
                         WHERE u.deleted_at IS NULL
                           AND u.created_at >= :startTs
                           AND u.created_at <  :endTs
                    )
                    """;
            case "ACTIVE" -> """
                    , metric_rows AS (
                        SELECT DISTINCT uae.user_id AS user_id,
                               1 AS numerator_flag,
                               1 AS denominator_flag
                          FROM user_activity_events uae
                         WHERE uae.occurred_at >= :startTs
                           AND uae.occurred_at <  :endTs
                    )
                    """;
            case "DIARY" -> """
                    , metric_rows AS (
                        SELECT d.user_id AS user_id,
                               SUM(CASE WHEN d.analysis_status = 'COMPLETED' THEN 1 ELSE 0 END) AS numerator_flag,
                               COUNT(*) AS denominator_flag
                          FROM diaries d
                         WHERE d.deleted_at IS NULL
                           AND d.created_at >= :startTs
                           AND d.created_at <  :endTs
                         GROUP BY d.user_id
                    )
                    """;
            case "ACCEPT" -> """
                    , metric_rows AS (
                        SELECT m.from_user_id AS user_id,
                               SUM(CASE WHEN m.status = 'MATCHED' THEN 1 ELSE 0 END) AS numerator_flag,
                               COUNT(*) AS denominator_flag
                          FROM matchings m
                         WHERE m.created_at >= :startTs
                           AND m.created_at <  :endTs
                         GROUP BY m.from_user_id
                    )
                    """;
            default -> throw new IllegalArgumentException("Unknown metric: " + metric);
        };

        String sql = """
                WITH segments AS (
                    SELECT
                        u.id AS user_id,
                        %s AS gender,
                        %s AS age_group,
                        %s AS region_code
                      FROM users u
                     WHERE u.deleted_at IS NULL
                       AND u.status = 'ACTIVE'
                )
                %s
                SELECT
                    s.gender, s.age_group, s.region_code,
                    COUNT(DISTINCT s.user_id)                                              AS users_cnt,
                    COALESCE(SUM(mr.numerator_flag),   0)                                  AS numerator,
                    COALESCE(SUM(mr.denominator_flag), 0)                                  AS denominator
                  FROM segments s
                  LEFT JOIN metric_rows mr ON mr.user_id = s.user_id
                 GROUP BY s.gender, s.age_group, s.region_code
                 ORDER BY users_cnt DESC
                """.formatted(genderExpr, ageExpr, regionExpr, metricBlock);

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        List<Object[]> rows = (List<Object[]>) query.getResultList();
        return rows != null ? rows : new ArrayList<>();
    }
}
