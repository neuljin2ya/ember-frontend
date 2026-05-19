import apiClient from './client';
import type { ApiResponse, PageResponse } from './types';
import type { Report, ReportSearchParams, ReportSummary } from '@/types/report';

/**
 * 관리자 신고 API — 관리자 API 통합명세서 v2.1 §5.
 * BE 형상(Phase A-3)에 맞춤 — resolve/dismiss 필드명은 BE 계약을 따른다.
 */
export const reportsApi = {
  // §5.1 목록 (priority/SLA 정렬, assignedTo/slaOverdue/minPriority 필터)
  getList: (params: ReportSearchParams) =>
    apiClient.get<ApiResponse<PageResponse<Report>>>('/api/admin/reports', { params }),

  // §5.2 요약 (pending/warning/exceeded 카운트)
  getSummary: () =>
    apiClient.get<ApiResponse<ReportSummary>>('/api/admin/reports/summary'),

  // §5.3 상세 (slaStatus + targetPreviousReports 5건 포함)
  getDetail: (reportId: number) =>
    apiClient.get<ApiResponse<Report>>(`/api/admin/reports/${reportId}`),

  // §5.6 맥락 조회 — ADMIN+, PII 접근 로그 자동 기록 (Fail-Closed)
  getContext: (reportId: number) =>
    apiClient.get<ApiResponse<{
      reportId: number;
      contextType: string;
      contextId: number | null;
      evidenceContent: string | null;
      note: string | null;
    }>>(`/api/admin/reports/${reportId}/context`),

  // §5.4 처리 — action: WARNING / SUSPEND_7D / SUSPEND_PERMANENT
  resolve: (
    reportId: number,
    data: {
      action: 'WARNING' | 'SUSPEND_7D' | 'SUSPEND_PERMANENT';
      note: string;
    },
  ) => apiClient.post<ApiResponse<null>>(`/api/admin/reports/${reportId}/resolve`, data),

  // §5.5 기각 — reason 필수
  dismiss: (reportId: number, data: { reason: string }) =>
    apiClient.post<ApiResponse<null>>(`/api/admin/reports/${reportId}/dismiss`, data),

  // §5.7 담당자 배정
  assign: (reportId: number, data: { assigneeId: number; reason?: string }) =>
    apiClient.patch<ApiResponse<null>>(`/api/admin/reports/${reportId}/assign`, data),

  // §5.12 패턴 분석
  patternAnalysis: (params?: { periodDays?: number; topN?: number }) =>
    apiClient.get<ApiResponse<unknown>>('/api/admin/reports/pattern-analysis', { params }),
};
