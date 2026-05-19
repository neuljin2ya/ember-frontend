package com.ember.ember.exchange.dto;

import lombok.Builder;

/**
 * 교환일기 개별 열람 응답
 */
@Builder
public record ExchangeDiaryDetailResponse(
        Long diaryId,
        String content,
        Long authorId,
        String reaction,
        String readAt
) {}
