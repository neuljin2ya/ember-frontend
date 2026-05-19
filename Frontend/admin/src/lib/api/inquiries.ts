import apiClient from './client';
import type { ApiResponse, PageResponse } from './types';
import type {
  Inquiry,
  InquirySearchParams,
  InquiryStatus,
} from '@/types/support';

/**
 * 고객 문의 관리 API.
 * 출처: 관리자_API_통합명세서_v2.0 §17.1
 */
export const inquiriesApi = {
  // 17.1.1 목록 조회 (VIEWER 이상)
  getList: (params: InquirySearchParams) =>
    apiClient.get<ApiResponse<PageResponse<Inquiry>>>('/api/admin/support/inquiries', {
      params,
    }),

  // 17.1.2 상세 조회 (VIEWER 이상)
  getDetail: (inquiryId: number) =>
    apiClient.get<ApiResponse<Inquiry>>(`/api/admin/support/inquiries/${inquiryId}`),

  // 17.1.3 담당자 배정 (ADMIN 이상)
  assign: (inquiryId: number, adminId: number) =>
    apiClient.patch<ApiResponse<null>>(
      `/api/admin/inquiries/${inquiryId}/assign`,
      { adminId },
    ),

  // 17.1.4 답변 등록 (ADMIN 이상)
  answer: (inquiryId: number, answer: string) =>
    apiClient.post<ApiResponse<null>>(
      `/api/admin/inquiries/${inquiryId}/answer`,
      { answer },
    ),

  // 17.1.5 상태 변경 (ADMIN 이상)
  updateStatus: (inquiryId: number, status: InquiryStatus) =>
    apiClient.patch<ApiResponse<null>>(
      `/api/admin/inquiries/${inquiryId}/status`,
      { status },
    ),
};
