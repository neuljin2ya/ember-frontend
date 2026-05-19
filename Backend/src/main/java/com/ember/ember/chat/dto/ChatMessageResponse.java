package com.ember.ember.chat.dto;

import lombok.Builder;

/**
 * 채팅 메시지 응답
 */
@Builder
public record ChatMessageResponse(
        Long messageId,
        Long senderId,
        String content,
        String type,
        String createdAt,
        boolean isRead,
        boolean isFlagged,
        Long sequenceId
) {}
