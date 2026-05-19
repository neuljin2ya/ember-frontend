package com.ember.ember.monitoring.controller;

import com.ember.ember.admin.annotation.AdminOnly;
import com.ember.ember.admin.annotation.SuperAdminOnly;
import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.monitoring.dto.*;
import com.ember.ember.monitoring.service.MonitoringActionService;
import com.ember.ember.monitoring.service.MonitoringQueryService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * 관리자 AI 모니터링 대시보드 API — Phase 3B §12 / §3.
 * <p>경로 접두사가 여러 개(/monitoring, /diaries, /exchange-reports, /consent)라
 * 클래스 레벨 {@code @RequestMapping}을 생략하고 메서드별 절대 경로를 사용한다.
 */
@RestController
@RequiredArgsConstructor
@Tag(name = "Admin Monitoring", description = "AI 모니터링 대시보드 (v2.2 §12 / §3)")
@SecurityRequirement(name = "bearerAuth")
public class AdminMonitoringController {

    private final MonitoringQueryService queryService;
    private final MonitoringActionService actionService;

    // ── 조회 6종 (ADMIN 이상) ──────────────────────────────────────────────────

    @AdminOnly
    @GetMapping("/api/admin/monitoring/ai/overview")
    @Operation(summary = "AI 파이프라인 개요")
    public ResponseEntity<ApiResponse<AiOverviewResponse>> getAiOverview() {
        return ResponseEntity.ok(ApiResponse.success(queryService.getAiOverview()));
    }

    @AdminOnly
    @GetMapping("/api/admin/monitoring/ai/consent-stats")
    @Operation(summary = "AI 동의 통계 (대시보드용)")
    public ResponseEntity<ApiResponse<ConsentStatsResponse>> getConsentStatsDashboard(
            @RequestParam(name = "range", defaultValue = "7d") String range) {
        return ResponseEntity.ok(ApiResponse.success(queryService.getConsentStats(range)));
    }

    @AdminOnly
    @GetMapping("/api/admin/monitoring/mq/status")
    @Operation(summary = "RabbitMQ 큐/DLQ 상태")
    public ResponseEntity<ApiResponse<MqStatusResponse>> getMqStatus() {
        return ResponseEntity.ok(ApiResponse.success(queryService.getMqStatus()));
    }

    @AdminOnly
    @GetMapping("/api/admin/monitoring/outbox/status")
    @Operation(summary = "OutboxRelay 상태")
    public ResponseEntity<ApiResponse<OutboxStatusResponse>> getOutboxStatus() {
        return ResponseEntity.ok(ApiResponse.success(queryService.getOutboxStatus()));
    }

    @AdminOnly
    @GetMapping("/api/admin/monitoring/redis/health")
    @Operation(summary = "Redis 캐시 건강도")
    public ResponseEntity<ApiResponse<RedisHealthResponse>> getRedisHealth() {
        return ResponseEntity.ok(ApiResponse.success(queryService.getRedisHealth()));
    }

    @AdminOnly
    @GetMapping("/api/admin/monitoring/analysis/overview")
    @Operation(summary = "일기/리포트 분석 상태 분포")
    public ResponseEntity<ApiResponse<AnalysisOverviewResponse>> getAnalysisOverview() {
        return ResponseEntity.ok(ApiResponse.success(queryService.getAnalysisOverview()));
    }

    // ── 액션 4종 (SUPER_ADMIN) ────────────────────────────────────────────────

    @SuperAdminOnly
    @PostMapping("/api/admin/monitoring/mq/dlq/reprocess")
    @Operation(summary = "DLQ 재처리 트리거")
    public ResponseEntity<ApiResponse<Map<String, Integer>>> reprocessDlq(
            @Valid @RequestBody DlqReprocessRequest request) {
        int processed = actionService.reprocessDlq(request.queueName());
        return ResponseEntity.ok(ApiResponse.success(Map.of("processedCount", processed)));
    }

    @SuperAdminOnly
    @PostMapping("/api/admin/monitoring/outbox/retry")
    @Operation(summary = "Outbox FAILED 재시도")
    public ResponseEntity<ApiResponse<Map<String, Integer>>> retryOutbox(
            @RequestBody(required = false) OutboxRetryRequest request) {
        int retried = actionService.retryOutbox(request == null ? null : request.eventIds());
        return ResponseEntity.ok(ApiResponse.success(Map.of("retriedCount", retried)));
    }

    @SuperAdminOnly
    @PostMapping("/api/admin/diaries/{diaryId}/analysis-status/force-fail")
    @Operation(summary = "일기 분석 상태 강제 FAILED")
    public ResponseEntity<ApiResponse<Void>> forceFailDiary(
            @PathVariable Long diaryId,
            @Valid @RequestBody ForceFailRequest request) {
        actionService.forceFailDiary(diaryId, request.reason());
        return ResponseEntity.ok(ApiResponse.success());
    }

    @SuperAdminOnly
    @PostMapping("/api/admin/exchange-reports/{reportId}/consent-remind")
    @Operation(summary = "리포트 동의 재획득 리마인드")
    public ResponseEntity<ApiResponse<Void>> consentRemind(@PathVariable Long reportId) {
        actionService.consentRemind(reportId);
        return ResponseEntity.ok(ApiResponse.success());
    }

    // ── 동의 통계 상세 2종 (§3) ────────────────────────────────────────────────

    @AdminOnly
    @GetMapping("/api/admin/consent/stats")
    @Operation(summary = "AI 동의 통계 상세 (§3)")
    public ResponseEntity<ApiResponse<ConsentStatsResponse>> getConsentStats(
            @RequestParam(name = "range", defaultValue = "7d") String range) {
        return ResponseEntity.ok(ApiResponse.success(queryService.getConsentStats(range)));
    }

    @AdminOnly
    @GetMapping("/api/admin/consent/users")
    @Operation(summary = "미동의 사용자 목록")
    public ResponseEntity<ApiResponse<ConsentMissingUsersResponse>> getConsentMissingUsers(
            @RequestParam int page,
            @RequestParam int size,
            @RequestParam String filter) {
        return ResponseEntity.ok(ApiResponse.success(queryService.getConsentMissingUsers(page, size, filter)));
    }
}
