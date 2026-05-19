package com.ember.ember.admin.dto.member;

import com.ember.ember.diary.domain.Diary;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 회원별 일기 목록 항목 — 관리자 API 통합명세서 v2.1 §3.6.
 * 관리자 화면 최적화를 위해 본문 200자 이내 프리뷰로 축약.
 */
@Schema(description = "관리자 회원별 일기 목록 항목")
public record AdminMemberDiaryListItemResponse(
        @Schema(description = "일기 ID") Long id,
        @Schema(description = "제목") String title,
        @Schema(description = "본문 프리뷰 (최대 200자)") String contentPreview,
        @Schema(description = "전체 본문 글자 수") int contentLength,
        @Schema(description = "일기 날짜") LocalDate date,
        @Schema(description = "공개 범위") Diary.DiaryVisibility visibility,
        @Schema(description = "사용자 워크플로우 상태") Diary.DiaryStatus status,
        @Schema(description = "AI 분석 상태") Diary.AnalysisStatus analysisStatus,
        @Schema(description = "요약") String summary,
        @Schema(description = "카테고리") String category,
        @Schema(description = "교환 여부") Boolean isExchanged,
        @Schema(description = "작성일") LocalDateTime createdAt
) {
    private static final int PREVIEW_MAX = 200;

    public static AdminMemberDiaryListItemResponse from(Diary diary) {
        String body = diary.getContent() == null ? "" : diary.getContent();
        String preview = body.length() <= PREVIEW_MAX ? body : body.substring(0, PREVIEW_MAX) + "…";
        return new AdminMemberDiaryListItemResponse(
                diary.getId(),
                diary.getTitle(),
                preview,
                body.length(),
                diary.getDate(),
                diary.getVisibility(),
                diary.getStatus(),
                diary.getAnalysisStatus(),
                diary.getSummary(),
                diary.getCategory(),
                diary.getIsExchanged(),
                diary.getCreatedAt()
        );
    }
}
