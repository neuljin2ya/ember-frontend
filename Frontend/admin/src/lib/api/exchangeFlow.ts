import apiClient from './client';
import type { ApiResponse } from './types';

/**
 * 교환일기 흐름 / 가이드 API — 관리자 API v2.1 §6.7 + flow-stats (Phase A-4 BE 연동).
 */
export interface GuideStep {
  id: number;
  stepOrder: number;
  stepTitle: string;
  description: string;
  imageUrl: string | null;
  isActive: boolean;
}

export interface FlowFunnelStep {
  stepName: string;
  enteredCount: number;
  exitedCount: number;
  retentionRate: number;
}

export interface ExchangeFlowStats {
  periodDays: number;
  matchingStartedCount: number;
  roomActiveCount: number;
  completedCount: number;
  terminatedCount: number;
  completionRate: number;
  avgTurnsToComplete: number;
  funnel: FlowFunnelStep[];
}

export const exchangeFlowApi = {
  getGuideSteps: () =>
    apiClient.get<ApiResponse<GuideStep[]>>('/api/admin/exchange-diary-guide'),

  replaceGuideSteps: (data: {
    steps: Array<{
      stepOrder: number;
      stepTitle: string;
      description: string;
      imageUrl?: string;
      isActive?: boolean;
    }>;
  }) =>
    apiClient.put<ApiResponse<GuideStep[]>>('/api/admin/exchange-diary-guide/steps', data),

  getFlowStats: (periodDays = 30) =>
    apiClient.get<ApiResponse<ExchangeFlowStats>>(
      '/api/admin/exchange-rooms/flow-stats',
      { params: { periodDays } },
    ),
};
