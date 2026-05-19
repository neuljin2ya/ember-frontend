package com.ember.ember.exchange.dto;

import lombok.Builder;
import java.util.List;

/**
 * 교환일기 공통점 리포트 응답
 */
@Builder
public record ExchangeReportResponse(
        Long reportId,
        String status,
        List<String> commonKeywords,
        Double emotionSimilarity,
        List<String> lifestylePatterns,
        String writingTempA,
        String writingTempB,
        String aiDescription,
        String generatedAt
) {}
