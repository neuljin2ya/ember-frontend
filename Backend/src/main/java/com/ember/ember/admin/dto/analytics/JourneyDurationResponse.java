package com.ember.ember.admin.dto.analytics;

import java.time.LocalDate;
import java.util.List;

/**
 * 여정 소요 시간 분포 응답 — 관리자 API §18.5 일부 / 설계서 §3.5.
 *
 * 각 단계(signup→profile, profile→match, match→exchange, exchange→couple) 별로
 * 도달 사용자의 소요 시간(시간 단위) 분포를 P50/P90/P99 + 평균/표준편차 로 제공한다.
 *
 * v1 은 user_activity_events 이벤트 스트림이 완전히 갖춰지지 않아 Fallback 쿼리를 사용한다.
 * fallbackUsed=true 로 표시한다.
 */
public record JourneyDurationResponse(
        Period period,
        List<StageStat> stages,
        boolean degraded,
        boolean fallbackUsed,
        Meta meta
) {

    public record Period(LocalDate start, LocalDate end, String tz) {}

    public record StageStat(
            String stage,              // SIGNUP_TO_PROFILE | PROFILE_TO_MATCH | MATCH_TO_EXCHANGE | EXCHANGE_TO_COUPLE
            long n,                    // 해당 단계 도달 사용자 수
            Double p50H,
            Double p90H,
            Double p99H,
            Double meanH,
            Double stddevH
    ) {}

    public record Meta(String source) {}
}
