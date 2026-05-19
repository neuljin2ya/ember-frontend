package com.ember.ember.admin.dto.analytics;

import java.time.LocalDate;
import java.util.List;

/**
 * 세그먼트 Overview 분석 응답 — 관리자 API §18.2 일부 / 설계서 §3.4.
 *
 * 성별 × 연령대 × 지역(시·도) 세그먼트별로 KPI 를 집계한다. v1 은 DAU 대신 활동 사용자 수
 * 기반 간이 지표 3종(signups/activeUsers/diaryCompletionRate/acceptanceRate) 을 제공한다.
 *
 * age_group: LT20 / 20-24 / 25-29 / 30-34 / 35-39 / 40+ / UNKNOWN — 설계서 §3.4.2.
 * gender: MALE / FEMALE / UNKNOWN (NULL → UNKNOWN).
 * regionCode: users.sido (NULL → UNKNOWN).
 *
 * k-anonymity: users < 5 세그먼트는 masked=true 로 값 null 처리.
 */
public record SegmentOverviewResponse(
        Period period,
        String metric,                 // "DIARY" | "ACCEPT" | "SIGNUP" | "ACTIVE"
        List<String> groupBy,
        List<SegmentRow> segments,
        Integer kMin,
        Meta meta
) {

    public record Period(LocalDate start, LocalDate end, String tz) {}

    public record SegmentRow(
            String gender,
            String ageGroup,
            String regionCode,
            long users,                // 세그먼트 모수 (ACTIVE & !deleted)
            Double value,              // metric 값 (masked 시 null)
            boolean masked,
            String reason              // masked 인 경우 "k<5" 등
    ) {}

    public record Meta(Boolean degraded, String source) {}
}
