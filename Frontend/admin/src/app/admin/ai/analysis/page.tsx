'use client';

// 분석 상태 분포 — Phase 3B §12.
// 일기/리포트 analysis_status 분포 + 장시간 처리 항목 목록.

import PageHeader from '@/components/layout/PageHeader';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import KpiCard from '@/components/common/KpiCard';
import { useAnalysisOverview } from '@/hooks/useMonitoring';
import { Activity, AlertCircle, CheckCircle2, XCircle } from 'lucide-react';

export default function AnalysisOverviewPage() {
  const { data, isLoading, error } = useAnalysisOverview();
  const diary = data?.diary ?? { processing: 0, done: 0, failed: 0, skipped: 0 };
  const report = data?.report ?? { processing: 0, done: 0, failed: 0, consentRequired: 0 };

  return (
    <div>
      <PageHeader
        title="분석 상태 분포"
        description="일기·리포트 analysis_status 실시간 분포 및 장시간 처리 감지."
      />

      <div className="mb-4 flex items-center">
        <Badge variant="outline">30초 자동 갱신</Badge>
      </div>

      {/* 일기 분석 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold">일기 분석</h2>
        <div className="grid gap-4 md:grid-cols-4">
          <KpiCard title="처리 중" value={diary.processing.toLocaleString()} description="PROCESSING" icon={Activity} />
          <KpiCard title="완료" value={diary.done.toLocaleString()} description="COMPLETED" icon={CheckCircle2} valueClassName="text-success" />
          <KpiCard title="실패" value={diary.failed.toLocaleString()} description="FAILED" icon={XCircle} valueClassName="text-destructive" />
          <KpiCard title="스킵" value={diary.skipped.toLocaleString()} description="SKIPPED (동의 미획득)" icon={AlertCircle} />
        </div>
      </section>

      {/* 리포트 분석 */}
      <section className="mb-8">
        <h2 className="mb-3 text-lg font-semibold">리포트 분석</h2>
        <div className="grid gap-4 md:grid-cols-4">
          <KpiCard title="처리 중" value={report.processing.toLocaleString()} description="PROCESSING" icon={Activity} />
          <KpiCard title="완료" value={report.done.toLocaleString()} description="COMPLETED" icon={CheckCircle2} valueClassName="text-success" />
          <KpiCard title="실패" value={report.failed.toLocaleString()} description="FAILED" icon={XCircle} valueClassName="text-destructive" />
          <KpiCard title="동의 필요" value={report.consentRequired.toLocaleString()} description="사용자 재동의 요청" icon={AlertCircle} />
        </div>
      </section>

      {/* 장시간 처리 */}
      <Card>
        <CardHeader>
          <CardTitle>장시간 처리 (15분 초과)</CardTitle>
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
                    <th className="py-2">Type</th>
                    <th className="py-2">시작 시각</th>
                    <th className="py-2 text-right">경과 시간</th>
                  </tr>
                </thead>
                <tbody>
                  {data?.longProcessing?.length ? (
                    data.longProcessing.map((item) => (
                      <tr key={`${item.type}-${item.id}`} className="border-b last:border-0">
                        <td className="py-2 font-mono-data">#{item.id}</td>
                        <td className="py-2">
                          <Badge variant="outline">{item.type}</Badge>
                        </td>
                        <td className="py-2 text-xs text-muted-foreground">{item.startedAt ?? '-'}</td>
                        <td className="py-2 text-right text-amber-600">
                          {item.elapsedMinutes}분
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={4} className="py-4 text-center text-muted-foreground">
                        장시간 처리 항목이 없습니다.
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
