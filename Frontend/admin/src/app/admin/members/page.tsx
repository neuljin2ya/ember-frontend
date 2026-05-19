'use client';

import { useState } from 'react';
import Link from 'next/link';
import PageHeader from '@/components/layout/PageHeader';
import SearchBar from '@/components/common/SearchBar';
import Pagination from '@/components/common/Pagination';
import StatusBadge from '@/components/common/StatusBadge';
import DataTable, { type DataTableColumn } from '@/components/common/DataTable';
import { AnalyticsLoading, AnalyticsError } from '@/components/common/AnalyticsStatus';
import { Button } from '@/components/ui/button';
import { formatDateTime } from '@/lib/utils/format';
import { Eye } from 'lucide-react';
import { useMemberList } from '@/hooks/useUsers';
import type { AdminMemberListItem } from '@/types/user';

const columns: DataTableColumn<AdminMemberListItem>[] = [
  {
    key: 'nickname',
    header: '닉네임',
    cell: (user) => <span className="font-medium">{user.nickname}</span>,
  },
  { key: 'realName', header: '실명', cell: (user) => user.realName || '-' },
  {
    key: 'gender',
    header: '성별',
    cell: (user) => (user.gender === 'MALE' ? '남성' : '여성'),
  },
  {
    key: 'sido',
    header: '지역',
    cell: (user) => [user.sido, user.sigungu].filter(Boolean).join(' ') || '-',
  },
  {
    key: 'status',
    header: '상태',
    cell: (user) => <StatusBadge status={user.status} />,
  },
  {
    key: 'lastLoginAt',
    header: '최근 로그인',
    cell: (user) => (
      <span className="text-muted-foreground">
        {user.lastLoginAt ? formatDateTime(user.lastLoginAt) : '-'}
      </span>
    ),
  },
  {
    key: 'createdAt',
    header: '가입일',
    cell: (user) => (
      <span className="text-muted-foreground">{formatDateTime(user.createdAt)}</span>
    ),
  },
  {
    key: 'actions',
    header: '액션',
    cell: (user) => (
      <Link href={`/admin/members/${user.id}`}>
        <Button variant="ghost" size="xs">
          <Eye className="mr-1 h-4 w-4" />
          상세
        </Button>
      </Link>
    ),
  },
];

export default function UsersPage() {
  const [page, setPage] = useState(0);
  const [keyword, setKeyword] = useState('');

  const { data, isLoading, isError, error } = useMemberList({
    nickname: keyword || undefined,
    page,
    size: 20,
  });

  const handleSearch = () => {
    setPage(0);
  };

  if (isLoading) {
    return (
      <div>
        <PageHeader title="회원 관리" description="전체 회원 목록 조회 및 관리" />
        <AnalyticsLoading label="회원 목록을 불러오는 중입니다..." />
      </div>
    );
  }

  if (isError) {
    return (
      <div>
        <PageHeader title="회원 관리" description="전체 회원 목록 조회 및 관리" />
        <AnalyticsError message={error?.message || '회원 목록을 불러오지 못했습니다.'} />
      </div>
    );
  }

  const members = data?.content ?? [];
  const totalPages = data?.totalPages ?? 1;

  return (
    <div>
      <PageHeader
        title="회원 관리"
        description="전체 회원 목록 조회 및 관리"
      />

      <div className="mb-6">
        <SearchBar
          value={keyword}
          onChange={setKeyword}
          placeholder="닉네임 또는 이름 검색"
          onSearch={handleSearch}
        />
      </div>

      <DataTable
        columns={columns}
        data={members}
        rowKey={(user) => user.id}
        emptyState="검색 결과가 없습니다."
      />

      <Pagination
        currentPage={page}
        totalPages={totalPages}
        onPageChange={setPage}
      />
    </div>
  );
}
