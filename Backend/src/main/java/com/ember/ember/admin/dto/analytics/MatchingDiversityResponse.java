package com.ember.ember.admin.dto.analytics;

import java.time.LocalDate;

/**
 * 매칭 통계 보조 응답 — 관리자 API §18.2 / 설계서 §3.7.
 *
 * 추천 다양성(Shannon Entropy), 재추천 비율, 고유 후보 수를 집계한다.
 *
 * 스키마 매핑:
 *   - matching_recommendations(user_id, candidate_user_id) → matchings(from_user_id, to_user_id)
 *   - 재추천 판정: 동일 (from_user_id, to_user_id) 쌍이 14일 이내 2회 이상 생성된 케이스.
 *
 * 엔트로피는 후보(= to_user_id) 등장 확률분포 기반으로 계산한다. 후보가 0~1명이면 NaN
 * 이 되므로 Service 에서 COALESCE(0) 처리.
 */
public record MatchingDiversityResponse(
        Period period,
        long totalRecs,
        long uniqueCandidates,
        Double shannonEntropy,
        long rerecommendationCount,
        Double rerecommendationRate,
        Meta meta
) {

    public record Period(LocalDate start, LocalDate end, String tz) {}

    public record Meta(Integer rerecWindowDays, String source) {}
}
