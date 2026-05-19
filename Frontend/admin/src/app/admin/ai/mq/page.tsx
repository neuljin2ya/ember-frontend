'use client';

// MQ/DLQ 모니터링 상세 — Phase 3B §12.
// 5개 큐의 pending/consumers/dlqSize 를 표로 표시하며 30초 auto-refresh.

import PageHeader from '@/components/layout/PageHeader';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { useMqStatus, useReprocessDlq } from '@/hooks/useMonitoring';
import { useAuthStore } from '@/stores/authStore';
import toast from 'react-hot-toast';

export default function MqStatusPage() {
  const { hasPermission } = useAuthStore();
  const { data, isLoading, error } = useMqStatus();
  const reprocessDlq = useReprocessDlq();

  const handleReprocess = (queueName: string) => {
    const dlqName = queueName.endsWith('.dlq') ? queueName : `${queueName}.dlq`;
    reprocessDlq.mutate(dlqName, {
      onSuccess: (res) => {
        const processed = res.data.data?.processedCount ?? 0;
        toast.success(`${dlqName} 재처리: ${processed}건`);
      },
      onError: () => toast.error('DLQ 재처리 실패'),
    });
  };

  return (
    <div>
      <PageHeader
        title="MQ / DLQ 모니터링"
        description="RabbitMQ 큐별 대기 메시지, 컨슈머 수, DLQ 누적을 30초마다 갱신합니다."
      />

      <Card>
        <CardHeader className="flex flex-row items-center justify-between">
          <CardTitle>큐 상태</CardTitle>
          <Badge variant="outline">30초 자동 갱신</Badge>
        </CardHeader>
        <CardContent>
          {isLoading && <p className="text-sm text-muted-foreground">불러오는 중…</p>}
          {error && <p className="text-sm text-destructive">큐 상태를 불러오지 못했습니다.</p>}
          {!isLoading && !error && (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b text-left">
                    <th className="py-2">큐 이름</th>
                    <th className="py-2 text-right">Pending</th>
                    <th className="py-2 text-right">Consumers</th>
                    <th className="py-2 text-right">DLQ</th>
                    <th className="py-2" />
                  </tr>
                </thead>
                <tbody>
                  {data?.queues?.length ? (
                    data.queues.map((q) => (
                      <tr key={q.name} className="border-b last:border-0">
                        <td className="py-2 font-mono-data">{q.name}</td>
                        <td className="py-2 text-right">{q.pending.toLocaleString()}</td>
                        <td className="py-2 text-right">{q.consumers}</td>
                        <td
                          className={`py-2 text-right font-semibold ${
                            q.dlqSize > 0 ? 'text-destructive' : ''
                          }`}
                        >
                          {q.dlqSize.toLocaleString()}
                        </td>
                        <td className="py-2 text-right">
                          {hasPermission('SUPER_ADMIN') && q.dlqSize > 0 && (
                            <Button
                              size="sm"
                              variant="outline"
                              onClick={() => handleReprocess(q.name)}
                              disabled={reprocessDlq.isPending}
                            >
                              재처리
                            </Button>
                          )}
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={5} className="py-4 text-center text-muted-foreground">
                        표시할 큐가 없습니다.
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
