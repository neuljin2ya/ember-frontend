import apiClient from './client';
import type { ApiResponse } from './types';
import type { SocialAuthIssue, SocialAuthStats, SocialAuthErrorHistory } from '@/types/system';

export const socialAuthApi = {
  // 소셜 로그인 오류 현황 (error-stats로 통합)
  getIssues: () =>
    apiClient.get<ApiResponse<SocialAuthIssue[]>>('/api/admin/social-login/error-stats'),

  // 소셜 로그인 성공/실패율
  getStats: () =>
    apiClient.get<ApiResponse<SocialAuthStats[]>>('/api/admin/social-login/error-stats', {
      params: { period: '24h' },
    }),

  // 오류 이력 조회
  getErrorHistory: (params?: { provider?: string; period?: string }) =>
    apiClient.get<ApiResponse<SocialAuthErrorHistory[]>>('/api/admin/social-login/error-history', { params }),
};
