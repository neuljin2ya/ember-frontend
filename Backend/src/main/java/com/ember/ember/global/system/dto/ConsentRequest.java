package com.ember.ember.global.system.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;

@Schema(description = "AI 분석 동의 등록 요청")
public record ConsentRequest(

        @Schema(description = "동의 유형 (AI_ANALYSIS / AI_DATA_USAGE)", example = "AI_ANALYSIS")
        @NotBlank(message = "consentType은 필수입니다.")
        String consentType
) {

    private static final java.util.Set<String> VALID_TYPES =
            java.util.Set.of("AI_ANALYSIS", "AI_DATA_USAGE");

    /** 유효한 consentType인지 검증 */
    public boolean isValidType() {
        return VALID_TYPES.contains(consentType);
    }
}
