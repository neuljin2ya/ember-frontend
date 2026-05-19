import apiClient from './client';
import type { ApiResponse } from './types';
import type {
  AnalyticsDateRangeParams,
  AssociationRulesResponse,
  AiPerformanceResponse,
  CohortRetentionResponse,
  DiaryEmotionTrendResponse,
  DiaryLengthQualityResponse,
  DiaryTimeHeatmapResponse,
  DiaryTopicParticipationResponse,
  ExchangeResponseRateResponse,
  ExchangeTurnFunnelResponse,
  JourneyDurationResponse,
  KeywordTagType,
  KeywordTopResponse,
  MatchingDiversityResponse,
  MatchingFunnelResponse,
  RetentionSurvivalResponse,
  SegmentMetric,
  SegmentOverviewResponse,
  UserFunnelResponse,
  UserSegmentationResponse,
} from '@/types/analytics';

const BASE = '/api/admin/analytics';

/**
 * 관리자 분석 API 클라이언트 — 백엔드 §18 / 설계서 §3.
 *
 * 엔드포인트 17개 (B-1.1 ~ B-5).
 * - 날짜 기본값은 백엔드에서 처리 (없으면 최근 29/89일 등).
 * - ApiResponse<T> unwrap 은 hooks 레이어에서 수행.
 */
export const analyticsApi = {
  // ------------------------------------------------------------------
  // B-1.1 매칭 퍼널
  // ------------------------------------------------------------------
  getMatchingFunnel: (params?: AnalyticsDateRangeParams & { gender?: 'M' | 'F' | 'ALL' }) =>
    apiClient.get<ApiResponse<MatchingFunnelResponse>>(`${BASE}/matching/funnel`, { params }),

  // ------------------------------------------------------------------
  // B-1.2 사용자 퍼널·코호트
  // ------------------------------------------------------------------
  getUserFunnel: (params?: AnalyticsDateRangeParams & { cohort?: 'signup_date' | 'first_match_date' }) =>
    apiClient.get<ApiResponse<UserFunnelResponse>>(`${BASE}/users/funnel`, { params }),

  // ------------------------------------------------------------------
  // B-1.3 키워드 TopN
  // ------------------------------------------------------------------
  getKeywordTop: (params?: AnalyticsDateRangeParams & { tagType?: KeywordTagType; limit?: number }) =>
    apiClient.get<ApiResponse<KeywordTopResponse>>(`${BASE}/keywords/top`, { params }),

  // ------------------------------------------------------------------
  // B-1.4 세그먼트 Overview
  // ------------------------------------------------------------------
  getSegmentOverview: (params?: AnalyticsDateRangeParams & { metric?: SegmentMetric; groupBy?: string[] }) =>
    apiClient.get<ApiResponse<SegmentOverviewResponse>>(`${BASE}/segments/overview`, {
      params,
      paramsSerializer: { indexes: null }, // groupBy=gender&groupBy=ageGroup
    }),

  // ------------------------------------------------------------------
  // B-1.5 여정 소요시간
  // ------------------------------------------------------------------
  getJourneyDurations: (params?: AnalyticsDateRangeParams) =>
    apiClient.get<ApiResponse<JourneyDurationResponse>>(`${BASE}/journeys/durations`, { params }),

  // ------------------------------------------------------------------
  // B-1.6 AI 성능 (DateTime 파라미터 — startTs/endTs ISO)
  // ------------------------------------------------------------------
  getAiPerformance: (params?: { startTs?: string; endTs?: string }) =>
    apiClient.get<ApiResponse<AiPerformanceResponse>>(`${BASE}/ai/performance`, { params }),

  // ------------------------------------------------------------------
  // B-1.7 매칭 다양성·재추천
  // ------------------------------------------------------------------
  getMatchingDiversity: (params?: AnalyticsDateRangeParams) =>
    apiClient.get<ApiResponse<MatchingDiversityResponse>>(`${BASE}/matching/diversity`, { params }),

  // ------------------------------------------------------------------
  // B-2.1 일기 시간 히트맵
  // ------------------------------------------------------------------
  getDiaryTimeHeatmap: (params?: AnalyticsDateRangeParams) =>
    apiClient.get<ApiResponse<DiaryTimeHeatmapResponse>>(`${BASE}/diary/time-heatmap`, { params }),

  // ------------------------------------------------------------------
  // B-2.2 일기 길이·품질
  // ------------------------------------------------------------------
  getDiaryLengthQuality: (params?: AnalyticsDateRangeParams) =>
    apiClient.get<ApiResponse<DiaryLengthQualityResponse>>(`${BASE}/diary/length-quality`, { params }),

  // ------------------------------------------------------------------
  // B-2.3 감정 태그 추이
  // ------------------------------------------------------------------
  getDiaryEmotionTrends: (params?: AnalyticsDateRangeParams & { bucket?: 'day' | 'week'; topN?: number }) =>
    apiClient.get<ApiResponse<DiaryEmotionTrendResponse>>(`${BASE}/diary/emotion-trends`, { params }),

  // ------------------------------------------------------------------
  // B-2.4 주제 참여
  // ------------------------------------------------------------------
  getDiaryTopicParticipation: (params?: AnalyticsDateRangeParams) =>
    apiClient.get<ApiResponse<DiaryTopicParticipationResponse>>(`${BASE}/diary/topic-participation`, { params }),

  // ------------------------------------------------------------------
  // B-2.5 교환일기 응답률
  // ------------------------------------------------------------------
  getExchangeResponseRate: (params?: AnalyticsDateRangeParams & { windowHours?: number }) =>
    apiClient.get<ApiResponse<ExchangeResponseRateResponse>>(`${BASE}/exchange/response-rate`, { params }),

  // ------------------------------------------------------------------
  // B-2.6 교환일기 턴→채팅 퍼널
  // ------------------------------------------------------------------
  getExchangeTurnFunnel: (params?: AnalyticsDateRangeParams) =>
    apiClient.get<ApiResponse<ExchangeTurnFunnelResponse>>(`${BASE}/exchange/turn-funnel`, { params }),

  // ------------------------------------------------------------------
  // B-2.7 사용자 이탈 생존분석 Kaplan-Meier
  // ------------------------------------------------------------------
  getRetentionSurvival: (params?: AnalyticsDateRangeParams & { inactivityDays?: number }) =>
    apiClient.get<ApiResponse<RetentionSurvivalResponse>>(`${BASE}/users/retention-survival`, { params }),

  // ------------------------------------------------------------------
  // B-3 사용자 세그먼테이션 (RFM + K-Means)
  // ------------------------------------------------------------------
  getUserSegmentation: (params?: AnalyticsDateRangeParams & { method?: 'RFM' | 'KMEANS' | 'BOTH'; k?: number }) =>
    apiClient.get<ApiResponse<UserSegmentationResponse>>(`${BASE}/users/segmentation`, { params }),

  // ------------------------------------------------------------------
  // B-4 연관 규칙 마이닝 Apriori
  // ------------------------------------------------------------------
  getDiaryAssociationRules: (params?: AnalyticsDateRangeParams & {
    tagTypes?: string[];
    minSupport?: number;
    minConfidence?: number;
    minLift?: number;
    maxItemsetSize?: number;
  }) =>
    apiClient.get<ApiResponse<AssociationRulesResponse>>(`${BASE}/diary/association-rules`, {
      params,
      paramsSerializer: { indexes: null },
    }),

  // ------------------------------------------------------------------
  // B-5 코호트 리텐션 매트릭스
  // ------------------------------------------------------------------
  getCohortRetention: (params?: AnalyticsDateRangeParams & { maxWeeks?: number }) =>
    apiClient.get<ApiResponse<CohortRetentionResponse>>(`${BASE}/users/cohort-retention`, { params }),
};
