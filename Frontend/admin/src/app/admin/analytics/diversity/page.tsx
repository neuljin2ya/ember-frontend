'use client';

import { useState } from 'react';
import PageHeader from '@/components/layout/PageHeader';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import KpiCard from '@/components/common/KpiCard';
import {
  Sparkles,
  Layers,
  Activity,
  Scale,
  RefreshCw,
} from 'lucide-react';
// recharts 차트 미사용 (백엔드에 daily 시계열 없음)
import { useMatchingDiversity } from '@/hooks/useAnalytics';
import {
  AnalyticsLoading,
  AnalyticsError,
  AnalyticsEmpty,
  DegradedBadge,
} from '@/components/common/AnalyticsStatus';
import { periodToDateRange, type AnalyticsPeriod } from '@/lib/utils/analyticsRange';
import type { MatchingDiversityResponse } from '@/types/analytics';

export default function DiversityAnalyticsPage() {
  const [period, setPeriod] = useState<AnalyticsPeriod>('30d');

  const { startDate, endDate } = periodToDateRange(period);
  const query = useMatchingDiversity({ startDate, endDate });
  const data: MatchingDiversityResponse | undefined = query.data;

  // 백엔드 응답에 daily 시계열 없음 — 단일 집계값만 존재
  const hasData = !!data;

  return (
    <div>
      <PageHeader
        title="다양성 지표"
        description="매칭 추천 다양성 (Shannon 엔트로피) + 재추천율 분석"
        actions={
          <>
            <div className="flex gap-1 rounded-md border border-border p-1">
              {(['7d', '30d', '90d'] as AnalyticsPeriod[]).map((p) => (
                <Button
                  key={p}
                  size="sm"
                  variant={period === p ? 'default' : 'ghost'}
                  className="h-7 px-3 text-xs"
                  onClick={() => setPeriod(p)}
                >
                  {p === '7d' ? '7일' : p === '30d' ? '30일' : '90일'}
                </Button>
              ))}
            </div>
            <Button variant="outline" size="sm" onClick={() => query.refetch()} disabled={query.isFetching}>
              <RefreshCw className={query.isFetching ? 'mr-1.5 h-4 w-4 animate-spin' : 'mr-1.5 h-4 w-4'} />
              새로고침
            </Button>
          </>
        }
      />

      {data?.meta?.degraded && (
        <div className="mb-4">
          <DegradedBadge degraded={data.meta.degraded} reason={data.meta.algorithm} />
        </div>
      )}

      {query.isLoading && <AnalyticsLoading height={400} />}
      {query.isError && (
        <AnalyticsError
          height={400}
          message={(query.error as Error)?.message}
          onRetry={() => query.refetch()}
        />
      )}

      {data && (
        <>
          <div className="mb-6 grid gap-4 md:grid-cols-4">
            <KpiCard
              title="Shannon 엔트로피"
              value={(data.shannonEntropy ?? 0).toFixed(2)}
              description="매칭 다양성 점수"
              icon={Sparkles}
              valueClassName="text-primary"
            />
            <KpiCard
              title="재추천율"
              value={`${((data.rerecommendationRate ?? 0) * 100).toFixed(1)}%`}
              description={`재추천 ${(data.rerecommendationCount ?? 0).toLocaleString()}건`}
              icon={Layers}
            />
            <KpiCard
              title="총 추천 수"
              value={(data.totalRecs ?? 0).toLocaleString()}
              description="기간 내 총 추천 횟수"
              icon={Activity}
              valueClassName="text-[#10b981]"
            />
            <KpiCard
              title="고유 후보 수"
              value={(data.uniqueCandidates ?? 0).toLocaleString()}
              description="고유 추천 후보 사용자 수"
              icon={Scale}
            />
          </div>

          <Card className="mb-6">
            <CardHeader>
              <CardTitle className="text-sm">다양성 지표 요약</CardTitle>
              <p className="mt-0.5 text-xs text-muted-foreground">
                Shannon 엔트로피가 높을수록 추천이 다양함. 재추천율이 낮을수록 새로운 후보를 추천.
              </p>
            </CardHeader>
            <CardContent>
              <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
                <div className="rounded-md border border-border p-4 text-center">
                  <p className="text-xs text-muted-foreground">총 추천</p>
                  <p className="mt-1 text-2xl font-bold tabular-nums">{(data.totalRecs ?? 0).toLocaleString()}</p>
                </div>
                <div className="rounded-md border border-border p-4 text-center">
                  <p className="text-xs text-muted-foreground">고유 후보</p>
                  <p className="mt-1 text-2xl font-bold tabular-nums">{(data.uniqueCandidates ?? 0).toLocaleString()}</p>
                </div>
                <div className="rounded-md border border-border p-4 text-center">
                  <p className="text-xs text-muted-foreground">Shannon H</p>
                  <p className="mt-1 text-2xl font-bold tabular-nums">{(data.shannonEntropy ?? 0).toFixed(3)}</p>
                </div>
                <div className="rounded-md border border-border p-4 text-center">
                  <p className="text-xs text-muted-foreground">재추천 건수</p>
                  <p className="mt-1 text-2xl font-bold tabular-nums">{(data.rerecommendationCount ?? 0).toLocaleString()}</p>
                </div>
              </div>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}
