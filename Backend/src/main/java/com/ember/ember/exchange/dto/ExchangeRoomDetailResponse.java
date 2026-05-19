package com.ember.ember.exchange.dto;

import lombok.Builder;
import java.util.List;

/**
 * 교환일기 방 상세 응답
 */
@Builder
public record ExchangeRoomDetailResponse(
        Long roomId,
        PartnerInfo partner,
        String status,
        int currentTurn,
        boolean isMyTurn,
        List<DiaryItem> diaries,
        String deadline,
        int roundNumber,
        boolean nextStepRequired,
        String nextStepDeadline
) {
    @Builder
    public record PartnerInfo(
            Long userId,
            String nickname
    ) {}

    @Builder
    public record DiaryItem(
            Long diaryId,
            Long authorId,
            String content,
            String reaction,
            String readAt,
            String createdAt,
            int turnNumber
    ) {}
}
