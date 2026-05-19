package com.ember.ember.admin.repository.analytics;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * AI 성능 Repository — 설계서 §3.6 (DB Fallback 모드).
 *
 * ai_inference_logs 테이블 미존재로 다음 테이블을 사용:
 *   - user_activity_events: AI_ANALYSIS_COMPLETED / AI_ANALYSIS_FAILED 이벤트 집계
 *   - lifestyle_analysis_log: 라이프스타일 분석 성공 건수 집계 (일 단위)
 */
@Repository
@RequiredArgsConstructor
public class AnalyticsAiPerformanceRepository {

    @PersistenceContext
    private final EntityManager em;

    /**
     * 일기 분석 성공/실패 집계.
     *
     * @return [completed, failed]
     */
    public Object[] aggregateDiaryAnalysis(LocalDateTime startTs, LocalDateTime endTs) {
        String sql = """
                SELECT
                    COUNT(*) FILTER (WHERE uae.event_type = 'AI_ANALYSIS_COMPLETED') AS completed,
                    COUNT(*) FILTER (WHERE uae.event_type = 'AI_ANALYSIS_FAILED')    AS failed
                  FROM user_activity_events uae
                 WHERE uae.event_type IN ('AI_ANALYSIS_COMPLETED', 'AI_ANALYSIS_FAILED')
                   AND uae.occurred_at >= :startTs
                   AND uae.occurred_at <  :endTs
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        Object result = query.getSingleResult();
        if (result instanceof Object[] arr) {
            return arr;
        }
        return new Object[]{0L, 0L};
    }

    /**
     * 라이프스타일 분석 집계 — 전체 건수 및 평균 diary_count.
     *
     * @return [total_runs, avg_diary_count]
     */
    public Object[] aggregateLifestyleAnalysisSummary(LocalDateTime startTs, LocalDateTime endTs) {
        String sql = """
                SELECT
                    COUNT(*)                 AS total_runs,
                    COALESCE(AVG(diary_count), 0) AS avg_diary_count
                  FROM lifestyle_analysis_log
                 WHERE analyzed_at >= :startTs
                   AND analyzed_at <  :endTs
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        Object result = query.getSingleResult();
        if (result instanceof Object[] arr) {
            return arr;
        }
        return new Object[]{0L, 0.0};
    }

    /**
     * 라이프스타일 분석 일별 처리량 (KST 기준).
     *
     * @return [date, runs]
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> aggregateLifestyleDaily(LocalDateTime startTs, LocalDateTime endTs) {
        String sql = """
                SELECT
                    (analyzed_at AT TIME ZONE 'Asia/Seoul')::date AS d,
                    COUNT(*) AS runs
                  FROM lifestyle_analysis_log
                 WHERE analyzed_at >= :startTs
                   AND analyzed_at <  :endTs
                 GROUP BY 1
                 ORDER BY 1
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        List<Object[]> rows = (List<Object[]>) query.getResultList();
        return rows != null ? rows : new ArrayList<>();
    }
}
