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
import { Bell, Plus, Power, Loader2 } from 'lucide-react';
import toast from 'react-hot-toast';

interface AutoNotificationRule {
  id: number;
  name: string;
  description: string | null;
  triggerCondition: string | null;
  notificationChannel: 'FCM' | 'IN_APP' | 'ALL';
  templateContent: string | null;
  enabled: boolean;
  lastTriggeredAt: string | null;
  createdAt: string;
}

const CHANNEL_LABELS: Record<string, string> = {
  FCM: 'FCM 푸시',
  IN_APP: '인앱 알림',
  ALL: '전체',
};

const CHANNEL_COLORS: Record<string, string> = {
  FCM: 'bg-blue-100 text-blue-800',
  IN_APP: 'bg-purple-100 text-purple-800',
  ALL: 'bg-indigo-100 text-indigo-800',
};

export default function AutoNotificationRulesPage() {
  const queryClient = useQueryClient();
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ name: '', description: '', triggerCondition: '', notificationChannel: 'ALL' as const, templateContent: '' });

  const { data: rules = [], isLoading } = useQuery<AutoNotificationRule[]>({
    queryKey: ['auto-notification-rules'],
    queryFn: () => apiClient.get('/api/admin/auto-notification-rules').then(r => r.data.data),
  });

  const toggleMutation = useMutation({
    mutationFn: (ruleId: number) =>
      apiClient.patch(`/api/admin/auto-notification-rules/${ruleId}/toggle`).then(r => r.data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['auto-notification-rules'] });
      toast.success('규칙 상태가 변경되었습니다.');
    },
    onError: () => toast.error('상태 변경에 실패했습니다.'),
  });

  const createMutation = useMutation({
    mutationFn: (data: typeof form) =>
      apiClient.post('/api/admin/auto-notification-rules', data).then(r => r.data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['auto-notification-rules'] });
      toast.success('규칙이 생성되었습니다.');
      setShowForm(false);
      setForm({ name: '', description: '', triggerCondition: '', notificationChannel: 'ALL', templateContent: '' });
    },
    onError: () => toast.error('규칙 생성에 실패했습니다.'),
  });

  if (isLoading) {
    return (
      <div className="flex h-64 items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin text-muted-foreground" />
      </div>
    );
  }

  const enabledCount = rules.filter(r => r.enabled).length;

  return (
    <div>
      <PageHeader
        title="자동 알림 규칙"
        description="조건에 따라 자동으로 알림을 발송하는 규칙 관리"
        actions={
          <Button onClick={() => setShowForm(!showForm)}>
            <Plus className="mr-2 h-4 w-4" />
            규칙 추가
          </Button>
        }
      />

      <div className="mb-6 grid gap-4 md:grid-cols-2">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Bell className="h-5 w-5 text-blue-500" />
              <span className="text-sm text-muted-foreground">전체 규칙</span>
            </div>
            <div className="mt-1 text-2xl font-bold">{rules.length}</div>
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
      </div>

      {showForm && (
        <Card className="mb-6">
          <CardContent className="p-4 space-y-4">
            <h3 className="font-semibold">새 규칙 추가</h3>
            <div className="grid gap-4 md:grid-cols-2">
              <div>
                <Label>규칙 이름</Label>
                <Input value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="예: 매칭 성사 시 양측 알림" />
              </div>
              <div>
                <Label>알림 채널</Label>
                <select className="w-full rounded-md border px-3 py-2 text-sm" value={form.notificationChannel} onChange={e => setForm({ ...form, notificationChannel: e.target.value as typeof form.notificationChannel })}>
                  <option value="FCM">FCM 푸시</option>
                  <option value="IN_APP">인앱 알림</option>
                  <option value="ALL">전체</option>
                </select>
              </div>
              <div className="md:col-span-2">
                <Label>설명</Label>
                <Input value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} placeholder="규칙 설명" />
              </div>
              <div className="md:col-span-2">
                <Label>트리거 조건</Label>
                <Input value={form.triggerCondition} onChange={e => setForm({ ...form, triggerCondition: e.target.value })} placeholder="예: MATCHING_ACCEPTED, EXCHANGE_COMPLETED" />
              </div>
              <div className="md:col-span-2">
                <Label>알림 템플릿</Label>
                <Input value={form.templateContent} onChange={e => setForm({ ...form, templateContent: e.target.value })} placeholder="예: {nickname}님과 매칭이 성사되었어요!" />
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
        {rules.length === 0 ? (
          <Card>
            <CardContent className="p-8 text-center text-muted-foreground">
              등록된 자동 알림 규칙이 없습니다.
            </CardContent>
          </Card>
        ) : (
          rules.map(rule => (
            <Card key={rule.id}>
              <CardContent className="p-4">
                <div className="flex items-start justify-between">
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <h3 className="font-semibold">{rule.name}</h3>
                      <Badge className={rule.enabled ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}>
                        {rule.enabled ? '활성' : '비활성'}
                      </Badge>
                      <Badge className={CHANNEL_COLORS[rule.notificationChannel]}>
                        {CHANNEL_LABELS[rule.notificationChannel]}
                      </Badge>
                    </div>
                    {rule.description && <p className="mt-1 text-sm text-muted-foreground">{rule.description}</p>}
                  </div>
                  <Button variant="ghost" size="sm" onClick={() => toggleMutation.mutate(rule.id)}>
                    <Power className="h-4 w-4" />
                  </Button>
                </div>
                <div className="mt-4 grid grid-cols-3 gap-4 text-sm">
                  <div>
                    <span className="text-muted-foreground">트리거 조건</span>
                    <p className="font-medium mt-1">{rule.triggerCondition || '-'}</p>
                  </div>
                  <div>
                    <span className="text-muted-foreground">마지막 발송</span>
                    <p className="font-medium mt-1">{rule.lastTriggeredAt ? formatDateTime(rule.lastTriggeredAt) : '-'}</p>
                  </div>
                  <div>
                    <span className="text-muted-foreground">생성일</span>
                    <p className="font-medium mt-1">{formatDateTime(rule.createdAt)}</p>
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
