'use client';

// Redis 캐시 건강도 — Phase 3B §12.
// 메모리 사용량과 캐시 패턴별 Hit Ratio / 키 수 표시.

import PageHeader from '@/components/layout/PageHeader';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import KpiCard from '@/components/common/KpiCard';
import { useRedisHealth } from '@/hooks/useMonitoring';
import { Database, Gauge, RefreshCcw } from 'lucide-react';

export default function RedisHealthPage() {
  const { data, isLoading, error } = useRedisHealth();

  return (
    <div>
      <PageHeader
        title="Redis 캐시 건강도"
        description="캐시 패턴별 Hit Ratio 와 Redis 메모리 사용량 모니터링."
      />

      <div className="mb-4 flex items-center">
        <Badge variant="outline">30초 자동 갱신</Badge>
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <KpiCard
          title="사용 메모리"
          value={`${Math.round(data?.memoryUsedMb ?? 0)} MB`}
          description="Redis 현재 사용"
          icon={Database}
        />
        <KpiCard
          title="피크 메모리"
          value={`${Math.round(data?.memoryPeakMb ?? 0)} MB`}
          description="누적 최대치"
          icon={Gauge}
        />
        <KpiCard
          title="stale-fallback Hit"
          value={(data?.staleFallbackHits ?? 0).toLocaleString()}
          description="장애 시 Fallback 사용"
          icon={RefreshCcw}
        />
      </div>

      <Card className="mt-6">
        <CardHeader>
          <CardTitle>캐시 패턴별 상태</CardTitle>
        </CardHeader>
        <CardContent>
          {isLoading && <p className="text-sm text-muted-foreground">불러오는 중…</p>}
          {error && <p className="text-sm text-destructive">데이터를 불러오지 못했습니다.</p>}
          {!isLoading && !error && (
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b text-left">
                    <th className="py-2">패턴</th>
                    <th className="py-2 text-right">Hit Ratio</th>
                    <th className="py-2 text-right">키 수</th>
                  </tr>
                </thead>
                <tbody>
                  {data?.patterns?.length ? (
                    data.patterns.map((p) => (
                      <tr key={p.pattern} className="border-b last:border-0">
                        <td className="py-2 font-mono-data">{p.pattern}</td>
                        <td className="py-2 text-right">{(p.hitRatio * 100).toFixed(1)}%</td>
                        <td className="py-2 text-right">{p.keys.toLocaleString()}</td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={3} className="py-4 text-center text-muted-foreground">
                        패턴 정보가 없습니다.
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
