package com.ember.ember.chat.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * 채팅 메시지 전송 요청
 */
public record ChatMessageRequest(
        @NotBlank(message = "메시지를 입력해주세요.")
        String content,
        @NotNull(message = "메시지 타입을 지정해주세요.")
        String type
) {}
