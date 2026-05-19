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
 * 일기 패턴 분석 Repository — 설계서 §3.8~§3.11 (B-2.1~B-2.4).
 *
 * 범위:
 *   - §3.8  시간 히트맵 (aggregateTimeHeatmap)
 *   - §3.9  길이·품질 (aggregateLengthStats, aggregateQualityCounts)
 *   - §3.10 감정 태그 추이 (aggregateEmotionTrends, aggregateTopEmotions)
 *   - §3.11 주제 참여도 (aggregateTopicParticipation)
 *
 * 스키마 매핑:
 *   - diaries.created_at 는 UTC 저장 → KST 변환 후 EXTRACT(DOW/HOUR)
 *   - diaries.content 는 TEXT, 길이는 CHAR_LENGTH(content) 사용
 *   - diary_keywords.tag_type='EMOTION' 필터 후 diaries 와 조인
 */
@Repository
@RequiredArgsConstructor
public class AnalyticsDiaryPatternRepository {

    @PersistenceContext
    private final EntityManager em;

    // =========================================================================
    // §3.8 시간 히트맵
    // =========================================================================

    /**
     * 요일 × 시간 24×7 버킷 집계 (KST 기준).
     *
     * @return [dayOfWeek(0=일), hour(0~23), count]
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> aggregateTimeHeatmap(LocalDate periodStart, LocalDate periodEnd) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                SELECT
                    EXTRACT(DOW  FROM d.created_at AT TIME ZONE 'Asia/Seoul')::int AS day_of_week,
                    EXTRACT(HOUR FROM d.created_at AT TIME ZONE 'Asia/Seoul')::int AS hour_of_day,
                    COUNT(*)                                                        AS cnt
                  FROM diaries d
                 WHERE d.created_at >= :startTs
                   AND d.created_at <  :endTs
                   AND d.deleted_at IS NULL
                 GROUP BY day_of_week, hour_of_day
                 ORDER BY day_of_week, hour_of_day
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        List<Object[]> rows = (List<Object[]>) query.getResultList();
        return rows != null ? rows : new ArrayList<>();
    }

    // =========================================================================
    // §3.9 길이·품질 분포
    // =========================================================================

    /**
     * 글자 수 통계 + 5구간 히스토그램 + 분석 상태 집계 — 단일 쿼리 스캔으로 해결.
     *
     * @return [total, mean, p50, p90, p99, minChars, maxChars,
     *          bucket100_199, bucket200_399, bucket400_799, bucket800_1499, bucket1500Plus,
     *          completed, failed, skipped, pending]
     */
    public Object[] aggregateLengthAndQuality(LocalDate periodStart, LocalDate periodEnd) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                SELECT
                    COUNT(*)                                                              AS total,
                    AVG(CHAR_LENGTH(d.content))                                           AS mean_chars,
                    PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY CHAR_LENGTH(d.content))  AS p50_chars,
                    PERCENTILE_CONT(0.9)  WITHIN GROUP (ORDER BY CHAR_LENGTH(d.content))  AS p90_chars,
                    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY CHAR_LENGTH(d.content))  AS p99_chars,
                    MIN(CHAR_LENGTH(d.content))                                           AS min_chars,
                    MAX(CHAR_LENGTH(d.content))                                           AS max_chars,
                    SUM(CASE WHEN CHAR_LENGTH(d.content) BETWEEN 100  AND 199  THEN 1 ELSE 0 END) AS b100_199,
                    SUM(CASE WHEN CHAR_LENGTH(d.content) BETWEEN 200  AND 399  THEN 1 ELSE 0 END) AS b200_399,
                    SUM(CASE WHEN CHAR_LENGTH(d.content) BETWEEN 400  AND 799  THEN 1 ELSE 0 END) AS b400_799,
                    SUM(CASE WHEN CHAR_LENGTH(d.content) BETWEEN 800  AND 1499 THEN 1 ELSE 0 END) AS b800_1499,
                    SUM(CASE WHEN CHAR_LENGTH(d.content) >= 1500                 THEN 1 ELSE 0 END) AS b1500_plus,
                    SUM(CASE WHEN d.analysis_status = 'COMPLETED' THEN 1 ELSE 0 END)      AS completed_cnt,
                    SUM(CASE WHEN d.analysis_status = 'FAILED'    THEN 1 ELSE 0 END)      AS failed_cnt,
                    SUM(CASE WHEN d.analysis_status = 'SKIPPED'   THEN 1 ELSE 0 END)      AS skipped_cnt,
                    SUM(CASE WHEN d.analysis_status = 'PENDING'   THEN 1 ELSE 0 END)      AS pending_cnt
                  FROM diaries d
                 WHERE d.created_at >= :startTs
                   AND d.created_at <  :endTs
                   AND d.deleted_at IS NULL
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        Object result = query.getSingleResult();
        if (result instanceof Object[] arr) return arr;
        return new Object[16];
    }

    // =========================================================================
    // §3.10 감정 태그 추이
    // =========================================================================

    /**
     * 감정 태그 시계열 집계 (day 버킷 기본).
     *
     * @param bucketUnit "day" | "week" — DATE_TRUNC 단위
     * @param topN       버킷별 TopN 감정만 반환
     * @return [bucketDate, emotion, freq, avgScore]
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> aggregateEmotionTrends(LocalDate periodStart,
                                                 LocalDate periodEnd,
                                                 String bucketUnit,
                                                 int topN) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();
        String unit = "week".equalsIgnoreCase(bucketUnit) ? "week" : "day";

        String sql = """
                WITH labeled AS (
                    SELECT
                        DATE_TRUNC(:unit, d.created_at AT TIME ZONE 'Asia/Seoul')::date AS bucket_date,
                        k.label                                                          AS emotion,
                        k.score
                      FROM diaries d
                      JOIN diary_keywords k ON k.diary_id = d.id
                     WHERE d.created_at >= :startTs
                       AND d.created_at <  :endTs
                       AND d.deleted_at IS NULL
                       AND k.tag_type = 'EMOTION'
                ),
                agg AS (
                    SELECT bucket_date, emotion,
                           COUNT(*) AS freq,
                           AVG(score) AS avg_score
                      FROM labeled
                     GROUP BY bucket_date, emotion
                ),
                ranked AS (
                    SELECT bucket_date, emotion, freq, avg_score,
                           ROW_NUMBER() OVER (PARTITION BY bucket_date ORDER BY freq DESC, emotion ASC) AS rn
                      FROM agg
                )
                SELECT bucket_date, emotion, freq, avg_score
                  FROM ranked
                 WHERE rn <= :topN
                 ORDER BY bucket_date ASC, rn ASC
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("unit", unit);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);
        query.setParameter("topN", topN);

        List<Object[]> rows = (List<Object[]>) query.getResultList();
        return rows != null ? rows : new ArrayList<>();
    }

    /**
     * 기간 전체 상위 N개 감정 라벨 (클라이언트 축 색상 매핑용).
     *
     * @return [emotion]
     */
    @SuppressWarnings("unchecked")
    public List<Object> aggregateTopEmotions(LocalDate periodStart, LocalDate periodEnd, int topN) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                SELECT k.label AS emotion
                  FROM diary_keywords k
                  JOIN diaries d ON d.id = k.diary_id
                 WHERE d.created_at >= :startTs
                   AND d.created_at <  :endTs
                   AND d.deleted_at IS NULL
                   AND k.tag_type = 'EMOTION'
                 GROUP BY k.label
                 ORDER BY COUNT(*) DESC, k.label ASC
                 LIMIT :topN
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);
        query.setParameter("topN", topN);

        List<Object> rows = (List<Object>) query.getResultList();
        return rows != null ? rows : new ArrayList<>();
    }

    // =========================================================================
    // §3.11 주제 참여도
    // =========================================================================

    /**
     * 카테고리별 일기 수 + 참여 사용자 수.
     *
     * @return [category, diary_cnt, user_cnt]
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> aggregateTopicParticipation(LocalDate periodStart, LocalDate periodEnd) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                SELECT
                    COALESCE(d.category, 'UNKNOWN') AS category,
                    COUNT(*)                        AS diary_cnt,
                    COUNT(DISTINCT d.user_id)       AS user_cnt
                  FROM diaries d
                 WHERE d.created_at >= :startTs
                   AND d.created_at <  :endTs
                   AND d.deleted_at IS NULL
                 GROUP BY COALESCE(d.category, 'UNKNOWN')
                 ORDER BY diary_cnt DESC
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        List<Object[]> rows = (List<Object[]>) query.getResultList();
        return rows != null ? rows : new ArrayList<>();
    }

    /**
     * 기간 내 일기 총계 + distinct 사용자 수 (카테고리 분모 계산용).
     *
     * @return [total_diaries, total_users]
     */
    public Object[] aggregateTopicTotals(LocalDate periodStart, LocalDate periodEnd) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                SELECT
                    COUNT(*)                  AS total_diaries,
                    COUNT(DISTINCT d.user_id) AS total_users
                  FROM diaries d
                 WHERE d.created_at >= :startTs
                   AND d.created_at <  :endTs
                   AND d.deleted_at IS NULL
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        Object result = query.getSingleResult();
        if (result instanceof Object[] arr) return arr;
        return new Object[]{0L, 0L};
    }
}
