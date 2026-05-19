package com.ember.ember.exchange.dto;

import lombok.Builder;

/**
 * 관계 확장 선택 상태 응답
 */
@Builder
public record NextStepStatusResponse(
        String myChoice,
        boolean partnerChose,
        int roundNumber,
        String status,
        String chatRoomUuid
) {}
