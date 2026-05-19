'use client';

import { useState } from 'react';
import { Calendar } from 'lucide-react';
import dayjs from 'dayjs';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { cn } from '@/lib/utils';

export interface DateRange {
  startDate: string; // yyyy-MM-dd
  endDate: string;
}

interface Props {
  value: DateRange;
  onChange: (range: DateRange) => void;
  /** 프리셋 숨김 */
  hidePresets?: boolean;
  className?: string;
}

type PresetKey = '7d' | '30d' | '90d' | '12w' | '180d';

const PRESETS: { key: PresetKey; label: string; days: number }[] = [
  { key: '7d', label: '최근 7일', days: 6 },
  { key: '30d', label: '최근 30일', days: 29 },
  { key: '90d', label: '최근 90일', days: 89 },
  { key: '12w', label: '최근 12주', days: 83 },
  { key: '180d', label: '최근 180일', days: 179 },
];

/**
 * 분석 API 공통 DateRange 선택기.
 *   - yyyy-MM-dd 형식 유지 (백엔드 @DateTimeFormat ISO.DATE)
 *   - 프리셋 + 직접 입력 혼합
 */
export default function AnalyticsDateRangePicker({ value, onChange, hidePresets, className }: Props) {
  const [activePreset, setActivePreset] = useState<PresetKey | null>(null);

  const applyPreset = (key: PresetKey) => {
    const preset = PRESETS.find((p) => p.key === key);
    if (!preset) return;
    const end = dayjs();
    const start = end.subtract(preset.days, 'day');
    setActivePreset(key);
    onChange({
      startDate: start.format('YYYY-MM-DD'),
      endDate: end.format('YYYY-MM-DD'),
    });
  };

  const handleManual = (field: 'startDate' | 'endDate', v: string) => {
    setActivePreset(null);
    onChange({ ...value, [field]: v });
  };

  return (
    <div className={cn('flex flex-wrap items-center gap-2', className)}>
      {!hidePresets && (
        <div className="flex flex-wrap items-center gap-1">
          {PRESETS.map((p) => (
            <Button
              key={p.key}
              size="sm"
              variant={activePreset === p.key ? 'default' : 'outline'}
              onClick={() => applyPreset(p.key)}
            >
              {p.label}
            </Button>
          ))}
        </div>
      )}

      <div className="flex items-center gap-2">
        <Calendar className="h-4 w-4 text-muted-foreground" />
        <Input
          type="date"
          value={value.startDate}
          onChange={(e) => handleManual('startDate', e.target.value)}
          className="h-9 w-[150px]"
          max={value.endDate}
        />
        <span className="text-muted-foreground">~</span>
        <Input
          type="date"
          value={value.endDate}
          onChange={(e) => handleManual('endDate', e.target.value)}
          className="h-9 w-[150px]"
          min={value.startDate}
          max={dayjs().format('YYYY-MM-DD')}
        />
      </div>
    </div>
  );
}

/** 날짜 디폴트 유틸 — 최근 N일 (endDate=오늘). */
export function defaultRange(daysAgo: number): DateRange {
  const end = dayjs();
  const start = end.subtract(daysAgo, 'day');
  return {
    startDate: start.format('YYYY-MM-DD'),
    endDate: end.format('YYYY-MM-DD'),
  };
}
