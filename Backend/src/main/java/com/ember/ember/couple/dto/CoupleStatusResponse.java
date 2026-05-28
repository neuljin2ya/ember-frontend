package com.ember.ember.couple.dto;

import io.swagger.v3.oas.annotations.media.Schema;
import lombok.Builder;

/**
 * 커플 요청 상태 조회 응답
 */
@Builder
@Schema(description = "커플 요청 상태 조회 응답")
public record CoupleStatusResponse(

        @Schema(description = "PENDING 요청 존재 여부")
        boolean hasPendingRequest,

        @Schema(description = "내가 요청자인지 (true=내가 보낸 요청, false=상대가 보낸 요청)")
        boolean isRequester,

        @Schema(description = "요청 상태 (PENDING/ACCEPTED/REJECTED/EXPIRED/CANCELLED, 없으면 null)")
        String status,

        @Schema(description = "만료 시각")
        String expiresAt,

        @Schema(description = "이미 커플 확정 여부")
        boolean isCouple,

        @Schema(description = "요청자 닉네임")
        String requesterNickname
) {}
