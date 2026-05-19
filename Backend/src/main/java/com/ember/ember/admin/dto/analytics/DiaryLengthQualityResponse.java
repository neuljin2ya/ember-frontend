package com.ember.ember.admin.dto.analytics;

import java.time.LocalDate;
import java.util.List;

/**
 * 일기 길이·품질 분포 — 설계서 §3.9 (B-2.2).
 *
 * 길이: 문자수(char count) 기준 p50/p90/p99 + 히스토그램(5구간).
 * 품질: analysis_status 별 카운트 + 성공률.
 */
public record DiaryLengthQualityResponse(
        Period period,
        LengthStats lengthStats,
        List<LengthBucket> histogram,
        QualityStats qualityStats,
        Meta meta
) {
    public record Period(LocalDate startDate, LocalDate endDate, String timezone) {}

    public record LengthStats(
            long totalDiaries,
            Double meanChars,
            Double p50Chars,
            Double p90Chars,
            Double p99Chars,
            Long minChars,
            Long maxChars
    ) {}

    /**
     * @param bucket 표기(예: "100-199", "200-399", "400-799", "800-1499", "1500+")
     * @param count  해당 구간 일기 수
     */
    public record LengthBucket(String bucket, long count) {}

    /**
     * analysis_status 분포. successRate = completed / (completed + failed).
     */
    public record QualityStats(
            long completed,
            long failed,
            long skipped,
            long pending,
            Double successRate
    ) {}

    public record Meta(int kAnonymityMin, String dataSourceVersion) {}
}
