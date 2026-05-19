import apiClient from './client';
import type { ApiResponse } from './types';

/**
 * 금칙어 관리자 API — 백엔드 §9.6 (BannedWordAdminController).
 * 4개 카테고리(PROFANITY/SEXUAL/DISCRIMINATION/ETC) + EXACT/PARTIAL 매칭.
 */

export type BannedWordCategory = 'PROFANITY' | 'SEXUAL' | 'DISCRIMINATION' | 'ETC';
export type BannedWordMatchMode = 'EXACT' | 'PARTIAL';

export interface BannedWordResponse {
  id: number;
  word: string;
  category: BannedWordCategory;
  matchMode: BannedWordMatchMode;
  isActive: boolean;
  createdByAdminId: number | null;
  createdByAdminName: string | null;
  createdAt: string;
  modifiedAt: string;
}

export interface BannedWordPage {
  content: BannedWordResponse[];
  totalElements: number;
  totalPages: number;
  number: number;
  size: number;
}

export interface BannedWordCreateRequest {
  word: string;
  category: BannedWordCategory;
  matchMode?: BannedWordMatchMode;
  isActive?: boolean;
}

export interface BannedWordUpdateRequest {
  category?: BannedWordCategory;
  matchMode?: BannedWordMatchMode;
  isActive?: boolean;
}

export interface BannedWordListParams {
  category?: BannedWordCategory;
  matchMode?: BannedWordMatchMode;
  isActive?: boolean;
  q?: string;
  page?: number;
  size?: number;
}

export const bannedWordsApi = {
  list: (params?: BannedWordListParams) =>
    apiClient.get<ApiResponse<BannedWordPage>>('/api/admin/content/banned-words', { params }),

  getById: (id: number) =>
    apiClient.get<ApiResponse<BannedWordResponse>>(`/api/admin/content/banned-words/${id}`),

  create: (body: BannedWordCreateRequest) =>
    apiClient.post<ApiResponse<BannedWordResponse>>('/api/admin/content/banned-words', body),

  update: (id: number, body: BannedWordUpdateRequest) =>
    apiClient.put<ApiResponse<BannedWordResponse>>(`/api/admin/content/banned-words/${id}`, body),

  delete: (id: number) =>
    apiClient.delete<ApiResponse<null>>(`/api/admin/content/banned-words/${id}`),
};
