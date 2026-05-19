package com.ember.ember.admin.dto.suspicious;

import com.ember.ember.report.domain.SuspiciousAccount;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * 의심 계정 상태 변경 요청 — §4.4.
 * status ∈ { INVESTIGATING, CONFIRMED, CLEARED }, reviewNote ≥ 10자.
 */
@Schema(description = "의심 계정 상태 변경 요청")
public record AdminSuspiciousAccountStatusChangeRequest(
        @NotNull(message = "변경할 상태는 필수입니다.")
        @Schema(description = "변경할 검토 상태", example = "CONFIRMED")
        SuspiciousAccount.ReviewStatus status,

        @NotBlank(message = "검토 메모는 필수입니다.")
        @Size(min = 10, max = 500, message = "검토 메모는 10~500자여야 합니다.")
        @Schema(description = "검토 메모 (10자 이상)")
        String reviewNote
) {}
