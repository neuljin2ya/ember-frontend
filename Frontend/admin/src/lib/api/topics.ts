import apiClient from './client';
import type { ApiResponse, PageResponse } from './types';
import type { Topic, TopicSearchParams, TopicSchedule } from '@/types/content';

/**
 * 주제 관리 API — 관리자 API v2.1 §6.4 / §6.5.
 * BE 형상(Phase A-4)에 맞춤 — `content` 필드는 `topic` 으로, schedule 은 단일 topicId+overrideReason.
 */
export const topicsApi = {
  getList: (params?: TopicSearchParams) =>
    apiClient.get<ApiResponse<PageResponse<Topic>>>('/api/admin/topics', { params }),

  /** 주제 등록 — BE: topic/category/weekStartDate(월요일 기준 자동 정규화)/isActive? */
  create: (data: {
    topic: string;
    category: 'GRATITUDE' | 'GROWTH' | 'DAILY' | 'EMOTION' | 'RELATIONSHIP' | 'SEASONAL';
    weekStartDate: string;
    isActive?: boolean;
  }) => apiClient.post<ApiResponse<Topic>>('/api/admin/topics', data),

  update: (id: number, data: { topic?: string; category?: string; isActive?: boolean }) =>
    apiClient.put<ApiResponse<Topic>>(`/api/admin/topics/${id}`, data),

  delete: (id: number) =>
    apiClient.delete<ApiResponse<null>>(`/api/admin/topics/${id}`),

  getSchedule: () =>
    apiClient.get<ApiResponse<TopicSchedule[]>>('/api/admin/topics/schedule'),

  /** §6.5 주간 주제 재배정 — 단일 topicId + overrideReason (BE 계약). */
  overrideSchedule: (week: string, data: { topicId: number; overrideReason: string }) =>
    apiClient.put<ApiResponse<null>>(`/api/admin/topics/schedule/${week}`, data),
};
