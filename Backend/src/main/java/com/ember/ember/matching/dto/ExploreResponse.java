package com.ember.ember.matching.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.*;

import java.util.List;

@Getter
@AllArgsConstructor
public class ExploreResponse {

    private List<ExploreDiaryItem> diaries;
    private Long nextCursor;
    private boolean hasNext;
    private String guidanceMessage;
    private String currentSort;

    @Getter
    @Builder
    @AllArgsConstructor
    @JsonInclude(JsonInclude.Include.NON_NULL)
    public static class ExploreDiaryItem {
        private Long diaryId;
        private Long authorId;
        private String ageGroupLabel;
        private String sido;
        private String sigungu;
        private String previewContent;
        private String category;
        private String createdAt;
        private String similarityBadge;
        private List<String> personalityKeywords;
        private List<String> moodTags;

        // ── recommended 전용 필드 (latest에서는 null → JSON 미노출) ──
        /** AI 매칭 점수 (0.0~1.0) */
        private Double matchingScore;
        /** 키워드 Jaccard 유사도 */
        private Double keywordOverlap;
        /** KoSimCSE 코사인 유사도 */
        private Double cosineSimilarity;
    }
}
