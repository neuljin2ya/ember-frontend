package com.ember.ember.monitoring.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/** AI 동의 통계 — 프런트 {@code ConsentStatsResponse} 일치. */
@Schema(description = "AI 동의 통계")
public record ConsentStatsResponse(

        @Schema(description = "전체 사용자 수") long totalUsers,
        @Schema(description = "AI 분석 동의율(0.0~1.0)") double analysisConsentRate,
        @Schema(description = "매칭 동의율(0.0~1.0)") double matchingConsentRate,
        @Schema(description = "철회 이력 누적 건수") long revokedCount,
        @Schema(description = "일자별 트렌드") List<DailyTrend> dailyTrend
) {
    public record DailyTrend(
            @Schema(description = "YYYY-MM-DD") String date,
            @Schema(description = "해당일 GRANTED 수") long consent,
            @Schema(description = "해당일 REVOKED 수") long revoke
    ) {}
}
