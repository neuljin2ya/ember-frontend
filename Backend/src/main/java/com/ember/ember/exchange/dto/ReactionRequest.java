package com.ember.ember.exchange.dto;

import jakarta.validation.constraints.NotNull;

/**
 * 리액션 등록 요청
 */
public record ReactionRequest(
        @NotNull(message = "리액션을 선택해주세요.")
        String reaction
) {}
