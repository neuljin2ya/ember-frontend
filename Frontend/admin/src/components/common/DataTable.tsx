import * as React from 'react';
import { Card, CardContent } from '@/components/ui/card';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { cn } from '@/lib/utils';

/**
 * Ember Signal DataTable — Phase 2-B (2026-04-21)
 * - 5+ 페이지에서 반복되던 `<table className="w-full"> + thead/tbody` 패턴을 단일 선언형 API로 통합.
 * - Phase 1 §2.12 요구: columns 스키마 기반, align(left/right), emptyState 슬롯, 호버 토큰화.
 * - 숫자 컬럼(align='right')은 자동으로 font-mono-data tabular-nums 적용 (DESIGN.md §3 숫자 정렬).
 * - Phase 2-A의 StatusBadge · SOFT 프리셋과 독립 — cell 렌더러가 자유롭게 활용.
 */

// 컬럼 정의
export interface DataTableColumn<T> {
  // 컬럼 고유 키 (React key 용도)
  key: string;
  // 헤더 표시 내용
  header: React.ReactNode;
  // 셀 렌더러 (row, index → React 노드)
  cell: (row: T, index: number) => React.ReactNode;
  // 헤더 셀 커스텀 클래스
  headerClassName?: string;
  // 데이터 셀 커스텀 클래스
  cellClassName?: string;
  // 정렬 (right는 숫자 컬럼 — font-mono-data tabular-nums 자동 적용)
  align?: 'left' | 'center' | 'right';
}

export interface DataTableProps<T> {
  columns: DataTableColumn<T>[];
  data: T[];
  // row 고유 key (지정 없으면 index)
  rowKey?: (row: T, index: number) => string | number;
  // 행 클릭 콜백
  onRowClick?: (row: T, index: number) => void;
  // 비어있을 때 표시할 내용
  emptyState?: React.ReactNode;
  // Card 래핑 여부 (default true) — 상위에 이미 Card 있으면 false
  wrapInCard?: boolean;
  // 테이블 루트 클래스
  className?: string;
  // 특정 행 강조용 클래스 반환
  rowClassName?: (row: T, index: number) => string | undefined;
}

function alignClass(align?: 'left' | 'center' | 'right') {
  if (align === 'center') return 'text-center';
  if (align === 'right') return 'text-right font-mono-data tabular-nums';
  return undefined;
}

function headerAlignClass(align?: 'left' | 'center' | 'right') {
  if (align === 'center') return 'text-center';
  if (align === 'right') return 'text-right';
  return undefined;
}

export default function DataTable<T>({
  columns,
  data,
  rowKey,
  onRowClick,
  emptyState,
  wrapInCard = true,
  className,
  rowClassName,
}: DataTableProps<T>) {
  const body = (
    <Table className={className}>
      <TableHeader>
        <TableRow>
          {columns.map((col) => (
            <TableHead
              key={col.key}
              className={cn(headerAlignClass(col.align), col.headerClassName)}
            >
              {col.header}
            </TableHead>
          ))}
        </TableRow>
      </TableHeader>
      <TableBody>
        {data.length === 0 ? (
          <TableRow>
            <TableCell
              colSpan={columns.length}
              className="py-10 text-center text-muted-foreground"
            >
              {emptyState ?? '데이터가 없습니다.'}
            </TableCell>
          </TableRow>
        ) : (
          data.map((row, index) => {
            const key = rowKey ? rowKey(row, index) : index;
            const customRowClass = rowClassName?.(row, index);
            return (
              <TableRow
                key={key}
                onClick={onRowClick ? () => onRowClick(row, index) : undefined}
                className={cn(onRowClick && 'cursor-pointer', customRowClass)}
              >
                {columns.map((col) => (
                  <TableCell
                    key={col.key}
                    className={cn(alignClass(col.align), col.cellClassName)}
                  >
                    {col.cell(row, index)}
                  </TableCell>
                ))}
              </TableRow>
            );
          })
        )}
      </TableBody>
    </Table>
  );

  if (!wrapInCard) {
    return body;
  }

  return (
    <Card>
      <CardContent className="p-0">{body}</CardContent>
    </Card>
  );
}
