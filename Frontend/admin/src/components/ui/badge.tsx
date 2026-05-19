import * as React from 'react';
import { cva, type VariantProps } from 'class-variance-authority';
import { cn } from '@/lib/utils';

/**
 * Ember Signal Badge — v1.0.1 (2026-04-21)
 * - 세만틱 토큰 기반 (Tailwind 팔레트 하드코딩 금지, DESIGN.md §11)
 * - shape: default(radius-sm) / pill(radius-full) 이원화 (DESIGN.md §7.2)
 * - tone: outline / soft / solid / destructive 4단계 계층 (DESIGN.md §11)
 */
const badgeVariants = cva(
  'inline-flex items-center border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2',
  {
    variants: {
      variant: {
        // solid (강조)
        default: 'border-transparent bg-primary text-primary-foreground hover:bg-primary/80',
        secondary: 'border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/80',
        destructive: 'border-transparent bg-destructive text-destructive-foreground hover:bg-destructive/80',
        // outline (최저 강조)
        outline: 'text-foreground',
        // soft (세만틱 토큰 + 알파, 다크모드 자동 대응)
        success: 'border-transparent bg-success/10 text-success',
        warning: 'border-transparent bg-warning/15 text-warning',
        info: 'border-transparent bg-info/10 text-info',
        'soft-destructive': 'border-transparent bg-destructive/10 text-destructive',
        'soft-primary': 'border-transparent bg-primary/10 text-primary',
        'soft-muted': 'border-transparent bg-muted text-muted-foreground',
      },
      shape: {
        default: 'rounded-sm',
        pill: 'rounded-full',
      },
    },
    defaultVariants: {
      variant: 'default',
      shape: 'default',
    },
  },
);

export interface BadgeProps extends React.HTMLAttributes<HTMLDivElement>, VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, shape, ...props }: BadgeProps) {
  return <div className={cn(badgeVariants({ variant, shape }), className)} {...props} />;
}

export { Badge, badgeVariants };
