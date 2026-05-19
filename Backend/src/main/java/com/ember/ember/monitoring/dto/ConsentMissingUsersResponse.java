package com.ember.ember.monitoring.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/** 미동의 사용자 목록 — 관리자 동의 통계 상세(§3). */
@Schema(description = "미동의 사용자 목록")
public record ConsentMissingUsersResponse(
        List<UserItem> content,
        long total
) {
    public record UserItem(
            Long userId,
            String nickname,
            @Schema(description = "ISO-8601 마지막 로그인 시각(없으면 null)") String lastLoginAt
    ) {}
}
