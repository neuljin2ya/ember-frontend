package com.ember.ember.chat.dto;

import lombok.Builder;
import java.util.List;

/**
 * 채팅방 목록 응답
 */
@Builder
public record ChatRoomListResponse(
        List<ChatRoomItem> chatRooms
) {
    @Builder
    public record ChatRoomItem(
            Long chatRoomId,
            String roomUuid,
            String partnerNickname,
            String lastMessage,
            String lastMessageAt,
            long unreadCount,
            String status
    ) {}
}
