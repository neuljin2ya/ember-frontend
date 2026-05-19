'use client';

// OutboxRelay 상태 상세 — Phase 3B §12.
// PENDING/FAILED 건수, p95 lag, FAILED 샘플 테이블 + 재시도 액션.

import PageHeader from '@/components/layout/PageHeader';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import KpiCard from '@/components/common/KpiCard';
import { useOutboxStatus, useRetryOutbox } from '@/hooks/useMonitoring';
import { useAuthStore } from '@/stores/authStore';
import { AlertTriangle, Clock, ListChecks } from 'lucide-react';
import toast from 'react-hot-toast';

export default function OutboxStatusPage() {
  const { hasPermission } = useAuthStore();
  const { data, isLoading, error } = useOutboxStatus();
  const retryOutbox = useRetryOutbox();

  const handleRetryAll = () => {
    retryOutbox.mutate(undefined, {
      onSuccess: (res) => toast.success(`재시도 요청 완료: ${res.data.data?.retriedCount ?? 0}건`),
      onError: () => toast.error('재시도 요청 실패'),
    });
  };

  const handleRetryOne = (eventId: number) => {
    retryOutbox.mutate([eventId], {
      onSuccess: () => toast.success(`#${eventId} 재시도 요청 완료`),
      onError: () => toast.error('재시도 실패'),
    });
  };

  return (
    <div>
      <PageHeader
        title="OutboxRelay 상태"
        description="Outbox 이벤트 PENDING/FAILED 추적 및 장애 이벤트 재시도."
      />

      <div className="mb-6 flex items-center gap-3">
        <Badge variant="outline">30초 자동 갱신</Badge>
        {hasPermission('SUPER_ADMIN') && (
          <Button
            size="sm"
            variant="outline"
            onClick={handleRetryAll}
            disabled={retryOutbox.isPending}
          >
            FAILED 전체 재시도
          </Button>
        )}
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <KpiCard
          title="PENDING"
          value={(data?.pending ?? 0).toLocaleString()}
          description="릴레이 대기 중"
          icon={ListChecks}
        />
        <KpiCard
          title="FAILED"
          value={(data?.failed ?? 0).toLocaleString()}
          description="재시도 대상"
          icon={AlertTriangle}
          valueClassName="text-destructive"
        />
        <KpiCard
          title="Lag p95"
          value={`${Math.round(data?.lagP95Ms ?? 0)} ms`}
          description="릴레이 지연 시간"
          icon={Clock}
        />
      </div>

      <Card className="mt-6">
        <CardHeader>
          <CardTitle>FAILED 이벤트 샘플 (최대 20건)</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading && <p className="text-sm text-muted-foreground">불러오는 중…</p>}
          {error && <p className="text-sm text-destructive">데이터를 불러오지 못했습니다.</p>}
          {!isLoading && !error && (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b text-left">
                    <th className="py-2">ID</th>
                    <th className="py-2">Aggregate</th>
                    <th className="py-2">Event</th>
                    <th className="py-2">생성일</th>
                    <th className="py-2">Last Error</th>
                    <th className="py-2" />
                  </tr>
                </thead>
                <tbody>
                  {data?.failedSample?.length ? (
                    data.failedSample.map((e) => (
                      <tr key={e.id} className="border-b last:border-0">
                        <td className="py-2 font-mono-data">#{e.id}</td>
                        <td className="py-2">{e.aggregateType}</td>
                        <td className="py-2">{e.eventType}</td>
                        <td className="py-2 text-xs text-muted-foreground">{e.createdAt ?? '-'}</td>
                        <td className="py-2 text-xs text-destructive">{e.lastError || '-'}</td>
                        <td className="py-2 text-right">
                          {hasPermission('SUPER_ADMIN') && (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleRetryOne(e.id)}
                              disabled={retryOutbox.isPending}
                            >
                              재시도
                            </Button>
                          )}
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={6} className="py-4 text-center text-muted-foreground">
                        FAILED 이벤트가 없습니다.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
