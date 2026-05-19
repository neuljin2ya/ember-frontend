package com.ember.ember.monitoring.dto;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * AI 파이프라인 개요 — 관리자 AI 모니터링 대시보드 상단 요약.
 * 프런트 {@code AiMonitoringOverview} 타입과 필드명 일치.
 */
@Schema(description = "AI 파이프라인 개요")
public record AiOverviewResponse(

        @Schema(description = "AI 분석 동의율(0.0~1.0)") double consentRate,
        @Schema(description = "DLQ 누적 메시지 수") long dlqSize,
        @Schema(description = "Outbox PENDING 건수") long outboxPending,
        @Schema(description = "Outbox FAILED 건수") long outboxFailed,
        @Schema(description = "Redis 캐시 Hit Ratio(0.0~1.0)") double redisHitRatio,
        @Schema(description = "분석 PROCESSING 상태 건수") long analysisProcessing,
        @Schema(description = "분석 FAILED 상태 건수") long analysisFailed
) {}
