package com.ember.ember.exchange.dto;

import lombok.Builder;
import java.util.List;

/**
 * 교환일기 방 목록 응답
 */
@Builder
public record ExchangeRoomListResponse(
        List<ExchangeRoomItem> rooms
) {
    @Builder
    public record ExchangeRoomItem(
            Long roomId,
            String roomUuid,
            String partnerNickname,
            String status,
            int currentTurn,
            boolean isMyTurn,
            String lastDiaryAt,
            String deadline
    ) {}
}
