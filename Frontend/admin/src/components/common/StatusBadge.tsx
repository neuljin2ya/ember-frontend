import { Badge } from '@/components/ui/badge';
import { USER_STATUS_LABELS, USER_STATUS_COLORS, SOFT } from '@/lib/constants';
import type { UserStatus } from '@/types/user';

interface StatusBadgeProps {
  status: UserStatus;
}

/**
 * Ember Signal StatusBadge — v1.0.1 (Phase 2-A, 2026-04-21)
 * - Badge 기본 variant(default) 위에 className으로 SOFT soft variant를 주입
 * - tailwind-merge가 default의 bg/text 유틸을 soft 값으로 교체
 * - fallback은 SOFT.muted (세만틱 토큰, 다크모드 자동 대응)
 */
export default function StatusBadge({ status }: StatusBadgeProps) {
  return (
    <Badge className={USER_STATUS_COLORS[status] || SOFT.muted}>
      {USER_STATUS_LABELS[status] || status}
    </Badge>
  );
}
