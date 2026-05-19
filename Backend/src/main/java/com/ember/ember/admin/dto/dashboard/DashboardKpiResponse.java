package com.ember.ember.admin.dto.dashboard;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 대시보드 KPI 응답 — 프론트엔드 DashboardKPIResponse 타입에 맞춤.
 */
public record DashboardKpiResponse(
    List<KpiCard> kpiCards,
    List<AnomalyAlert> anomalyAlerts,
    String lastUpdatedAt
) {
    public record KpiCard(
        String key,
        String label,
        long currentValue,
        double changeRate,
        String changeDirection
    ) {}

    public record AnomalyAlert(
        String message,
        String severity,
        String link
    ) {}

    public static DashboardKpiResponse of(
        long totalSignups, long newSignupsToday, long activeMatching,
        double matchingSuccessRate, long diaryCountToday,
        long exchangeDiaryCountToday, double churnRate7d,
        long pendingReports
    ) {
        List<KpiCard> cards = List.of(
            new KpiCard("totalSignups", "누적 가입자", totalSignups, 0, "UP"),
            new KpiCard("newSignupsToday", "오늘 가입", newSignupsToday, 0, "UP"),
            new KpiCard("activeMatching", "활성 매칭", activeMatching, 0, "UP"),
            new KpiCard("matchingSuccessRate", "매칭 성공률", (long) matchingSuccessRate, 0, "UP"),
            new KpiCard("diaryCountToday", "오늘 일기", diaryCountToday, 0, "UP"),
            new KpiCard("exchangeDiaryCountToday", "오늘 교환일기", exchangeDiaryCountToday, 0, "UP"),
            new KpiCard("churnRate7d", "7일 이탈률", (long) churnRate7d, 0, "DOWN"),
            new KpiCard("pendingReports", "미처리 신고", pendingReports, 0, "UP")
        );

        List<AnomalyAlert> alerts = new java.util.ArrayList<>();
        if (pendingReports > 5) {
            alerts.add(new AnomalyAlert(
                "미처리 신고가 " + pendingReports + "건 있습니다.",
                "WARNING", "/admin/reports"));
        }
        if (churnRate7d > 10) {
            alerts.add(new AnomalyAlert(
                "7일 이탈률이 " + String.format("%.1f", churnRate7d) + "%입니다.",
                "WARNING", "/admin/analytics/retention"));
        }

        return new DashboardKpiResponse(cards, alerts,
            LocalDateTime.now().toString());
    }
}
