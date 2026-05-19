import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { reportsApi } from '@/lib/api/reports';
import type { ReportSearchParams } from '@/types/report';
import toast from 'react-hot-toast';

export function useReportList(params: ReportSearchParams) {
  return useQuery({
    queryKey: ['reports', params],
    queryFn: () => reportsApi.getList(params).then((res) => res.data.data),
  });
}

export function useReportDetail(id: number) {
  return useQuery({
    queryKey: ['reports', id],
    queryFn: () => reportsApi.getDetail(id).then((res) => res.data.data),
    enabled: !!id,
  });
}

/**
 * 신고 처리 (resolve / dismiss) — 관리자 API v2.1 §5.4 / §5.5 (Phase A-3 BE).
 * - dismiss: { reason }
 * - resolve: { action, note }  ← action: WARNING / SUSPEND_7D / SUSPEND_PERMANENT
 */
export function useProcessReport() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({
      id,
      result,
      adminMemo,
      sanctionType,
    }: {
      id: number;
      result: 'RESOLVED' | 'DISMISSED';
      adminMemo: string;
      sanctionType?: 'NONE' | 'WARNING' | 'SUSPEND_7D' | 'SUSPEND_PERMANENT';
    }) => {
      if (result === 'DISMISSED') {
        return reportsApi.dismiss(id, { reason: adminMemo });
      }
      // sanctionType=NONE → 기본 경고만 (BE: WARNING)
      const action: 'WARNING' | 'SUSPEND_7D' | 'SUSPEND_PERMANENT' =
        sanctionType === undefined || sanctionType === 'NONE' ? 'WARNING' : sanctionType;
      return reportsApi.resolve(id, { action, note: adminMemo });
    },
    onSuccess: (_, variables) => {
      queryClient.invalidateQueries({ queryKey: ['reports'] });
      toast.success(
        variables.result === 'RESOLVED'
          ? '신고가 처리되었습니다.'
          : '신고가 기각되었습니다.',
      );
    },
  });
}
