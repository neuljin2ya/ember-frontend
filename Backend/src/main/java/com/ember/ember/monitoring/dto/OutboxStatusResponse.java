package com.ember.ember.monitoring.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/** OutboxRelay 상태 — 프런트 {@code OutboxStatusResponse} 일치. */
@Schema(description = "Outbox 상태")
public record OutboxStatusResponse(

        @Schema(description = "PENDING 건수") long pending,
        @Schema(description = "FAILED 건수") long failed,
        @Schema(description = "릴레이 지연 p95 (ms)") double lagP95Ms,
        @Schema(description = "FAILED 샘플 (최대 20건)") List<FailedItem> failedSample
) {
    public record FailedItem(
            @Schema(description = "OutboxEvent PK") Long id,
            @Schema(description = "집계 유형") String aggregateType,
            @Schema(description = "이벤트 유형") String eventType,
            @Schema(description = "마지막 에러 메시지(미수집 시 공란)") String lastError,
            @Schema(description = "ISO-8601 생성 시각") String createdAt
    ) {}
}
