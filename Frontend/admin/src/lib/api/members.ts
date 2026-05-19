import apiClient from './client';
import type { ApiResponse, PageResponse } from './types';
import type { AdminMemberListItem, AdminUserDetail, ActivitySummary, MemberDiary, MemberSearchParams } from '@/types/user';

export const membersApi = {
  // 7.1 회원 목록 조회 (page/size 오프셋 페이지네이션)
  getList: (params: MemberSearchParams) =>
    apiClient.get<ApiResponse<PageResponse<AdminMemberListItem>>>('/api/admin/members', { params }),

  // 7.2 회원 상세 조회
  getDetail: (userId: number) =>
    apiClient.get<ApiResponse<AdminUserDetail>>(`/api/admin/members/${userId}`),

  // 7.2 회원 활동 요약
  getActivitySummary: (userId: number) =>
    apiClient.get<ApiResponse<ActivitySummary>>(`/api/admin/members/${userId}/activity-summary`),

  // 7.4 회원 활동 타임라인
  getActivityTimeline: (userId: number, params?: { period?: string; cursor?: string; limit?: number }) =>
    apiClient.get<ApiResponse<unknown>>(`/api/admin/members/${userId}/activity-timeline`, { params }),

  // 7.2 제재/신고 이력 (ADMIN+ only)
  getSanctionHistory: (userId: number) =>
    apiClient.get<ApiResponse<unknown>>(`/api/admin/members/${userId}/sanctions`),

  // 7.2 회원이 작성한 일기 목록
  getDiaries: (userId: number, params?: { page?: number; size?: number }) =>
    apiClient.get<ApiResponse<PageResponse<MemberDiary>>>(`/api/admin/members/${userId}/diaries`, { params }),

  // 7.3 7일 정지
  suspend: (userId: number, data: { memo: string }) =>
    apiClient.post<ApiResponse<null>>(`/api/admin/members/${userId}/suspend`, { type: '7DAY', ...data }),

  // 7.3 영구 정지
  ban: (userId: number, data: { memo: string }) =>
    apiClient.post<ApiResponse<null>>(`/api/admin/members/${userId}/ban`, { type: 'PERMANENT', ...data }),

  // 7.3 즉시 영구 정지 (SUPER_ADMIN only)
  immediateBan: (userId: number, data: { memo: string }) =>
    apiClient.post<ApiResponse<null>>(`/api/admin/members/${userId}/ban`, { type: 'IMMEDIATE_PERMANENT', ...data }),

  // 7.7 회원 제재 해제 (SUPER_ADMIN only)
  releaseSanction: (userId: number, reason: string) =>
    apiClient.post<ApiResponse<null>>(`/api/admin/users/${userId}/suspension/release`, { reason }),
};
