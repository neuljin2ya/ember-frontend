package com.ember.ember.exchange.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 관계 확장 선택 요청
 */
public record NextStepRequest(
        @NotBlank(message = "선택을 입력해주세요.")
        String choice
) {}
