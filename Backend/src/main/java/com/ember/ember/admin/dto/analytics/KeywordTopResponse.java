package com.ember.ember.admin.dto.analytics;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

/**
 * 키워드 TopN 분석 응답 — 관리자 API §18.2 일부 / 설계서 §3.3.
 *
 * 기간 내 완료 일기(analysis_status='COMPLETED')의 diary_keywords 를 집계해
 * 태그 유형(TagType)별 TopN 키워드를 반환한다.
 *
 * 스키마 매핑:
 *   - diary_keywords.keyword  → diary_keywords.label
 *   - diary_keywords.weight   → diary_keywords.score (DECIMAL 4,3)
 *   - tag_type                → DiaryKeyword.TagType (EMOTION/LIFESTYLE/RELATIONSHIP_STYLE/TONE)
 *
 * k-anonymity: userFreq >= 5 인 키워드만 노출 (설계서 §3.3.4 K1).
 */
public record KeywordTopResponse(
        Period period,
        String tagType,                // null 또는 단일 TagType 문자열
        List<KeywordItem> items,
        Integer kMin,
        Meta meta
) {

    public record Period(LocalDate start, LocalDate end, String tz) {}

    public record KeywordItem(
            String tagType,
            String keyword,            // == label 컬럼 값
            long freq,                 // 총 등장 횟수
            long diaryFreq,            // 등장 일기 수
            long userFreq,             // 등장 유저 수 (k-anon 기준)
            BigDecimal avgScore,
            BigDecimal p50Score,
            BigDecimal p90Score,
            int rank                   // tag_type 내 순위
    ) {}

    public record Meta(Boolean degraded, String source) {}
}
