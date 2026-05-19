package com.ember.ember.admin.dto.analytics;

import java.time.LocalDate;
import java.util.List;

/**
 * 주제(카테고리) 참여도 분포 — 설계서 §3.11 (B-2.4).
 *
 * diaries.category 기준 일기 수 + 참여 사용자 수. 비율은 기간 내 전체 일기 대비.
 * WeeklyTopic 링크는 diaries.topic_id 로 추적 가능하나, v1 에선 category 텍스트 그룹핑만.
 */
public record DiaryTopicParticipationResponse(
        Period period,
        long totalDiaries,
        long totalUsers,
        List<TopicRow> topics,
        Meta meta
) {
    public record Period(LocalDate startDate, LocalDate endDate, String timezone) {}

    /**
     * @param category    카테고리 라벨 (diaries.category, 미분류는 'UNKNOWN')
     * @param diaryCount  해당 카테고리 일기 수
     * @param userCount   해당 카테고리에 일기를 쓴 distinct 사용자 수
     * @param diaryShare  전체 일기 대비 비율 (0.0~1.0)
     * @param userShare   전체 사용자 대비 비율 (0.0~1.0)
     */
    public record TopicRow(
            String category,
            long diaryCount,
            long userCount,
            Double diaryShare,
            Double userShare
    ) {}

    public record Meta(int kAnonymityMin, String dataSourceVersion) {}
}
