package com.ember.ember.couple.dto;

import lombok.Builder;

/**
 * 커플 수락 응답
 */
@Builder
public record CoupleAcceptResponse(
        Long coupleId,
        String status
) {}
