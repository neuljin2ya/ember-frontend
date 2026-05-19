package com.ember.ember.monitoring.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

/** DLQ 재처리 요청 */
@Schema(description = "DLQ 재처리 요청")
public record DlqReprocessRequest(
        @NotBlank @Schema(description = "재처리 대상 DLQ 큐 이름", example = "diary-analyze.dlq") String queueName
) {}
