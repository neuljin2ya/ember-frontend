package com.ember.ember.monitoring.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/** 일기/리포트 분석 상태 분포 — 프런트 {@code AnalysisOverviewResponse} 일치. */
@Schema(description = "분석 상태 개요")
public record AnalysisOverviewResponse(

        DiaryAnalysisCounts diary,
        ReportAnalysisCounts report,
        @Schema(description = "장시간 처리 중인 항목 (기본 15분 초과)") List<LongProcessingItem> longProcessing
) {

    public record DiaryAnalysisCounts(
            long processing, long done, long failed, long skipped
    ) {}

    public record ReportAnalysisCounts(
            long processing, long done, long failed,
            @Schema(description = "동의 재획득 필요 건수") long consentRequired
    ) {}

    public record LongProcessingItem(
            Long id,
            @Schema(description = "DIARY | REPORT") String type,
            @Schema(description = "ISO-8601 시작 시각") String startedAt,
            @Schema(description = "경과 시간(분)") long elapsedMinutes
    ) {}
}
