import apiClient from './client';
import type { ApiResponse, PageResponse } from './types';

/**
 * 외부 연락처 감지 API — 관리자 API v2.1 §5.10 / §5.11 (Phase A-3.5 BE 연동).
 */
export type ContactPatternType = 'PHONE' | 'EMAIL' | 'KAKAO' | 'INSTAGRAM' | 'LINK' | 'OTHER';
export type ContactContentType = 'DIARY' | 'EXCHANGE_DIARY' | 'CHAT_MESSAGE';
export type ContactStatus = 'PENDING' | 'CONFIRMED' | 'FALSE_POSITIVE';
export type ContactActionType = 'HIDE_AND_WARN' | 'ESCALATE_TO_REPORT' | 'DISMISS';

export interface ContactDetection {
  id: number;
  userId: number;
  nickname: string;
  contentType: ContactContentType;
  contentId: number | null;
  detectedText: string;
  patternType: ContactPatternType;
  context: string | null;
  status: ContactStatus;
  actionType: ContactActionType | null;
  confidence: number;
  adminMemo: string | null;
  detectedAt: string;
  reviewedByName: string | null;
  reviewedAt: string | null;
}

export interface ContactDetectionStats {
  periodDays: number;
  totalCount: number;
  pendingCount: number;
  confirmedCount: number;
  falsePositiveCount: number;
  byPatternType: Record<ContactPatternType, number>;
}

export interface ContactSearchParams {
  status?: ContactStatus;
  patternType?: ContactPatternType;
  periodDays?: number;
  page?: number;
  size?: number;
}

export const contactsApi = {
  getList: (params?: ContactSearchParams) =>
    apiClient.get<ApiResponse<PageResponse<ContactDetection>>>(
      '/api/admin/contact-detections',
      { params },
    ),

  getStats: (periodDays = 7) =>
    apiClient.get<ApiResponse<ContactDetectionStats>>(
      '/api/admin/contact-detections/stats',
      { params: { periodDays } },
    ),

  getDetail: (detectionId: number) =>
    apiClient.get<ApiResponse<ContactDetection>>(
      `/api/admin/contact-detections/${detectionId}`,
    ),

  /** §5.11 조치 — HIDE_AND_WARN·ESCALATE_TO_REPORT → CONFIRMED, DISMISS → FALSE_POSITIVE. */
  applyAction: (detectionId: number, data: { action: ContactActionType; adminMemo: string }) =>
    apiClient.patch<ApiResponse<ContactDetection>>(
      `/api/admin/contact-detections/${detectionId}/action`,
      data,
    ),
};
