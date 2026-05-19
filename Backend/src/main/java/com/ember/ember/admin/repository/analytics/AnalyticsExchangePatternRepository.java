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
 * 교환일기 패턴 Repository — 설계서 §3.12~§3.13 (B-2.5~B-2.6).
 *
 * 범위:
 *   - §3.12 응답률 (aggregateResponseRate, aggregateTurnDelays)
 *   - §3.13 턴→채팅 퍼널 (aggregateTurnFunnel)
 *
 * 스키마 매핑:
 *   - exchange_diaries.turn_number 로 턴 순서 식별 (1~4 가 1라운드, 5~6 이 2라운드 연장).
 *   - exchange_diaries.submitted_at 이 실제 제출 시각. DRAFT 는 submitted_at=NULL.
 *   - exchange_rooms.status IN ('CHAT_CONNECTED','ENDED') 가 채팅 전환 완료.
 */
@Repository
@RequiredArgsConstructor
public class AnalyticsExchangePatternRepository {

    @PersistenceContext
    private final EntityManager em;

    // =========================================================================
    // §3.12 응답률
    // =========================================================================

    /**
     * 방 시작(턴1) → 윈도우 시간 내 턴2 응답 비율.
     *
     * @return [rooms_started, rooms_responded_in_window]
     */
    public Object[] aggregateFirstResponseRate(LocalDate periodStart,
                                               LocalDate periodEnd,
                                               int windowHours) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                WITH turn1 AS (
                    SELECT DISTINCT ON (ed.room_id) ed.room_id, ed.submitted_at
                      FROM exchange_diaries ed
                     WHERE ed.turn_number = 1
                       AND ed.submitted_at IS NOT NULL
                       AND ed.submitted_at >= :startTs
                       AND ed.submitted_at <  :endTs
                     ORDER BY ed.room_id, ed.submitted_at ASC
                ),
                turn2 AS (
                    SELECT DISTINCT ON (ed.room_id) ed.room_id, ed.submitted_at
                      FROM exchange_diaries ed
                     WHERE ed.turn_number = 2
                       AND ed.submitted_at IS NOT NULL
                     ORDER BY ed.room_id, ed.submitted_at ASC
                )
                SELECT
                    COUNT(t1.room_id) AS rooms_started,
                    SUM(CASE WHEN t2.submitted_at IS NOT NULL
                              AND t2.submitted_at <= t1.submitted_at + (:windowHours || ' hours')::interval
                             THEN 1 ELSE 0 END) AS rooms_responded
                  FROM turn1 t1
                  LEFT JOIN turn2 t2 ON t2.room_id = t1.room_id
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);
        query.setParameter("windowHours", String.valueOf(windowHours));

        Object result = query.getSingleResult();
        if (result instanceof Object[] arr) return arr;
        return new Object[]{0L, 0L};
    }

    /**
     * 턴 전체 지연시간 분포 p50/p90/p99/mean (시간 단위).
     * 같은 방 내 turn_number N → N+1 사이의 submitted_at 차이.
     *
     * @return [mean_hours, p50_hours, p90_hours, p99_hours]
     */
    public Object[] aggregateResponseDelay(LocalDate periodStart, LocalDate periodEnd) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                WITH turns AS (
                    SELECT ed.room_id, ed.turn_number, ed.submitted_at
                      FROM exchange_diaries ed
                     WHERE ed.submitted_at IS NOT NULL
                       AND ed.submitted_at >= :startTs
                       AND ed.submitted_at <  :endTs
                ),
                deltas AS (
                    SELECT EXTRACT(EPOCH FROM (
                        LEAD(submitted_at) OVER (PARTITION BY room_id ORDER BY turn_number)
                        - submitted_at
                    )) / 3600.0 AS delay_hours
                      FROM turns
                )
                SELECT
                    AVG(delay_hours)                                          AS mean_h,
                    PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY delay_hours) AS p50_h,
                    PERCENTILE_CONT(0.9)  WITHIN GROUP (ORDER BY delay_hours) AS p90_h,
                    PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY delay_hours) AS p99_h
                  FROM deltas
                 WHERE delay_hours IS NOT NULL AND delay_hours >= 0
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        Object result = query.getSingleResult();
        if (result instanceof Object[] arr) return arr;
        return new Object[]{null, null, null, null};
    }

    /**
     * 턴 N → 턴 N+1 전환율 + 지연시간 p50.
     *
     * @return [from_turn, to_turn, samples, rate, p50_hours]
     */
    @SuppressWarnings("unchecked")
    public List<Object[]> aggregateTurnTransitions(LocalDate periodStart, LocalDate periodEnd) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                WITH turns AS (
                    SELECT ed.room_id, ed.turn_number, ed.submitted_at
                      FROM exchange_diaries ed
                     WHERE ed.submitted_at IS NOT NULL
                       AND ed.submitted_at >= :startTs
                       AND ed.submitted_at <  :endTs
                ),
                turn_pairs AS (
                    SELECT t1.turn_number AS from_turn,
                           t1.turn_number + 1 AS to_turn,
                           t1.room_id,
                           t2.submitted_at IS NOT NULL AS has_next,
                           CASE WHEN t2.submitted_at IS NOT NULL
                                THEN EXTRACT(EPOCH FROM (t2.submitted_at - t1.submitted_at)) / 3600.0
                                ELSE NULL
                           END AS delay_hours
                      FROM turns t1
                      LEFT JOIN turns t2
                             ON t2.room_id = t1.room_id
                            AND t2.turn_number = t1.turn_number + 1
                )
                SELECT
                    from_turn, to_turn,
                    SUM(CASE WHEN has_next THEN 1 ELSE 0 END)                           AS samples,
                    AVG(CASE WHEN has_next THEN 1.0 ELSE 0.0 END)                       AS rate,
                    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delay_hours)            AS p50_h
                  FROM turn_pairs
                 GROUP BY from_turn, to_turn
                 ORDER BY from_turn
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        List<Object[]> rows = (List<Object[]>) query.getResultList();
        return rows != null ? rows : new ArrayList<>();
    }

    // =========================================================================
    // §3.13 턴 → 채팅 전환 퍼널
    // =========================================================================

    /**
     * 방 생성 → 턴1~4 도달 → CHAT_CONNECTED 6단 집계.
     * 기준: exchange_rooms.created_at 이 기간 내 & exchange_diaries.turn_number 별 도달.
     *
     * @return [rooms_created, turn1, turn2, turn3, turn4_complete, chat_connected]
     */
    public Object[] aggregateTurnFunnel(LocalDate periodStart, LocalDate periodEnd) {
        LocalDateTime startTs = periodStart.atStartOfDay();
        LocalDateTime endTs = periodEnd.atStartOfDay();

        String sql = """
                WITH period_rooms AS (
                    SELECT er.id, er.status
                      FROM exchange_rooms er
                     WHERE er.created_at >= :startTs
                       AND er.created_at <  :endTs
                ),
                turn_reach AS (
                    SELECT room_id, MAX(turn_number) AS max_turn
                      FROM exchange_diaries
                     WHERE submitted_at IS NOT NULL
                     GROUP BY room_id
                )
                SELECT
                    COUNT(pr.id)                                                                AS rooms_created,
                    SUM(CASE WHEN tr.max_turn >= 1 THEN 1 ELSE 0 END)                           AS turn1_cnt,
                    SUM(CASE WHEN tr.max_turn >= 2 THEN 1 ELSE 0 END)                           AS turn2_cnt,
                    SUM(CASE WHEN tr.max_turn >= 3 THEN 1 ELSE 0 END)                           AS turn3_cnt,
                    SUM(CASE WHEN tr.max_turn >= 4 THEN 1 ELSE 0 END)                           AS turn4_cnt,
                    SUM(CASE WHEN pr.status IN ('CHAT_CONNECTED','ENDED') THEN 1 ELSE 0 END)    AS chat_cnt
                  FROM period_rooms pr
                  LEFT JOIN turn_reach tr ON tr.room_id = pr.id
                """;

        var query = em.createNativeQuery(sql);
        query.setParameter("startTs", startTs);
        query.setParameter("endTs", endTs);

        Object result = query.getSingleResult();
        if (result instanceof Object[] arr) return arr;
        return new Object[]{0L, 0L, 0L, 0L, 0L, 0L};
    }
}
