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
 * 키워드 TopN Repository — 설계서 §3.3.
 *
 * 설계서 상 컬럼명은 keyword/weight 이지만 실제 엔티티는 label/score 이다. 본 Repository 쿼리는
 * 실제 컬럼을 기준으로 작성되며, 응답 DTO 는 keyword/avgScore 로 재명명되어 나간다.
 */
@Repository
@RequiredArgsConstructor
public class AnalyticsKeywordRepository {

    @PersistenceContext
    private final EntityManager em;

    /**
     * 태그 유형별 TopN 키워드. tag_type IS NULL(ALL) 이면 모든 유형에 대해 각각 TopN.
     *
     * @param tagType null 이면 전 유형, 아니면 해당 enum 문자열
     * @param kMin    k-anonymity 최소 사용자 수
     * @param limit   각 tag_type 당 반환할 상위 키워드 수
     * @return [tag_type, label, freq, diary_freq, user_freq, avg_score, p50, p90, rn]
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> topKeywords(LocalDate periodStart,
                                      LocalDate periodEnd,
                                      String tagType,
                                      int kMin,
                                      int limit) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                WITH period_diaries AS (
                    SELECT d.id, d.user_id
                      FROM diaries d
                     WHERE d.created_at >= :startTs
                       AND d.created_at <  :endTs
                       AND d.analysis_status = 'COMPLETED'
                       AND d.deleted_at IS NULL
                ),
                keyword_stats AS (
                    SELECT
                        dk.label                                       AS keyword,
                        dk.tag_type,
                        COUNT(*)                                       AS freq,
                        COUNT(DISTINCT dk.diary_id)                    AS diary_freq,
                        COUNT(DISTINCT pd.user_id)                     AS user_freq,
                        AVG(dk.score)                                  AS avg_score,
                        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY dk.score) AS p50_score,
                        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY dk.score) AS p90_score
                      FROM diary_keywords dk
                      JOIN period_diaries pd ON pd.id = dk.diary_id
                     WHERE (CAST(:tagType AS VARCHAR) IS NULL
                            OR dk.tag_type = CAST(:tagType AS VARCHAR))
                     GROUP BY dk.label, dk.tag_type
                    HAVING COUNT(DISTINCT pd.user_id) >= :kMin
                ),
                ranked AS (
                    SELECT
                        tag_type, keyword, freq, diary_freq, user_freq,
                        avg_score, p50_score, p90_score,
                        ROW_NUMBER() OVER (PARTITION BY tag_type ORDER BY freq DESC, keyword ASC) AS rn
                      FROM keyword_stats
                )
                SELECT tag_type, keyword, freq, diary_freq, user_freq,
                       avg_score, p50_score, p90_score, rn
                  FROM ranked
                 WHERE rn <= :limit
                 ORDER BY tag_type, rn
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);
        query.setParameter("tagType", tagType);
        query.setParameter("kMin", kMin);
        query.setParameter("limit", limit);

        List<Object[]> rows = (List<Object[]>) query.getResultList();
        return rows != null ? rows : new ArrayList<>();
    }
}
