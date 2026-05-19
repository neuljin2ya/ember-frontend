package com.ember.ember.exchange.dto;

import lombok.Builder;

/**
 * 교환일기 작성 응답
 */
@Builder
public record ExchangeDiaryWriteResponse(
        Long diaryId,
        int nextTurn,
        boolean isCompleted,
        boolean chatUnlocked
) {}
