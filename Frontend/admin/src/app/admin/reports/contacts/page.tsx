'use client';

import { useEffect, useMemo, useState } from 'react';
import PageHeader from '@/components/layout/PageHeader';
import SearchBar from '@/components/common/SearchBar';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { formatDateTime } from '@/lib/utils/format';
import {
  RefreshCw,
  Eye,
  AlertTriangle,
  CheckCircle,
  XCircle,
  Phone,
  Mail,
  MessageCircle,
  Link as LinkIcon,
  Shield,
} from 'lucide-react';
import toast from 'react-hot-toast';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from 'recharts';

import {
  contactsApi,
  type ContactDetection,
  type ContactPatternType,
  type ContactStatus,
  type ContactDetectionStats,
} from '@/lib/api/contacts';

// ─────────────────────────────────────────────────────────
// 관리자 v2.1 §5.10~§5.11 · 외부 연락처 감지 (Phase A-5 실 API 연동)
// ─────────────────────────────────────────────────────────

const PIE_COLORS = ['#3b82f6', '#22c55e', '#f59e0b', '#ef4444', '#8b5cf6', '#6b7280'];

const PATTERN_TYPE_LABELS: Record<ContactPatternType, string> = {
  PHONE: '전화번호',
  EMAIL: '이메일',
  KAKAO: '카카오톡',
  INSTAGRAM: '인스타그램',
  LINK: '외부 링크',
  OTHER: '기타',
};

const PATTERN_TYPE_COLORS: Record<ContactPatternType, string> = {
  PHONE: 'bg-blue-100 text-blue-800',
  EMAIL: 'bg-green-100 text-green-800',
  KAKAO: 'bg-yellow-100 text-yellow-800',
  INSTAGRAM: 'bg-pink-100 text-pink-800',
  LINK: 'bg-purple-100 text-purple-800',
  OTHER: 'bg-gray-100 text-gray-800',
};

const PATTERN_TYPE_ICONS: Record<ContactPatternType, React.ReactNode> = {
  PHONE: <Phone className="h-4 w-4" />,
  EMAIL: <Mail className="h-4 w-4" />,
  KAKAO: <MessageCircle className="h-4 w-4" />,
  INSTAGRAM: <MessageCircle className="h-4 w-4" />,
  LINK: <LinkIcon className="h-4 w-4" />,
  OTHER: <Shield className="h-4 w-4" />,
};

const CONTENT_TYPE_LABELS: Record<string, string> = {
  DIARY: '일기',
  EXCHANGE_DIARY: '교환일기',
  CHAT_MESSAGE: '채팅',
};

const STATUS_LABELS: Record<ContactStatus, string> = {
  PENDING: '검토 대기',
  CONFIRMED: '확인됨',
  FALSE_POSITIVE: '오탐지',
};

const STATUS_COLORS: Record<ContactStatus, string> = {
  PENDING: 'bg-yellow-100 text-yellow-800',
  CONFIRMED: 'bg-red-100 text-red-800',
  FALSE_POSITIVE: 'bg-green-100 text-green-800',
};

export default function ExternalContactsPage() {
  const [keyword, setKeyword] = useState('');
  const [typeFilter, setTypeFilter] = useState<'ALL' | ContactPatternType>('ALL');
  const [statusFilter, setStatusFilter] = useState<'ALL' | ContactStatus>('ALL');

  const [detections, setDetections] = useState<ContactDetection[]>([]);
  const [stats, setStats] = useState<ContactDetectionStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [version, setVersion] = useState(0); // 새로고침용

  // 실 API 호출 — 관리자 API v2.1 §5.10 + /stats
  useEffect(() => {
    let ignore = false;
    const load = async () => {
      setLoading(true);
      try {
        const [listRes, statsRes] = await Promise.all([
          contactsApi.getList({
            status: statusFilter === 'ALL' ? undefined : statusFilter,
            patternType: typeFilter === 'ALL' ? undefined : typeFilter,
            periodDays: 30,
            size: 100,
          }),
          contactsApi.getStats(7),
        ]);
        if (ignore) return;
        setDetections(listRes.data.data.content);
        setStats(statsRes.data.data);
      } catch (err) {
        if (!ignore) toast.error('외부 연락처 감지 데이터를 불러오지 못했습니다.');
      } finally {
        if (!ignore) setLoading(false);
      }
    };
    load();
    return () => {
      ignore = true;
    };
  }, [typeFilter, statusFilter, version]);

  const filtered = useMemo(() => {
    if (!keyword) return detections;
    return detections.filter(
      (d) => d.nickname.includes(keyword) || d.detectedText.includes(keyword),
    );
  }, [detections, keyword]);

  const patternChartData = useMemo(() => {
    if (!stats) return [];
    return (Object.keys(stats.byPatternType) as ContactPatternType[])
      .map((t) => ({ type: PATTERN_TYPE_LABELS[t], count: stats.byPatternType[t] ?? 0 }))
      .filter((row) => row.count > 0);
  }, [stats]);

  const handleRefresh = () => setVersion((v) => v + 1);

  const handleAction = async (
    detectionId: number,
    action: 'HIDE_AND_WARN' | 'ESCALATE_TO_REPORT' | 'DISMISS',
  ) => {
    const adminMemo = window.prompt('처리 메모를 입력하세요 (1~500자)');
    if (!adminMemo || adminMemo.trim().length === 0) {
      return;
    }
    try {
      await contactsApi.applyAction(detectionId, { action, adminMemo: adminMemo.trim() });
      toast.success(
        action === 'DISMISS' ? '오탐지로 처리했습니다.' : '외부 연락처 공유로 확인했습니다.',
      );
      handleRefresh();
    } catch {
      toast.error('조치 처리에 실패했습니다.');
    }
  };

  return (
    <div>
      <PageHeader
        title="외부 연락처 감지 관리"
        description="AI 기반 외부 연락처 공유 감지 및 관리 (관리자 API v2.1 §5.10~5.11)"
        actions={
          <Button variant="outline" onClick={handleRefresh} disabled={loading}>
            <RefreshCw className={`mr-2 h-4 w-4 ${loading ? 'animate-spin' : ''}`} />
            새로고침
          </Button>
        }
      />

      {/* Stats */}
      <div className="mb-6 grid gap-4 md:grid-cols-4">
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <Shield className="h-5 w-5 text-blue-500" />
              <span className="text-sm text-muted-foreground">최근 7일 감지</span>
            </div>
            <div className="mt-1 text-2xl font-bold">{stats?.totalCount ?? '-'}</div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-yellow-500" />
              <span className="text-sm text-muted-foreground">검토 대기</span>
            </div>
            <div className="mt-1 text-2xl font-bold text-yellow-600">
              {stats?.pendingCount ?? '-'}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <XCircle className="h-5 w-5 text-red-500" />
              <span className="text-sm text-muted-foreground">확인됨</span>
            </div>
            <div className="mt-1 text-2xl font-bold text-red-600">
              {stats?.confirmedCount ?? '-'}
            </div>
          </CardContent>
        </Card>
        <Card>
          <CardContent className="p-4">
            <div className="flex items-center gap-2">
              <CheckCircle className="h-5 w-5 text-green-500" />
              <span className="text-sm text-muted-foreground">오탐지</span>
            </div>
            <div className="mt-1 text-2xl font-bold text-green-600">
              {stats?.falsePositiveCount ?? '-'}
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Chart */}
      <div className="mb-6 grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle>패턴 유형별 감지</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie
                  data={patternChartData}
                  cx="50%"
                  cy="50%"
                  outerRadius={80}
                  dataKey="count"
                  label={({ type, count }) => `${type}: ${count}`}
                >
                  {patternChartData.map((_, index) => (
                    <Cell key={`cell-${index}`} fill={PIE_COLORS[index % PIE_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
        <Card>
          <CardHeader>
            <CardTitle>유형별 건수</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={patternChartData}>
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="type" />
                <YAxis />
                <Tooltip />
                <Bar dataKey="count" fill="#3b82f6" />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Filters */}
      <div className="mb-4 flex flex-wrap gap-2">
        <SearchBar value={keyword} onChange={setKeyword} placeholder="닉네임·감지 텍스트 검색" />
        <select
          className="rounded border px-3 py-2 text-sm"
          value={typeFilter}
          onChange={(e) => setTypeFilter(e.target.value as 'ALL' | ContactPatternType)}
        >
          <option value="ALL">전체 유형</option>
          {(Object.keys(PATTERN_TYPE_LABELS) as ContactPatternType[]).map((t) => (
            <option key={t} value={t}>
              {PATTERN_TYPE_LABELS[t]}
            </option>
          ))}
        </select>
        <select
          className="rounded border px-3 py-2 text-sm"
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as 'ALL' | ContactStatus)}
        >
          <option value="ALL">전체 상태</option>
          <option value="PENDING">검토 대기</option>
          <option value="CONFIRMED">확인됨</option>
          <option value="FALSE_POSITIVE">오탐지</option>
        </select>
      </div>

      {/* Table */}
      <Card>
        <CardContent className="p-0">
          <table className="min-w-full text-sm">
            <thead className="bg-gray-50 text-gray-700">
              <tr>
                <th className="px-3 py-2 text-left">감지 일시</th>
                <th className="px-3 py-2 text-left">사용자</th>
                <th className="px-3 py-2 text-left">유형</th>
                <th className="px-3 py-2 text-left">감지 텍스트</th>
                <th className="px-3 py-2 text-left">맥락</th>
                <th className="px-3 py-2 text-left">상태</th>
                <th className="px-3 py-2 text-left">신뢰도</th>
                <th className="px-3 py-2 text-left">조치</th>
              </tr>
            </thead>
            <tbody>
              {loading && (
                <tr>
                  <td className="px-3 py-6 text-center text-muted-foreground" colSpan={8}>
                    불러오는 중…
                  </td>
                </tr>
              )}
              {!loading && filtered.length === 0 && (
                <tr>
                  <td className="px-3 py-6 text-center text-muted-foreground" colSpan={8}>
                    감지된 항목이 없습니다.
                  </td>
                </tr>
              )}
              {filtered.map((d) => (
                <tr key={d.id} className="border-t">
                  <td className="px-3 py-2">{formatDateTime(d.detectedAt)}</td>
                  <td className="px-3 py-2">{d.nickname}</td>
                  <td className="px-3 py-2">
                    <Badge className={PATTERN_TYPE_COLORS[d.patternType]}>
                      <span className="mr-1">{PATTERN_TYPE_ICONS[d.patternType]}</span>
                      {PATTERN_TYPE_LABELS[d.patternType]}
                    </Badge>
                    <div className="text-xs text-muted-foreground">
                      {CONTENT_TYPE_LABELS[d.contentType] ?? d.contentType}
                    </div>
                  </td>
                  <td className="px-3 py-2 font-mono">{d.detectedText}</td>
                  <td className="max-w-xs truncate px-3 py-2" title={d.context ?? undefined}>
                    {d.context ?? '-'}
                  </td>
                  <td className="px-3 py-2">
                    <Badge className={STATUS_COLORS[d.status]}>{STATUS_LABELS[d.status]}</Badge>
                  </td>
                  <td className="px-3 py-2">{d.confidence}%</td>
                  <td className="px-3 py-2">
                    {d.status === 'PENDING' ? (
                      <div className="flex gap-1">
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => handleAction(d.id, 'HIDE_AND_WARN')}
                        >
                          숨김+경고
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => handleAction(d.id, 'ESCALATE_TO_REPORT')}
                        >
                          신고 전환
                        </Button>
                        <Button
                          size="sm"
                          variant="ghost"
                          onClick={() => handleAction(d.id, 'DISMISS')}
                        >
                          오탐지
                        </Button>
                      </div>
                    ) : (
                      <span className="text-xs text-muted-foreground">
                        {d.actionType ?? '-'} · {d.reviewedByName ?? '-'}
                      </span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </CardContent>
      </Card>

      <div className="mt-4 flex items-center gap-2 text-xs text-muted-foreground">
        <Eye className="h-3 w-3" />
        <span>상세 맥락 조회는 PII 접근 로그 대상입니다 (관리자 API v2.1 §5.6).</span>
      </div>
    </div>
  );
}
