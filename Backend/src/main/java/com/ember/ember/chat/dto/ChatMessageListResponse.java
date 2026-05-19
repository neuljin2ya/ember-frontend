package com.ember.ember.chat.dto;

import lombok.Builder;
import java.util.List;

/**
 * 채팅 메시지 이력 응답
 */
@Builder
public record ChatMessageListResponse(
        List<ChatMessageResponse> messages,
        boolean hasMore
) {}
