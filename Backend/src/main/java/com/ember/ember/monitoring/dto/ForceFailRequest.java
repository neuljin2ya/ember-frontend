package com.ember.ember.monitoring.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** 일기 분석 상태 강제 FAILED 전이 사유 */
@Schema(description = "분석 상태 강제 FAILED 전이 사유")
public record ForceFailRequest(
        @NotBlank @Size(max = 500) @Schema(description = "강제 FAILED 사유") String reason
) {}
