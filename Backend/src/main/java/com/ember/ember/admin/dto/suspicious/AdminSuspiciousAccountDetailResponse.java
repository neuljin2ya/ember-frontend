package com.ember.ember.admin.dto.suspicious;

import com.ember.ember.report.domain.SuspiciousAccount;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 의심 계정 탐지 상세 — 관리자 API 통합명세서 v2.1 §4.2.
 * 탐지 근거(indicators) + 관련 계정 목록(relatedAccounts) 반환.
 */
@Schema(description = "의심 계정 탐지 상세")
public record AdminSuspiciousAccountDetailResponse(
        @Schema(description = "탐지 ID") Long id,
        @Schema(description = "사용자 ID") Long userId,
        @Schema(description = "닉네임") String nickname,
        @Schema(description = "마스킹 이메일") String email,
        @Schema(description = "의심 유형") SuspiciousAccount.SuspicionType suspicionType,
        @Schema(description = "위험도 점수") BigDecimal riskScore,
        @Schema(description = "검토 상태") SuspiciousAccount.ReviewStatus status,
        @Schema(description = "탐지 일시") LocalDateTime detectedAt,
        @Schema(description = "검토 관리자 이름") String reviewedByName,
        @Schema(description = "검토 일시") LocalDateTime reviewedAt,
        @Schema(description = "검토 메모") String reviewNote,
        @Schema(description = "탐지 지표 목록") List<String> indicators,
        @Schema(description = "관련 의심 계정 목록") List<RelatedAccount> relatedAccounts
) {
    public record RelatedAccount(
            @Schema(description = "탐지 ID") Long id,
            @Schema(description = "사용자 ID") Long userId,
            @Schema(description = "닉네임") String nickname,
            @Schema(description = "의심 유형") SuspiciousAccount.SuspicionType suspicionType,
            @Schema(description = "위험도") BigDecimal riskScore,
            @Schema(description = "탐지 일시") LocalDateTime detectedAt
    ) {}
}
