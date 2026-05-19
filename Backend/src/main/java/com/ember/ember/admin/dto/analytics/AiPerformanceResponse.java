package com.ember.ember.admin.dto.analytics;

import java.time.LocalDateTime;
import java.util.List;

/**
 * AI 성능 분석 응답 — 관리자 API §18.2 / 설계서 §3.6.
 *
 * 현재 시스템에 ai_inference_logs 테이블은 존재하지 않으므로 Fallback 으로 아래 두 소스를 사용:
 *   1) user_activity_events 의 AI_ANALYSIS_COMPLETED / AI_ANALYSIS_FAILED (일기 분석)
 *   2) lifestyle_analysis_log (라이프스타일 분석 성공 이력)
 *
 * 심층 모니터링(Latency P95 등)은 Prometheus 측에서 처리한다. 본 API 는 DB 기반 집계로
 * 성공/실패율 · 처리량 · 라이프스타일 분석 처리량만 노출한다.
 */
public record AiPerformanceResponse(
        Period period,
        DiaryAnalysis diaryAnalysis,
        LifestyleAnalysis lifestyleAnalysis,
        boolean degraded,
        Meta meta
) {

    public record Period(LocalDateTime start, LocalDateTime end, String tz) {}

    public record DiaryAnalysis(
            long completed,
            long failed,
            Double failRate,           // failed / (completed + failed)
            long totalEvents
    ) {}

    public record LifestyleAnalysis(
            long totalRuns,
            Double avgDiaryCount,
            List<DailyBucket> daily
    ) {}

    public record DailyBucket(
            java.time.LocalDate date,
            long runs
    ) {}

    public record Meta(String source, String note) {}
}
