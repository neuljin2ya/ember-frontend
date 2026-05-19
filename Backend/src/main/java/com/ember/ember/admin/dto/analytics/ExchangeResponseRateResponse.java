package com.ember.ember.admin.dto.analytics;

import java.time.LocalDate;
import java.util.List;

/**
 * 교환일기 응답률 — 설계서 §3.12 (B-2.5).
 *
 * 방 시작(턴1 작성) 후 windowHours 이내 상대방 첫 응답률 + 전체 턴별 지연시간 분포.
 * - firstResponseRate: 턴1 작성 후 windowHours 내에 턴2 응답이 들어온 비율
 * - meanResponseHours / p50/p90: 같은 방 내 턴 n → 턴 n+1 사이의 작성 지연 시간
 */
public record ExchangeResponseRateResponse(
        Period period,
        int windowHours,
        long roomsStarted,       // 턴1이 발생한 방 수
        long roomsResponded,     // 윈도우 내 턴2까지 발생한 방 수
        Double firstResponseRate,
        ResponseDelay responseDelay,
        List<TurnResponseRow> byTurn,
        Meta meta
) {
    public record Period(LocalDate startDate, LocalDate endDate, String timezone) {}

    public record ResponseDelay(
            Double meanHours,
            Double p50Hours,
            Double p90Hours,
            Double p99Hours
    ) {}

    /**
     * @param fromTurn 턴 n
     * @param toTurn   턴 n+1
     * @param samples  전환 샘플 수 (턴 n+1 이 발생한 방 수)
     * @param rate     fromTurn 대비 toTurn 도달율 (0~1)
     * @param p50Hours 전환 소요 시간 중앙값
     */
    public record TurnResponseRow(
            int fromTurn,
            int toTurn,
            long samples,
            Double rate,
            Double p50Hours
    ) {}

    public record Meta(int kAnonymityMin, String dataSourceVersion) {}
}
