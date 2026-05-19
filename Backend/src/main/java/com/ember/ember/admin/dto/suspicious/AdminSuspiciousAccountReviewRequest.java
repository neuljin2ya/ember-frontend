package com.ember.ember.admin.dto.suspicious;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 의심 계정 오탐 처리 요청 — §4.3.
 * 명세상 필드명은 `reason` 또는 `reviewNote` 를 모두 허용하며, 서버는 reviewNote 로 저장한다.
 * 최소 10자.
 */
@Schema(description = "의심 계정 오탐 처리 요청")
public record AdminSuspiciousAccountReviewRequest(
        @NotBlank(message = "검토 메모는 필수입니다.")
        @Size(min = 10, max = 500, message = "검토 메모는 10~500자여야 합니다.")
        @Schema(description = "검토 메모 / 사유 (10자 이상)", example = "실제 사용자로 확인됨 — CS 연락 결과 본인 인증 완료")
        String reviewNote
) {}
