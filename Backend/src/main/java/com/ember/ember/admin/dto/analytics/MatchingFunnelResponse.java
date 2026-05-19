package com.ember.ember.admin.dto.analytics;

import java.time.LocalDate;
import java.util.List;

/**
 * 매칭 퍼널 분석 응답 — 관리자 API v2.1 §18.1 / 설계서 §3.1.
 *
 * 5단 퍼널(recs → accepts → exchanges → couples) 일별 집계. 각 row는 KST 기준 하루를 의미한다.
 * stage 전환율은 프론트에서 계산한다(분자/분모 분리 원칙 — 설계서 §0).
 */
public record MatchingFunnelResponse(
        Period period,
        String gender,
        List<DailyFunnelPoint> daily,
        StageTotals totals,
        String worstDropoffStage,
        Meta meta
) {

    public record Period(LocalDate start, LocalDate end, String tz) {}

    public record DailyFunnelPoint(
            LocalDate date,
            long recs,          // 매칭 요청(= matchings 생성)
            long accepts,       // 매칭 성사(= status=MATCHED 전환)
            long exchanges,     // 교환일기 시작(= exchange_rooms 생성)
            long couples        // 커플 성사(= couples 생성)
    ) {}

    public record StageTotals(
            long recs,
            long accepts,
            long exchanges,
            long couples,
            Double acceptRate,      // accepts / recs
            Double exchangeRate,    // exchanges / accepts
            Double coupleRate       // couples / exchanges
    ) {}

    public record Meta(
            Integer kMin,           // k-anonymity 임계 (기본 5)
            Boolean degraded,
            String source           // "live" | "rollup"
    ) {}
}
