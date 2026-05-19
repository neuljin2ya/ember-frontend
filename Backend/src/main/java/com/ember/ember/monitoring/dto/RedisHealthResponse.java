package com.ember.ember.monitoring.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/** Redis 캐시 건강도 — 프런트 {@code RedisHealthResponse} 일치. */
@Schema(description = "Redis 캐시 건강도")
public record RedisHealthResponse(

        @Schema(description = "사용 메모리(MB)") double memoryUsedMb,
        @Schema(description = "피크 메모리(MB)") double memoryPeakMb,
        @Schema(description = "캐시 패턴별 Hit Ratio 및 키 수") List<CachePattern> patterns,
        @Schema(description = "stale-fallback 적중 건수") long staleFallbackHits
) {
    public record CachePattern(
            @Schema(description = "Redis 키 패턴") String pattern,
            @Schema(description = "Hit Ratio(0.0~1.0)") double hitRatio,
            @Schema(description = "현재 키 개수") long keys
    ) {}
}
