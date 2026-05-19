package com.ember.ember.admin.dto.analytics;

import java.time.LocalDate;
import java.util.List;

/**
 * 사용자 퍼널·코호트 분석 응답 — 관리자 API v2.1 §18.5 / 설계서 §3.2.
 *
 * 가입 → 프로필 완료 → 첫 매칭(ACCEPT) → 첫 교환일기 → 첫 커플의 5단 여정을
 * 주 단위 코호트(가입 주 또는 첫 매칭 주)로 집계한다.
 *
 * 분모는 코호트 모수이고, 분자는 코호트 내 해당 단계 도달 고유 사용자 수.
 * 단계 도달 시점은 분석 시점까지 누적(탈퇴 여부 무관)으로 본다 — 설계서 §3.2.5 F1.
 *
 * 시점 편향은 maturityDays 로 경고한다:
 *   - < 28일      : WARMING_UP
 *   - 28~84일 미만 : PARTIAL
 *   - >= 84일     : MATURE
 */
public record UserFunnelResponse(
        Period period,
        String cohort,                 // "signup_date" | "first_match_date"
        List<CohortRow> cohorts,
        Summary summary,
        Meta meta
) {

    public record Period(LocalDate start, LocalDate end, String tz) {}

    public record CohortRow(
            LocalDate cohortWeek,
            LocalDate cohortWeekEnd,
            long maturityDays,
            String maturityLabel,      // WARMING_UP | PARTIAL | MATURE
            Stages stages,
            Dropoff dropoff
    ) {}

    public record Stages(
            StageCount signup,
            StageCount profile,
            StageCount match,
            StageCount exchange,
            StageCount couple
    ) {}

    public record StageCount(long count, Double rate) {}

    public record Dropoff(
            Double signupToProfile,
            Double profileToMatch,
            Double matchToExchange,
            Double exchangeToCouple
    ) {}

    public record Summary(
            long totalSignups,
            Double overallConversion,
            String worstDropoffStage
    ) {}

    public record Meta(Integer kMin, Boolean degraded, String source) {}
}
