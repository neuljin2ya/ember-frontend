'use client';

// 금칙어 관리 페이지 — 실 API 연동 (PR-β).
// 백엔드 §9.6 BannedWordAdminController: GET/POST/PUT/DELETE /api/admin/content/banned-words

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import PageHeader from '@/components/layout/PageHeader';
import SearchBar from '@/components/common/SearchBar';
import Pagination from '@/components/common/Pagination';
import {
  AnalyticsLoading,
  AnalyticsError,
} from '@/components/common/AnalyticsStatus';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Input } from '@/components/ui/input';
import { useAuthStore } from '@/stores/authStore';
import { formatDateTime } from '@/lib/utils/format';
import { Plus, Trash2, RefreshCw } from 'lucide-react';
import toast from 'react-hot-toast';
import {
  bannedWordsApi,
  type BannedWordCategory,
  type BannedWordMatchMode,
  type BannedWordResponse,
} from '@/lib/api/bannedWords';

const CATEGORY_LABELS: Record<BannedWordCategory, string> = {
  PROFANITY: '욕설/비하',
  SEXUAL: '성적 표현',
  DISCRIMINATION: '차별/혐오',
  ETC: '기타(외부 연락처)',
};

const CATEGORY_COLORS: Record<BannedWordCategory, string> = {
  PROFANITY: 'bg-red-100 text-red-800',
  SEXUAL: 'bg-pink-100 text-pink-800',
  DISCRIMINATION: 'bg-orange-100 text-orange-800',
  ETC: 'bg-gray-100 text-gray-700',
};

const PAGE_SIZE = 20;

export default function BannedWordsPage() {
  const { hasPermission } = useAuthStore();
  const qc = useQueryClient();

  const [keyword, setKeyword] = useState('');
  const [categoryFilter, setCategoryFilter] = useState<string>('ALL');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  const [page, setPage] = useState(0);

  const [isAdding, setIsAdding] = useState(false);
  const [newWord, setNewWord] = useState('');
  const [newCategory, setNewCategory] = useState<BannedWordCategory>('PROFANITY');
  const [newMatchMode, setNewMatchMode] = useState<BannedWordMatchMode>('PARTIAL');

  // 목록 조회
  const listQuery = useQuery({
    queryKey: ['banned-words', { keyword, categoryFilter, statusFilter, page }],
    queryFn: () =>
      bannedWordsApi
        .list({
          q: keyword || undefined,
          category: categoryFilter === 'ALL' ? undefined : (categoryFilter as BannedWordCategory),
          isActive:
            statusFilter === 'ALL' ? undefined : statusFilter === 'ACTIVE',
          page,
          size: PAGE_SIZE,
        })
        .then((res) => res.data.data),
  });

  const invalidate = () => qc.invalidateQueries({ queryKey: ['banned-words'] });

  // 생성
  const createMutation = useMutation({
    mutationFn: () =>
      bannedWordsApi.create({
        word: newWord.trim(),
        category: newCategory,
        matchMode: newMatchMode,
        isActive: true,
      }),
    onSuccess: () => {
      toast.success('금칙어가 추가되었습니다.');
      setNewWord('');
      setNewCategory('PROFANITY');
      setNewMatchMode('PARTIAL');
      setIsAdding(false);
      invalidate();
    },
    onError: (e: Error) => toast.error(`추가 실패: ${e.message}`),
  });

  // 활성 토글 (PUT)
  const toggleMutation = useMutation({
    mutationFn: (item: BannedWordResponse) =>
      bannedWordsApi.update(item.id, { isActive: !item.isActive }),
    onSuccess: () => {
      toast.success('활성 상태가 변경되었습니다.');
      invalidate();
    },
    onError: (e: Error) => toast.error(`변경 실패: ${e.message}`),
  });

  // 비활성화(soft-delete)
  const deleteMutation = useMutation({
    mutationFn: (id: number) => bannedWordsApi.delete(id),
    onSuccess: () => {
      toast.success('금칙어가 비활성화되었습니다.');
      invalidate();
    },
    onError: (e: Error) => toast.error(`삭제 실패: ${e.message}`),
  });

  const handleAddWord = () => {
    if (!newWord.trim()) {
      toast.error('금칙어를 입력해주세요.');
      return;
    }
    createMutation.mutate();
  };

  const data = listQuery.data;
  const words = data?.content ?? [];
  const totalElements = data?.totalElements ?? 0;
  const totalPages = data?.totalPages ?? 0;

  return (
    <div>
      <PageHeader
        title="금칙어 관리"
        description="일기 작성 시 필터링되는 금칙어를 관리합니다"
        actions={
          hasPermission('SUPER_ADMIN') && (
            <Button onClick={() => setIsAdding(true)}>
              <Plus className="mr-2 h-4 w-4" />
              금칙어 추가
            </Button>
          )
        }
      />

      {/* 통계 카드 (현재 페이지 + 총합 일부) */}
      <div className="mb-6 grid gap-4 md:grid-cols-3">
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold">{totalElements.toLocaleString()}</div>
            <p className="text-sm text-muted-foreground">전체 금칙어 (필터 적용)</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold text-green-600">
              {words.filter((w) => w.isActive).length}
            </div>
            <p className="text-sm text-muted-foreground">현재 페이지 활성</p>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="text-2xl font-bold">4</div>
            <p className="text-sm text-muted-foreground">카테고리 수</p>
          </CardContent>
        </Card>
      </div>

      {/* 인라인 추가 폼 */}
      {isAdding && (
        <Card className="mb-6">
          <CardContent className="p-4">
            <div className="flex flex-wrap gap-2">
              <Input
                placeholder="금칙어 입력..."
                value={newWord}
                onChange={(e) => setNewWord(e.target.value)}
                className="min-w-[200px] flex-1"
                onKeyDown={(e) => e.key === 'Enter' && handleAddWord()}
                disabled={createMutation.isPending}
              />
              <select
                value={newCategory}
                onChange={(e) => setNewCategory(e.target.value as BannedWordCategory)}
                className="rounded-md border px-3 py-2 text-sm"
                disabled={createMutation.isPending}
              >
                {(Object.keys(CATEGORY_LABELS) as BannedWordCategory[]).map((cat) => (
                  <option key={cat} value={cat}>
                    {CATEGORY_LABELS[cat]}
                  </option>
                ))}
              </select>
              <select
                value={newMatchMode}
                onChange={(e) => setNewMatchMode(e.target.value as BannedWordMatchMode)}
                className="rounded-md border px-3 py-2 text-sm"
                disabled={createMutation.isPending}
              >
                <option value="PARTIAL">부분 일치</option>
                <option value="EXACT">완전 일치</option>
              </select>
              <Button onClick={handleAddWord} disabled={createMutation.isPending}>
                {createMutation.isPending ? '추가 중...' : '추가'}
              </Button>
              <Button variant="outline" onClick={() => setIsAdding(false)}>
                취소
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* 필터 */}
      <div className="mb-6 flex flex-wrap gap-4">
        <div className="min-w-[240px] flex-1">
          <SearchBar
            value={keyword}
            onChange={(v) => {
              setKeyword(v);
              setPage(0);
            }}
            placeholder="금칙어 검색"
          />
        </div>
        <div className="flex gap-2">
          <select
            value={categoryFilter}
            onChange={(e) => {
              setCategoryFilter(e.target.value);
              setPage(0);
            }}
            className="rounded-md border px-3 py-2 text-sm"
          >
            <option value="ALL">전체 카테고리</option>
            {(Object.keys(CATEGORY_LABELS) as BannedWordCategory[]).map((cat) => (
              <option key={cat} value={cat}>
                {CATEGORY_LABELS[cat]}
              </option>
            ))}
          </select>
          <select
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value);
              setPage(0);
            }}
            className="rounded-md border px-3 py-2 text-sm"
          >
            <option value="ALL">전체 상태</option>
            <option value="ACTIVE">활성</option>
            <option value="INACTIVE">비활성</option>
          </select>
        </div>
      </div>

      {/* 금칙어 목록 */}
      <Card>
        <CardHeader>
          <CardTitle>금칙어 목록 ({totalElements.toLocaleString()}개)</CardTitle>
        </CardHeader>
        <CardContent className="p-0">
          {listQuery.isLoading && <AnalyticsLoading height={240} />}
          {listQuery.isError && (
            <AnalyticsError
              height={240}
              message={(listQuery.error as Error)?.message}
              onRetry={() => listQuery.refetch()}
            />
          )}
          {data && (
            <>
              <div className="divide-y">
                {words.map((w) => (
                  <div
                    key={w.id}
                    className="flex items-center justify-between p-4 hover:bg-muted/30"
                  >
                    <div className="flex flex-1 items-center gap-4">
                      <code className="rounded bg-muted px-2 py-1 font-mono text-sm font-semibold">
                        {w.word}
                      </code>
                      <Badge className={CATEGORY_COLORS[w.category]}>
                        {CATEGORY_LABELS[w.category]}
                      </Badge>
                      <Badge variant="outline" className="text-xs">
                        {w.matchMode === 'EXACT' ? '완전 일치' : '부분 일치'}
                      </Badge>
                      {!w.isActive && <Badge variant="secondary">비활성</Badge>}
                      <span className="text-xs text-muted-foreground">
                        {formatDateTime(w.createdAt)}
                        {w.createdByAdminName && ` · ${w.createdByAdminName}`}
                      </span>
                    </div>
                    {hasPermission('SUPER_ADMIN') && (
                      <div className="flex gap-1">
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => toggleMutation.mutate(w)}
                          title={w.isActive ? '비활성화' : '활성화'}
                          disabled={toggleMutation.isPending}
                        >
                          <RefreshCw className="h-4 w-4" />
                        </Button>
                        <Button
                          variant="ghost"
                          size="sm"
                          onClick={() => {
                            if (confirm(`"${w.word}" 금칙어를 비활성화하시겠습니까?`)) {
                              deleteMutation.mutate(w.id);
                            }
                          }}
                          disabled={deleteMutation.isPending}
                        >
                          <Trash2 className="h-4 w-4 text-red-500" />
                        </Button>
                      </div>
                    )}
                  </div>
                ))}
                {words.length === 0 && (
                  <div className="p-8 text-center text-muted-foreground">
                    검색 결과가 없습니다.
                  </div>
                )}
              </div>
              {totalPages > 1 && (
                <div className="border-t border-border p-3">
                  <Pagination
                    currentPage={page}
                    totalPages={totalPages}
                    onPageChange={setPage}
                  />
                </div>
              )}
            </>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
