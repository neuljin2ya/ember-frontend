package com.ember.ember.admin.controller.automation;

import com.ember.ember.admin.annotation.AdminAction;
import com.ember.ember.admin.annotation.AdminOnly;
import com.ember.ember.admin.annotation.AdminOperator;
import com.ember.ember.admin.dto.automation.AutoReportScheduleCreateRequest;
import com.ember.ember.admin.dto.automation.AutoReportScheduleResponse;
import com.ember.ember.admin.service.automation.AdminAutoReportService;
import com.ember.ember.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 관리자 자동 리포트 스케줄 API — 목록 조회, 생성, 토글, 수동 실행.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/admin/auto-report-schedules")
@Tag(name = "관리자 자동 리포트 스케줄")
@SecurityRequirement(name = "bearerAuth")
public class AdminAutoReportController {

    private final AdminAutoReportService adminAutoReportService;

    @GetMapping
    @AdminOnly
    @Operation(summary = "자동 리포트 스케줄 목록 조회", description = "등록된 전체 자동 리포트 스케줄 목록")
    public ResponseEntity<ApiResponse<List<AutoReportScheduleResponse>>> getSchedules() {
        return ResponseEntity.ok(ApiResponse.success(adminAutoReportService.getSchedules()));
    }

    @PostMapping
    @AdminOperator
    @Operation(summary = "자동 리포트 스케줄 생성", description = "새 자동 리포트 스케줄 등록")
    @AdminAction(action = "AUTO_REPORT_SCHEDULE_CREATE", targetType = "AUTO_REPORT_SCHEDULE")
    public ResponseEntity<ApiResponse<AutoReportScheduleResponse>> createSchedule(
            @RequestBody @Valid AutoReportScheduleCreateRequest request) {
        return ResponseEntity.ok(ApiResponse.created(adminAutoReportService.createSchedule(request)));
    }

    @PatchMapping("/{scheduleId}/toggle")
    @AdminOperator
    @Operation(summary = "자동 리포트 스케줄 활성/비활성 토글", description = "스케줄 enabled 상태 반전")
    @AdminAction(action = "AUTO_REPORT_SCHEDULE_TOGGLE", targetType = "AUTO_REPORT_SCHEDULE", targetIdParam = "scheduleId")
    public ResponseEntity<ApiResponse<AutoReportScheduleResponse>> toggleSchedule(
            @PathVariable Long scheduleId) {
        return ResponseEntity.ok(ApiResponse.success(adminAutoReportService.toggleSchedule(scheduleId)));
    }

    @PostMapping("/{scheduleId}/run")
    @AdminOperator
    @Operation(summary = "자동 리포트 수동 실행", description = "스케줄 즉시 실행 (실행 카운트 증가)")
    @AdminAction(action = "AUTO_REPORT_SCHEDULE_RUN", targetType = "AUTO_REPORT_SCHEDULE", targetIdParam = "scheduleId")
    public ResponseEntity<ApiResponse<AutoReportScheduleResponse>> runNow(
            @PathVariable Long scheduleId) {
        return ResponseEntity.ok(ApiResponse.success(adminAutoReportService.executeNow(scheduleId)));
    }
}
