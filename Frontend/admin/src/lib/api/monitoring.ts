// AI 파이프라인 모니터링 API — v2.2 신규 12종 (§12 기준)
import apiClient from './client';
import type { ApiResponse } from './types';

// ─── 응답 타입 ───────────────────────────────────────────────

export interface AiMonitoringOverview {
  consentRate: number;
  dlqSize: number;
  outboxPending: number;
  outboxFailed: number;
  redisHitRatio: number;
  analysisProcessing: number;
  analysisFailed: number;
}

export interface ConsentStatsResponse {
  totalUsers: number;
  analysisConsentRate: number;
  matchingConsentRate: number;
  revokedCount: number;
  dailyTrend: Array<{ date: string; consent: number; revoke: number }>;
}

export interface MqStatusResponse {
  queues: Array<{ name: string; pending: number; consumers: number; dlqSize: number }>;
}

export interface OutboxStatusResponse {
  pending: number;
  failed: number;
  lagP95Ms: number;
  failedSample: Array<{
    id: number;
    aggregateType: string;
    eventType: string;
    lastError: string;
    createdAt: string;
  }>;
}

export interface RedisHealthResponse {
  memoryUsedMb: number;
  memoryPeakMb: number;
  patterns: Array<{ pattern: string; hitRatio: number; keys: number }>;
  staleFallbackHits: number;
}

export interface AnalysisOverviewResponse {
  diary: { processing: number; done: number; failed: number; skipped: number };
  report: { processing: number; done: number; failed: number; consentRequired: number };
  longProcessing: Array<{
    id: number;
    type: 'DIARY' | 'REPORT';
    startedAt: string;
    elapsedMinutes: number;
  }>;
}

// ─── API 함수 ────────────────────────────────────────────────

export const monitoringApi = {
  // AI 파이프라인 개요 (§12)
  getAiOverview: () =>
    apiClient.get<ApiResponse<AiMonitoringOverview>>('/api/admin/monitoring/ai/overview'),

  // AI 동의 통계 (range 기준)
  getConsentStats: (range: '7d' | '24h' | '30d' = '7d') =>
    apiClient.get<ApiResponse<ConsentStatsResponse>>('/api/admin/monitoring/ai/consent-stats', {
      params: { range },
    }),

  // MQ 큐 상태
  getMqStatus: () =>
    apiClient.get<ApiResponse<MqStatusResponse>>('/api/admin/monitoring/mq/status'),

  // OutboxRelay 상태
  getOutboxStatus: () =>
    apiClient.get<ApiResponse<OutboxStatusResponse>>('/api/admin/monitoring/outbox/status'),

  // Redis 캐시 건강도
  getRedisHealth: () =>
    apiClient.get<ApiResponse<RedisHealthResponse>>('/api/admin/monitoring/redis/health'),

  // 일기/리포트 분석 현황
  getAnalysisOverview: () =>
    apiClient.get<ApiResponse<AnalysisOverviewResponse>>('/api/admin/monitoring/analysis/overview'),

  // SUPER_ADMIN 액션: DLQ 재처리
  reprocessDlq: (queueName: string) =>
    apiClient.post<ApiResponse<{ processedCount: number }>>(
      '/api/admin/monitoring/mq/dlq/reprocess',
      { queueName },
    ),

  // SUPER_ADMIN 액션: Outbox 이벤트 재시도
  retryOutbox: (eventIds?: number[]) =>
    apiClient.post<ApiResponse<{ retriedCount: number }>>(
      '/api/admin/monitoring/outbox/retry',
      { eventIds },
    ),

  // SUPER_ADMIN 액션: 일기 분석 강제 FAILED 전이
  forceFailDiary: (diaryId: number, reason: string) =>
    apiClient.post<ApiResponse<null>>(
      `/api/admin/diaries/${diaryId}/analysis-status/force-fail`,
      { reason },
    ),

  // SUPER_ADMIN 액션: 리포트 동의 리마인드 알림
  consentRemind: (reportId: number) =>
    apiClient.post<ApiResponse<null>>(
      `/api/admin/exchange-reports/${reportId}/consent-remind`,
    ),

  // AI 동의 통계 상세 (§3)
  getConsentStatsGeneral: (range: '7d' | '30d' = '7d') =>
    apiClient.get<ApiResponse<ConsentStatsResponse>>('/api/admin/consent/stats', {
      params: { range },
    }),

  // 미동의 사용자 목록
  getConsentMissingUsers: (params: {
    page: number;
    size: number;
    filter: 'NO_AI_ANALYSIS' | 'NO_MATCHING';
  }) =>
    apiClient.get<
      ApiResponse<{
        content: Array<{ userId: number; nickname: string; lastLoginAt: string }>;
        total: number;
      }>
    >('/api/admin/consent/users', { params }),
};
