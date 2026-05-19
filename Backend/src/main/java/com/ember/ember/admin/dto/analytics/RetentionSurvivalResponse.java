package com.ember.ember.admin.dto.analytics;

import java.time.LocalDate;
import java.util.List;

/**
 * 사용자 이탈 생존분석 (Kaplan-Meier) — 설계서 §3.14 (B-2.7).
 *
 * 이벤트 정의(Death):
 *   - deactivated_at IS NOT NULL (명시 탈퇴 유예)  OR
 *   - last_login_at  < NOW() - INTERVAL 'inactivityThresholdDays days' (암묵 이탈)
 * 검열(Censored): 위 두 조건에 해당하지 않는 활동중 사용자.
 *
 * 산출물:
 *   - point 마다 S(t) = ∏(1 - d_i / n_i)
 *   - Greenwood 분산: Var(S(t)) = S(t)^2 * Σ(d_i / (n_i * (n_i - d_i)))
 *   - 95% 신뢰구간: S(t) ± 1.96 * stdError
 *   - medianSurvivalDay: S(t) 가 처음 0.5 이하로 떨어지는 시점 (도달 안 하면 null)
 *
 * 포트폴리오 가치:
 *   SQL-native 구현 (lifelines / scipy 없이). CTE + Window Function 로 1-shot.
 */
public record RetentionSurvivalResponse(
        Period period,
        int inactivityThresholdDays,
        long cohortSize,
        long eventCount,         // 이탈 이벤트 발생자 수
        long censoredCount,      // 검열(활동중) 수
        Integer medianSurvivalDay,
        List<SurvivalPoint> curve,
        Meta meta
) {
    public record Period(LocalDate startDate, LocalDate endDate, String timezone) {}

    /**
     * @param day                 가입 후 경과 일수
     * @param atRisk              해당 시점 리스크 셋 크기
     * @param events              해당 시점 이탈 이벤트 수
     * @param survivalProbability S(t)
     * @param stdError            Greenwood 표준오차
     * @param ciLower             95% CI 하한 (max 0)
     * @param ciUpper             95% CI 상한 (min 1)
     */
    public record SurvivalPoint(
            int day,
            long atRisk,
            long events,
            Double survivalProbability,
            Double stdError,
            Double ciLower,
            Double ciUpper
    ) {}

    public record Meta(
            String algorithm,           // "kaplan-meier-greenwood"
            String eventDefinition,     // "deactivated_at OR last_login_at < threshold"
            boolean degraded,           // user_activity_events 미활용 fallback 여부
            String dataSourceVersion
    ) {}
}
