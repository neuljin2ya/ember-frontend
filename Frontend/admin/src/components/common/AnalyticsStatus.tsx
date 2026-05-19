'use client';

import { AlertTriangle, Loader2, Database } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent } from '@/components/ui/card';
import { cn } from '@/lib/utils';

/** 공통 로딩 스켈레톤 (차트 영역 전용). */
export function AnalyticsLoading({ height = 300, label = '데이터를 불러오는 중입니다…' }: { height?: number; label?: string }) {
  return (
    <div
      className="flex flex-col items-center justify-center rounded-md border border-dashed border-border bg-card/40"
      style={{ minHeight: height }}
    >
      <Loader2 className="mb-2 h-6 w-6 animate-spin text-muted-foreground" />
      <p className="text-sm text-muted-foreground">{label}</p>
    </div>
  );
}

/** 데이터 없음 상태. */
export function AnalyticsEmpty({
  height = 300,
  title = '표시할 데이터가 없습니다',
  description,
}: {
  height?: number;
  title?: string;
  description?: string;
}) {
  return (
    <div
      className="flex flex-col items-center justify-center rounded-md border border-dashed border-border bg-card/40 px-6 py-8 text-center"
      style={{ minHeight: height }}
    >
      <Database className="mb-2 h-6 w-6 text-muted-foreground" />
      <p className="text-sm font-medium">{title}</p>
      {description && <p className="mt-1 text-xs text-muted-foreground">{description}</p>}
    </div>
  );
}

/** 에러 상태. */
export function AnalyticsError({
  height = 300,
  message,
  onRetry,
}: {
  height?: number;
  message?: string;
  onRetry?: () => void;
}) {
  return (
    <div
      className="flex flex-col items-center justify-center rounded-md border border-dashed border-destructive/40 bg-destructive/5 px-6 py-8 text-center"
      style={{ minHeight: height }}
    >
      <AlertTriangle className="mb-2 h-6 w-6 text-destructive" />
      <p className="text-sm font-medium text-destructive">분석 데이터 조회 실패</p>
      {message && <p className="mt-1 text-xs text-muted-foreground">{message}</p>}
      {onRetry && (
        <button
          onClick={onRetry}
          className="mt-3 text-xs font-medium text-primary underline underline-offset-2 hover:text-primary/80"
        >
          다시 시도
        </button>
      )}
    </div>
  );
}

/** degraded / Fallback 모드 표시 배지. (X-Degraded, dataSourceVersion 등 메타에서 트리거) */
export function DegradedBadge({
  degraded,
  reason,
  className,
}: {
  degraded: boolean;
  reason?: string;
  className?: string;
}) {
  if (!degraded) return null;
  return (
    <Badge variant="warning" className={cn('gap-1 font-medium', className)}>
      <AlertTriangle className="h-3 w-3" />
      Fallback 모드 {reason ? `· ${reason}` : ''}
    </Badge>
  );
}

/** 데이터 소스 메타 배지 (algorithm / dataSourceVersion / kMin 등을 한 줄로). */
export function AnalyticsMetaBar({
  algorithm,
  dataSourceVersion,
  kAnonymityMin,
  extraLeft,
  extraRight,
  className,
}: {
  algorithm?: string;
  dataSourceVersion?: string;
  kAnonymityMin?: number;
  extraLeft?: React.ReactNode;
  extraRight?: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn('flex flex-wrap items-center gap-2 text-xs text-muted-foreground', className)}>
      {extraLeft}
      {algorithm && <Badge variant="soft-primary">algorithm: {algorithm}</Badge>}
      {dataSourceVersion && <Badge variant="soft-muted">source: {dataSourceVersion}</Badge>}
      {typeof kAnonymityMin === 'number' && kAnonymityMin > 0 && (
        <Badge variant="soft-muted">k-anon ≥ {kAnonymityMin}</Badge>
      )}
      {extraRight}
    </div>
  );
}

/** 페이지 최상단 기간/필터 컨테이너. */
export function AnalyticsToolbar({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <Card className={cn('mb-4', className)}>
      <CardContent className="flex flex-wrap items-center gap-3 p-4">{children}</CardContent>
    </Card>
  );
}
