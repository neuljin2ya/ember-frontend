'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import apiClient from '@/lib/api/client';
import PageHeader from '@/components/layout/PageHeader';
import { Card, CardContent } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { formatDateTime } from '@/lib/utils/format';
import { FileText, Plus, Power, Play, Clock, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';

interface AutoReportSchedule {
  id: number;
  name: string;
  description: string | null;
  reportType: 'USER_ANALYTICS' | 'MATCHING_PERFORMANCE' | 'OPERATIONS_SUMMARY' | 'DIARY_STATISTICS' | 'RETENTION_ANALYSIS';
  cronExpression: string;
  enabled: boolean;
  executionCount: number;
  lastExecutedAt: string | null;
  createdAt: string;
}

const TYPE_LABELS: Record<string, string> = {
  USER_ANALYTICS: '사용자 분석',
  MATCHING_PERFORMANCE: '매칭 성과',
  OPERATIONS_SUMMARY: '운영 현황',
  DIARY_STATISTICS: '일기 통계',
  RETENTION_ANALYSIS: '리텐션 분석',
};

const TYPE_COLORS: Record<string, string> = {
  USER_ANALYTICS: 'bg-blue-100 text-blue-800',
  MATCHING_PERFORMANCE: 'bg-pink-100 text-pink-800',
  OPERATIONS_SUMMARY: 'bg-green-100 text-green-800',
  DIARY_STATISTICS: 'bg-amber-100 text-amber-800',
  RETENTION_ANALYSIS: 'bg-purple-100 text-purple-800',
};

export default function AutoReportsPage() {
  const queryClient = useQueryClient();
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ name: '', description: '', reportType: 'USER_ANALYTICS' as const, cronExpression: '0 0 9 * * MON' });

  const { data: schedules = [], isLoading } = useQuery<AutoReportSchedule[]>({
    queryKey: ['auto-report-schedules'],
    queryFn: () => apiClient.get('/api/admin/auto-report-schedules').then(r => r.data.data),
  });

  const toggleMutation = useMutation({
    mutationFn: (id: number) =>
      apiClient.patch(`/api/admin/auto-report-schedules/${id}/toggle`).then(r => r.data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['auto-report-schedules'] });
      toast.success('스케줄 상태가 변경되었습니다.');
    },
    onError: () => toast.error('상태 변경에 실패했습니다.'),
  });

  const runMutation = useMutation({
    mutationFn: (id: number) =>
      apiClient.post(`/api/admin/auto-report-schedules/${id}/run`).then(r => r.data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['auto-report-schedules'] });
      toast.success('리포트를 수동 실행합니다.');
    },
    onError: () => toast.error('수동 실행에 실패했습니다.'),
  });

  const createMutation = useMutation({
    mutationFn: (data: typeof form) =>
      apiClient.post('/api/admin/auto-report-schedules', data).then(r => r.data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['auto-report-schedules'] });
      toast.success('스케줄이 생성되었습니다.');
      setShowForm(false);
      setForm({ name: '', description: '', reportType: 'USER_ANALYTICS', cronExpression: '0 0 9 * * MON' });
    },
    onError: () => toast.error('스케줄 생성에 실패했습니다.'),
  });

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  const enabledCount = schedules.filter(s => s.enabled).length;

  return (
    <div>
      <PageHeader
        title="자동 리포트 스케줄링"
        description="주기적으로 자동 생성되는 리포트 스케줄 관리"
        actions={
          <Button onClick={() => setShowForm(!showForm)}>
            <Plus className="mr-2 h-4 w-4" />
            스케줄 추가
          </Button>
        }
      />

      <div className="mb-6 grid gap-4 md:grid-cols-3">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <FileText className="h-5 w-5 text-blue-500" />
              <span className="text-sm text-muted-foreground">전체 스케줄</span>
            </div>
            <div className="mt-1 text-2xl font-bold">{schedules.length}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Power className="h-5 w-5 text-green-500" />
              <span className="text-sm text-muted-foreground">활성</span>
            </div>
            <div className="mt-1 text-2xl font-bold text-green-600">{enabledCount}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Clock className="h-5 w-5 text-purple-500" />
              <span className="text-sm text-muted-foreground">총 실행 횟수</span>
            </div>
            <div className="mt-1 text-2xl font-bold">{schedules.reduce((s, r) => s + r.executionCount, 0)}</div>
          </CardContent>
        </Card>
      </div>

      {showForm && (
        <Card className="mb-6">
          <CardContent className="p-4 space-y-4">
            <h3 className="font-semibold">새 스케줄 추가</h3>
            <div className="grid gap-4 md:grid-cols-2">
              <div>
                <Label>스케줄 이름</Label>
                <Input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="예: 주간 매칭 성과 리포트" />
              </div>
              <div>
                <Label>리포트 유형</Label>
                <select className="w-full rounded-md border px-3 py-2 text-sm" value={form.reportType} onChange={e => setForm({ ...form, reportType: e.target.value as typeof form.reportType })}>
                  <option value="USER_ANALYTICS">사용자 분석</option>
                  <option value="MATCHING_PERFORMANCE">매칭 성과</option>
                  <option value="OPERATIONS_SUMMARY">운영 현황</option>
                  <option value="DIARY_STATISTICS">일기 통계</option>
                  <option value="RETENTION_ANALYSIS">리텐션 분석</option>
                </select>
              </div>
              <div className="md:col-span-2">
                <Label>설명</Label>
                <Input value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} placeholder="스케줄 설명" />
              </div>
              <div className="md:col-span-2">
                <Label>Cron 표현식</Label>
                <Input value={form.cronExpression} onChange={e => setForm({ ...form, cronExpression: e.target.value })} placeholder="0 0 9 * * MON (매주 월요일 09:00)" />
                <p className="mt-1 text-xs text-muted-foreground">초 분 시 일 월 요일 (예: 0 0 9 * * MON = 매주 월 09:00, 0 0 0 1 * * = 매월 1일)</p>
              </div>
            </div>
            <div className="flex gap-2">
              <Button onClick={() => createMutation.mutate(form)} disabled={!form.name || createMutation.isPending}>
                {createMutation.isPending ? <Loader2 className="mr-2 h-4 w-4 animate-spin" /> : null}
                생성
              </Button>
              <Button variant="outline" onClick={() => setShowForm(false)}>취소</Button>
            </div>
          </CardContent>
        </Card>
      )}

      <div className="grid gap-4">
        {schedules.length === 0 ? (
          <Card>
            <CardContent className="p-8 text-center text-muted-foreground">
              등록된 자동 리포트 스케줄이 없습니다.
            </CardContent>
          </Card>
        ) : (
          schedules.map(schedule => (
            <Card key={schedule.id}>
              <CardContent className="p-4">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <h3 className="font-semibold">{schedule.name}</h3>
                      <Badge className={schedule.enabled ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}>
                        {schedule.enabled ? '활성' : '비활성'}
                      </Badge>
                      <Badge className={TYPE_COLORS[schedule.reportType]}>
                        {TYPE_LABELS[schedule.reportType]}
                      </Badge>
                    </div>
                    {schedule.description && <p className="mt-1 text-sm text-muted-foreground">{schedule.description}</p>}
                  </div>
                  <div className="flex gap-2">
                    <Button variant="outline" size="sm" onClick={() => runMutation.mutate(schedule.id)}>
                      <Play className="mr-1 h-3 w-3" />
                      실행
                    </Button>
                    <Button variant="ghost" size="sm" onClick={() => toggleMutation.mutate(schedule.id)}>
                      <Power className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
                <div className="mt-4 grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                  <div>
                    <span className="text-muted-foreground">스케줄</span>
                    <p className="font-medium flex items-center gap-1 mt-1">
                      <Clock className="h-3 w-3" />
                      {schedule.cronExpression}
                    </p>
                  </div>
                  <div>
                    <span className="text-muted-foreground">실행 횟수</span>
                    <p className="font-medium mt-1">{schedule.executionCount}회</p>
                  </div>
                  <div>
                    <span className="text-muted-foreground">마지막 실행</span>
                    <p className="font-medium mt-1">{schedule.lastExecutedAt ? formatDateTime(schedule.lastExecutedAt) : '-'}</p>
                  </div>
                  <div>
                    <span className="text-muted-foreground">생성일</span>
                    <p className="font-medium mt-1">{formatDateTime(schedule.createdAt)}</p>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))
        )}
      </div>
    </div>
  );
}
