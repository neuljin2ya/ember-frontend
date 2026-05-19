package com.ember.ember.admin.dto.member;

import com.ember.ember.diary.domain.UserActivityEvent;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDateTime;

/**
 * 회원 활동 타임라인 항목 — 관리자 API 통합명세서 v2.1 §3.8.
 *
 * 이상 패턴 자동 하이라이트 {@code isAnomalous}:
 * <ul>
 *   <li>1시간 내 신고 3회 이상 → 해당 구간 REPORT_CREATED 이벤트 전부 true</li>
 *   <li>24시간 내 매칭 신청 10명 이상 → 해당 구간 MATCH_REQUESTED 이벤트 전부 true</li>
 *   <li>30초 이내 일기 반복 제출 → 연속 DIARY_CREATED 이벤트 쌍 전부 true</li>
 * </ul>
 */
@Schema(description = "관리자 회원 활동 타임라인 항목")
public record AdminActivityTimelineItemResponse(
        @Schema(description = "이벤트 ID") Long id,
        @Schema(description = "이벤트 유형") String eventType,
        @Schema(description = "대상 엔티티 유형") String targetType,
        @Schema(description = "대상 엔티티 ID") Long targetId,
        @Schema(description = "추가 상세 (JSON 혹은 평문)") String detail,
        @Schema(description = "발생 일시") LocalDateTime occurredAt,
        @Schema(description = "이상 패턴 하이라이트 여부") boolean isAnomalous
) {
    public static AdminActivityTimelineItemResponse from(UserActivityEvent event, boolean anomalous) {
        return new AdminActivityTimelineItemResponse(
                event.getId(),
                event.getEventType(),
                event.getTargetType(),
                event.getTargetId(),
                event.getDetail(),
                event.getOccurredAt(),
                anomalous
        );
    }
}
