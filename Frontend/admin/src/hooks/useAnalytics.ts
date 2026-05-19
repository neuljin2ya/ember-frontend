import { useQuery } from '@tanstack/react-query';
import { analyticsApi } from '@/lib/api/analytics';
import type { AnalyticsDateRangeParams, KeywordTagType, SegmentMetric } from '@/types/analytics';

/**
 * 관리자 분석 API React Query 훅 — 17개 엔드포인트.
 *
 * 공통 정책:
 *   - staleTime  : 5분 (분석 지표는 분 단위 변동 적음)
 *   - gcTime     : 30분 (cache retention)
 *   - refetch    : window focus 시 재조회 (default true)
 *   - enabled    : 필수 파라미터 체크는 컴포넌트 호출 전에 조건부 처리
 */

const STALE_MS = 5 * 60 * 1000;      // 5분
const GC_MS = 30 * 60 * 1000;        // 30분

const unwrap = <T,>(fn: () => Promise<{ data: { data: T } }>) =>
  fn().then((res) => res.data.data);

// =============================================================================
// B-1.1 매칭 퍼널
// =============================================================================

export function useMatchingFunnel(params?: AnalyticsDateRangeParams & { gender?: 'M' | 'F' | 'ALL' }) {
  return useQuery({
    queryKey: ['analytics', 'matching-funnel', params],
    queryFn: () => unwrap(() => analyticsApi.getMatchingFunnel(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-1.2 사용자 퍼널·코호트
// =============================================================================

export function useUserFunnel(params?: AnalyticsDateRangeParams & { cohort?: 'signup_date' | 'first_match_date' }) {
  return useQuery({
    queryKey: ['analytics', 'user-funnel', params],
    queryFn: () => unwrap(() => analyticsApi.getUserFunnel(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-1.3 키워드 TopN
// =============================================================================

export function useKeywordTop(params?: AnalyticsDateRangeParams & { tagType?: KeywordTagType; limit?: number }) {
  return useQuery({
    queryKey: ['analytics', 'keywords-top', params],
    queryFn: () => unwrap(() => analyticsApi.getKeywordTop(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-1.4 세그먼트 Overview
// =============================================================================

export function useSegmentOverview(params?: AnalyticsDateRangeParams & { metric?: SegmentMetric; groupBy?: string[] }) {
  return useQuery({
    queryKey: ['analytics', 'segments-overview', params],
    queryFn: () => unwrap(() => analyticsApi.getSegmentOverview(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-1.5 여정 소요시간
// =============================================================================

export function useJourneyDurations(params?: AnalyticsDateRangeParams) {
  return useQuery({
    queryKey: ['analytics', 'journey-durations', params],
    queryFn: () => unwrap(() => analyticsApi.getJourneyDurations(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-1.6 AI 성능
// =============================================================================

export function useAiPerformance(params?: { startTs?: string; endTs?: string }) {
  return useQuery({
    queryKey: ['analytics', 'ai-performance', params],
    queryFn: () => unwrap(() => analyticsApi.getAiPerformance(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-1.7 매칭 다양성·재추천
// =============================================================================

export function useMatchingDiversity(params?: AnalyticsDateRangeParams) {
  return useQuery({
    queryKey: ['analytics', 'matching-diversity', params],
    queryFn: () => unwrap(() => analyticsApi.getMatchingDiversity(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-2.1 일기 시간 히트맵
// =============================================================================

export function useDiaryTimeHeatmap(params?: AnalyticsDateRangeParams) {
  return useQuery({
    queryKey: ['analytics', 'diary-time-heatmap', params],
    queryFn: () => unwrap(() => analyticsApi.getDiaryTimeHeatmap(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-2.2 일기 길이·품질
// =============================================================================

export function useDiaryLengthQuality(params?: AnalyticsDateRangeParams) {
  return useQuery({
    queryKey: ['analytics', 'diary-length-quality', params],
    queryFn: () => unwrap(() => analyticsApi.getDiaryLengthQuality(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-2.3 감정 태그 추이
// =============================================================================

export function useDiaryEmotionTrends(params?: AnalyticsDateRangeParams & { bucket?: 'day' | 'week'; topN?: number }) {
  return useQuery({
    queryKey: ['analytics', 'diary-emotion-trends', params],
    queryFn: () => unwrap(() => analyticsApi.getDiaryEmotionTrends(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-2.4 주제 참여
// =============================================================================

export function useDiaryTopicParticipation(params?: AnalyticsDateRangeParams) {
  return useQuery({
    queryKey: ['analytics', 'diary-topic-participation', params],
    queryFn: () => unwrap(() => analyticsApi.getDiaryTopicParticipation(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-2.5 교환일기 응답률
// =============================================================================

export function useExchangeResponseRate(params?: AnalyticsDateRangeParams & { windowHours?: number }) {
  return useQuery({
    queryKey: ['analytics', 'exchange-response-rate', params],
    queryFn: () => unwrap(() => analyticsApi.getExchangeResponseRate(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-2.6 교환일기 턴→채팅 퍼널
// =============================================================================

export function useExchangeTurnFunnel(params?: AnalyticsDateRangeParams) {
  return useQuery({
    queryKey: ['analytics', 'exchange-turn-funnel', params],
    queryFn: () => unwrap(() => analyticsApi.getExchangeTurnFunnel(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-2.7 사용자 이탈 생존분석 Kaplan-Meier
// =============================================================================

export function useRetentionSurvival(params?: AnalyticsDateRangeParams & { inactivityDays?: number }) {
  return useQuery({
    queryKey: ['analytics', 'retention-survival', params],
    queryFn: () => unwrap(() => analyticsApi.getRetentionSurvival(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-3 사용자 세그먼테이션 (RFM + K-Means)
// =============================================================================

export function useUserSegmentation(params?: AnalyticsDateRangeParams & { method?: 'RFM' | 'KMEANS' | 'BOTH'; k?: number }) {
  return useQuery({
    queryKey: ['analytics', 'user-segmentation', params],
    queryFn: () => unwrap(() => analyticsApi.getUserSegmentation(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-4 연관 규칙 마이닝 Apriori
// =============================================================================

export function useDiaryAssociationRules(params?: AnalyticsDateRangeParams & {
  tagTypes?: string[];
  minSupport?: number;
  minConfidence?: number;
  minLift?: number;
  maxItemsetSize?: number;
}) {
  return useQuery({
    queryKey: ['analytics', 'diary-association-rules', params],
    queryFn: () => unwrap(() => analyticsApi.getDiaryAssociationRules(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}

// =============================================================================
// B-5 코호트 리텐션 매트릭스
// =============================================================================

export function useCohortRetention(params?: AnalyticsDateRangeParams & { maxWeeks?: number }) {
  return useQuery({
    queryKey: ['analytics', 'cohort-retention', params],
    queryFn: () => unwrap(() => analyticsApi.getCohortRetention(params)),
    staleTime: STALE_MS,
    gcTime: GC_MS,
  });
}
