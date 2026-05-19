package com.ember.ember.exchange.dto;

import lombok.Builder;

/**
 * 관계 확장 선택 응답
 */
@Builder
public record NextStepResponse(
        String status,
        int roundNumber,
        String chatRoomUuid,
        String newExpiresAt
) {}
