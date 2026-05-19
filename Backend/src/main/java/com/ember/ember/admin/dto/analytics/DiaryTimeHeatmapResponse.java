package com.ember.ember.admin.dto.analytics;

import java.time.LocalDate;
import java.util.List;

/**
 * 일기 작성 시간대 히트맵 — 설계서 §3.8 (B-2.1).
 *
 * 요일(0=일요일 ~ 6=토요일) × 시간(0~23) 24×7 버킷. KST 기준.
 * totalDiaries: 전체 일기 수 (분모, mask 여부 판정용).
 * peakDayOfWeek, peakHour: 최빈 작성 시간대.
 */
public record DiaryTimeHeatmapResponse(
        Period period,
        List<HeatmapCell> cells,
        long totalDiaries,
        Integer peakDayOfWeek,
        Integer peakHour,
        Meta meta
) {
    public record Period(LocalDate startDate, LocalDate endDate, String timezone) {}

    /**
     * @param dayOfWeek 0=일 ~ 6=토 (KST 기준 PostgreSQL EXTRACT(DOW) 규칙)
     * @param hour      0~23
     * @param count     해당 버킷 일기 수
     */
    public record HeatmapCell(int dayOfWeek, int hour, long count) {}

    public record Meta(int kAnonymityMin, String dataSourceVersion) {}
}
