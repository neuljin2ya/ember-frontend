package com.ember.ember.admin.dto.suspicious;

import com.ember.ember.report.domain.SuspiciousAccount;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 의심 계정 검토 큐 항목 — 관리자 API 통합명세서 v2.1 §4.1.
 * 이메일은 항상 마스킹 (목록 화면 공통 정책).
 */
@Schema(description = "의심 계정 검토 큐 항목")
public record AdminSuspiciousAccountListItemResponse(
        @Schema(description = "탐지 ID") Long id,
        @Schema(description = "사용자 ID") Long userId,
        @Schema(description = "닉네임") String nickname,
        @Schema(description = "마스킹 이메일") String email,
        @Schema(description = "의심 유형") SuspiciousAccount.SuspicionType suspicionType,
        @Schema(description = "위험도 점수 (0.00 ~ 100.00)") BigDecimal riskScore,
        @Schema(description = "의심 지표 목록") List<String> indicators,
        @Schema(description = "검토 상태") SuspiciousAccount.ReviewStatus status,
        @Schema(description = "탐지 일시") LocalDateTime detectedAt
) {
    public static AdminSuspiciousAccountListItemResponse from(SuspiciousAccount sa,
                                                               String maskedEmail,
                                                               List<String> indicators) {
        return new AdminSuspiciousAccountListItemResponse(
                sa.getId(),
                sa.getUser().getId(),
                sa.getUser().getNickname(),
                maskedEmail,
                sa.getSuspicionType(),
                sa.getRiskScore(),
                indicators,
                sa.getStatus(),
                sa.getDetectedAt()
        );
    }
}
