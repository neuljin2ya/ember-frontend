package com.ember.ember.monitoring.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/** Outbox 재시도 요청 — eventIds 미지정 시 FAILED 전체 대상 */
@Schema(description = "Outbox 재시도 요청")
public record OutboxRetryRequest(
        @Schema(description = "재시도할 OutboxEvent PK 목록 (null/empty 시 FAILED 전체)") List<Long> eventIds
) {}
