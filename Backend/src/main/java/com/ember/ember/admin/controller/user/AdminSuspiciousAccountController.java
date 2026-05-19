package com.ember.ember.admin.controller.user;

import com.ember.ember.admin.annotation.AdminOnly;
import com.ember.ember.admin.dto.suspicious.AdminSuspiciousAccountDetailResponse;
import com.ember.ember.admin.dto.suspicious.AdminSuspiciousAccountListItemResponse;
import com.ember.ember.admin.dto.suspicious.AdminSuspiciousAccountReviewRequest;
import com.ember.ember.admin.dto.suspicious.AdminSuspiciousAccountStatusChangeRequest;
import com.ember.ember.admin.service.AdminSuspiciousAccountService;
import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.global.security.CustomUserDetails;
import com.ember.ember.report.domain.SuspiciousAccount;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * 관리자 의심 계정 관리 API — 관리자 API 통합명세서 v2.1 §4.
 */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/admin/suspicious-accounts")
@Tag(name = "Admin Suspicious Accounts", description = "관리자 의심 계정 관리 API (v2.1 §4)")
@SecurityRequirement(name = "bearerAuth")
@AdminOnly
public class AdminSuspiciousAccountController {

    private final AdminSuspiciousAccountService service;

    /** §4.1 검토 큐 조회 */
    @GetMapping
    @Operation(summary = "의심 계정 검토 큐 조회",
            description = "risk_score 내림차순 기본. status / suspicionType / keyword 필터 제공.")
    public ResponseEntity<ApiResponse<Page<AdminSuspiciousAccountListItemResponse>>> list(
            @RequestParam(required = false) SuspiciousAccount.ReviewStatus status,
            @RequestParam(required = false) SuspiciousAccount.SuspicionType suspicionType,
            @RequestParam(required = false) String keyword,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                service.list(status, suspicionType, keyword, pageable)));
    }

    /** §4.2 탐지 상세 */
    @GetMapping("/{accountId}/detection-detail")
    @Operation(summary = "의심 계정 탐지 상세",
            description = "탐지 근거 indicators + 동일 의심 유형의 관련 계정 10건을 함께 반환.")
    public ResponseEntity<ApiResponse<AdminSuspiciousAccountDetailResponse>> detail(
            @PathVariable Long accountId) {
        return ResponseEntity.ok(ApiResponse.success(service.getDetail(accountId)));
    }

    /** §4.3 오탐 처리 */
    @PostMapping("/{accountId}/false-positive")
    @Operation(summary = "의심 계정 오탐 처리",
            description = "검토 큐에서 제거 (status=CLEARED). 검토 메모 10자 이상 필수.")
    public ResponseEntity<ApiResponse<Void>> falsePositive(
            @PathVariable Long accountId,
            @Valid @RequestBody AdminSuspiciousAccountReviewRequest request,
            @AuthenticationPrincipal CustomUserDetails admin) {
        service.markFalsePositive(accountId, request, admin);
        return ResponseEntity.ok(ApiResponse.success());
    }

    /** §4.4 상태 변경 */
    @PatchMapping("/{accountId}/status")
    @Operation(summary = "의심 계정 상태 변경",
            description = "상태 전이 규칙: PENDING → INVESTIGATING / CONFIRMED / CLEARED, "
                    + "INVESTIGATING → CONFIRMED / CLEARED. CONFIRMED / CLEARED 는 종착. "
                    + "CONFIRMED 전환 시 자동 제재 훅 연동(Phase B).")
    public ResponseEntity<ApiResponse<Void>> changeStatus(
            @PathVariable Long accountId,
            @Valid @RequestBody AdminSuspiciousAccountStatusChangeRequest request,
            @AuthenticationPrincipal CustomUserDetails admin) {
        service.changeStatus(accountId, request, admin);
        return ResponseEntity.ok(ApiResponse.success());
    }
}
