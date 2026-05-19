import { Info } from 'lucide-react';
import { cn } from '@/lib/utils';

interface MockPageNoticeProps {
  /** 메인 안내 메시지 오버라이드 (기본: "Mock 데이터 — 실제 API 연결 예정") */
  message?: string;
  /** 보조 설명 (예: 연결 예정 API 엔드포인트, 준비 중인 도메인) */
  description?: string;
  className?: string;
}

/**
 * Ember Signal MockPageNotice — Phase 2-C (2026-04-21)
 * - 기존 amber 팔레트 하드코딩 제거, 세만틱 토큰(primary/muted/border/foreground) 기반으로 재작성 [Phase 1 Appendix A].
 * - 다크모드 자동 대응. border-dashed 로 "임시 상태" 시각 신호.
 * - 기존 props `message` 하위 호환 유지, 보조 설명용 `description` 추가.
 * 사용 예:
 *   <MockPageNotice description="고객 문의 도메인 백엔드 API 준비 중입니다." />
 */
export default function MockPageNotice({
  message = 'Mock 데이터 — 실제 API 연결 예정',
  description,
  className,
}: MockPageNoticeProps) {
  return (
    <div
      role="note"
      aria-label="Mock 데이터 안내"
      className={cn(
        'mb-4 flex items-start gap-2 rounded-lg border border-dashed border-primary/30 bg-muted/60 px-4 py-3 text-sm text-muted-foreground',
        className,
      )}
    >
      <Info className="mt-0.5 h-4 w-4 flex-shrink-0 text-primary" aria-hidden="true" />
      <div className="flex-1">
        <p className="font-medium text-foreground">{message}</p>
        {description && <p className="mt-0.5 text-xs text-muted-foreground">{description}</p>}
      </div>
    </div>
  );
}
