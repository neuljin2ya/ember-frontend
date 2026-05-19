package com.ember.ember.couple.dto;

import lombok.Builder;
import java.util.List;

/**
 * 커플 요청 응답
 */
@Builder
public record CoupleRequestResponse(
        Long requestId,
        String expiresAt,
        List<String> reminderSchedule
) {}
