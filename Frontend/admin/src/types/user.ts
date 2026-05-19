// 회원 상태 (ERD v2.0 기준 6종)
export type UserStatus =
  | 'ACTIVE'
  | 'GUEST'
  | 'SUSPEND_7D'
  | 'SUSPEND_30D'
  | 'BANNED'
  | 'DEACTIVATED';

export type UserRole = 'ROLE_USER' | 'ROLE_GUEST';

// 성별 (ERD v2.0 기준)
export type Gender = 'MALE' | 'FEMALE';

// 의심 계정 관련
export type SuspicionType = 'BOT' | 'FAKE_PROFILE' | 'SPAM' | 'MULTI_ACCOUNT' | 'SCAM';
export type SuspiciousAccountStatus = 'PENDING' | 'INVESTIGATING' | 'CONFIRMED' | 'CLEARED';

// 회원 목록 항목 (GET /api/admin/members 응답)
export interface AdminMemberListItem {
  id: number;
  nickname: string;
  realName: string;
  email: string;
  gender: Gender;
  birthDate: string;
  sido: string;
  sigungu: string;
  status: UserStatus;
  lastLoginAt: string;
  createdAt: string;
}

// 회원 상세 (GET /api/admin/members/{id} 응답)
export interface AdminUserDetail {
  id: number;
  email: string;
  emailMasked: boolean;
  nickname: string;
  realName: string;
  gender: Gender;
  birthDate: string;
  sido: string;
  sigungu: string;
  school: string | null;
  status: UserStatus;
  role: UserRole;
  onboardingCompleted: boolean;
  createdAt: string;
  modifiedAt: string;
  lastLoginAt: string;
  suspensionReason: string | null;
  suspendedUntil: string | null;
}

// 활동 요약 (GET /api/admin/members/{id}/activity-summary 응답)
export interface ActivitySummary {
  totalDiaries: number;
  totalMatches: number;
  activeDays: number;
  lastActiveAt: string;
}

// 회원 일기 항목
export interface MemberDiary {
  id: number;
  title: string | null;
  contentPreview: string;
  summary: string | null;
  category: string | null;
  createdAt: string;
  analysisStatus: string;
}

export interface SuspiciousAccount {
  id: number;
  userId: number;
  nickname: string;
  email: string;
  signupDate: string;
  suspicionType: SuspicionType;
  riskScore: number;
  indicators: string[];
  status: SuspiciousAccountStatus;
  detectedAt: string;
  lastActivity: string;
  activityCount: number;
}

// 백엔드 page/size 기반 검색 파라미터
export interface MemberSearchParams {
  page?: number;
  size?: number;
  status?: UserStatus;
  gender?: Gender;
  nickname?: string;
  email?: string;
  sortBy?: string;
}
