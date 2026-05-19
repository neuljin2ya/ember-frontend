import apiClient from './client';
import type { ApiResponse } from './types';
import type { ExchangeDiaryGuideStep, Banner } from '@/types/content';

// ─── 예제 일기(Example Diary) — 백엔드 §6.6 (AdminExampleDiaryController) ──────
// BE 응답 shape: AdminExampleDiaryResponse (createdByName 포함)

export type ExampleDiaryCategoryBe =
  | 'GRATITUDE'
  | 'GROWTH'
  | 'DAILY'
  | 'EMOTION'
  | 'RELATIONSHIP'
  | 'SEASONAL';

export type ExampleDiaryDisplayTarget = 'ONBOARDING' | 'HELP' | 'FAQ';

export interface ExampleDiaryResponse {
  id: number;
  title: string;
  content: string;
  category: ExampleDiaryCategoryBe;
  displayTarget: ExampleDiaryDisplayTarget;
  displayOrder: number;
  isActive: boolean;
  createdByName: string | null;
  createdAt: string;
}

export interface ExampleDiaryCreateRequest {
  title: string;
  content: string;
  category: ExampleDiaryCategoryBe;
  displayTarget: ExampleDiaryDisplayTarget;
  displayOrder: number;
  isActive?: boolean;
}

export type ExampleDiaryUpdateRequest = Partial<ExampleDiaryCreateRequest>;

export const exampleDiariesApi = {
  getList: () =>
    apiClient.get<ApiResponse<ExampleDiaryResponse[]>>('/api/admin/example-diaries'),

  create: (data: ExampleDiaryCreateRequest) =>
    apiClient.post<ApiResponse<ExampleDiaryResponse>>('/api/admin/example-diaries', data),

  update: (id: number, data: ExampleDiaryUpdateRequest) =>
    apiClient.put<ApiResponse<ExampleDiaryResponse>>(`/api/admin/example-diaries/${id}`, data),

  delete: (id: number) =>
    apiClient.delete<ApiResponse<null>>(`/api/admin/example-diaries/${id}`),
};

export const exchangeDiaryGuideApi = {
  // 교환일기 흐름 가이드 조회
  getGuide: () =>
    apiClient.get<ApiResponse<ExchangeDiaryGuideStep[]>>('/api/admin/exchange-diary-guide'),

  // 교환일기 흐름 가이드 단계 교체
  updateSteps: (steps: ExchangeDiaryGuideStep[]) =>
    apiClient.put<ApiResponse<null>>('/api/admin/exchange-diary-guide/steps', { steps }),
};

export const bannersApi = {
  // 배너 목록 조회
  getList: () =>
    apiClient.get<ApiResponse<Banner[]>>('/api/admin/banners'),

  // 배너 생성
  create: (data: Omit<Banner, 'id' | 'createdAt'>) =>
    apiClient.post<ApiResponse<Banner>>('/api/admin/banners', data),

  // 배너 수정
  update: (id: number, data: Partial<Banner>) =>
    apiClient.put<ApiResponse<Banner>>(`/api/admin/banners/${id}`, data),
};
