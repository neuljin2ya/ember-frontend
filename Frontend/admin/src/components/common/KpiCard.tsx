import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { cn } from '@/lib/utils';
import { TrendingDown, TrendingUp } from 'lucide-react';

interface KpiTrend {
  value: number;
  isPositive: boolean;
  // 기본값 "전일 대비"
  label?: string;
}

interface KpiCardProps {
  title: string;
  value: number | string;
  description?: string;
  icon?: React.ComponentType<{ className?: string }>;
  trend?: KpiTrend;
  // 값 색상 오버라이드 (세만틱 토큰 권장: text-primary, text-success, text-info 등)
  valueClassName?: string;
  className?: string;
}

/**
 * Ember Signal KpiCard — Phase 2-C (2026-04-21)
 * - dashboard/page.tsx 지역 KPICard를 공통 승격. Phase 1-C 스타일 보존:
 *   · .kpi-number (Instrument Serif, CSS variable)
 *   · .font-mono-data tabular-nums (트렌드 숫자 정렬)
 *   · duration-short + hover:bg-card/80 마이크로 인터랙션
 *   · text-success / text-destructive 세만틱 트렌드 색
 * - valueClassName 으로 AI 성능 지표 등 의미 색 주입 가능 (text-primary, text-success)
 */
export default function KpiCard({
  title,
  value,
  description,
  icon: Icon,
  trend,
  valueClassName,
  className,
}: KpiCardProps) {
  return (
    <Card
      className={cn(
        'overflow-hidden transition-colors duration-short hover:bg-card/80',
        className,
      )}
    >
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
          {title}
        </CardTitle>
        {Icon && <Icon className="h-4 w-4 text-muted-foreground" />}
      </CardHeader>
      <CardContent>
        <div className={cn('kpi-number text-4xl leading-none text-foreground', valueClassName)}>
          {typeof value === 'number' ? value.toLocaleString() : value}
        </div>
        {description && (
          <p className="mt-2 text-xs text-muted-foreground">{description}</p>
        )}
        {trend && (
          <div
            className={cn(
              'mt-2 flex items-center gap-1 text-xs',
              trend.isPositive ? 'text-success' : 'text-destructive',
            )}
          >
            {trend.isPositive ? (
              <TrendingUp className="h-3 w-3" />
            ) : (
              <TrendingDown className="h-3 w-3" />
            )}
            <span className="font-mono-data">
              {trend.isPositive ? '+' : '−'}
              {trend.value}% {trend.label ?? '전일 대비'}
            </span>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
