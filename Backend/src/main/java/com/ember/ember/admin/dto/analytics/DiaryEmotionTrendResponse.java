package com.ember.ember.admin.dto.analytics;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * 감정 태그 추이 시계열 — 설계서 §3.10 (B-2.3).
 *
 * 일자 × 감정 라벨 TopN. 각 포인트는 특정 일자에 등장한 감정 라벨의 빈도/평균 점수.
 * tag_type='EMOTION' 필터 적용.
 */
public record DiaryEmotionTrendResponse(
        Period period,
        String bucket, // "day" | "week"
        List<TrendPoint> trends,
        List<String> topEmotions,   // 전체 기간 상위 5개 감정 라벨 (클라이언트 축 색상 매핑용)
        Meta meta
) {
    public record Period(LocalDate startDate, LocalDate endDate, String timezone) {}

    /**
     * @param bucketDate KST 일자(혹은 주 시작일)
     * @param emotion    감정 라벨
     * @param freq       해당 버킷 출현 빈도
     * @param avgScore   평균 점수 (0.000~1.000)
     */
    public record TrendPoint(LocalDate bucketDate, String emotion, long freq, BigDecimal avgScore) {}

    public record Meta(int kAnonymityMin, String dataSourceVersion) {}
}
