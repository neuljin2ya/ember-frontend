# Ember Admin Dashboard

교환일기 소개팅 앱 **Ember**의 관리자 대시보드입니다.

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **UI Components**: shadcn/ui
- **Charts**: Recharts
- **State Management**: Zustand
- **Icons**: Lucide React

## Features

### 회원 관리
- 회원 목록 조회 (커서 기반 페이지네이션)
- 회원 상세 정보 (5탭: 기본정보/활동요약/매칭이력/제재·신고/소셜로그인)
- 의심 계정 탐지 (봇, 스팸, 다중 계정 등)

### 신고 관리
- 신고 목록 및 처리 (우선순위 점수 기반 정렬)
- SLA 관리 (심각 24h / 일반 72h)
- 차단 이력 관리
- 외부 연락처 감지 (정규식 기반 탐지 + 관리자 수동 조치)
- 신고 패턴 분석 대시보드

### 콘텐츠 관리
- 랜덤 주제 관리
- 큐레이션 관리
- 약관 관리 (서비스, 개인정보, 위치정보 등)
- 공지사항 관리

### AI 모니터링
- AI 성능 현황 (KoSimCSE, KcELECTRA)
- A/B 테스트 관리

### 분석
- 매칭 분석
- 리텐션 분석
- 일기 패턴 분석
- 퍼널 분석

### 마케팅
- 이벤트/프로모션 관리

### 시스템
- 시스템 현황 모니터링 (Supabase, Redis, AI 서버)
- 관리자 계정 관리
- 활동 로그 (Activity Logs)
- 기능 플래그 관리
- 배치 스케줄 관리

### 고객지원
- 문의 관리
- 이의신청 처리

## 발표 시연 지도

관리자 대시보드는 발표에서 "Ember가 안전하고 운영 가능한 서비스인가"를 보여주는 화면입니다. 아래 순서로 시연하면 제품 가치, 백엔드 구현, 운영 방어가 자연스럽게 연결됩니다.

| 시연 흐름 | 화면 위치 | 백엔드 근거 | 발표 메시지 |
|---|---|---|---|
| 1. 운영 현황 확인 | `/admin/dashboard`, `/admin/system` | `AdminMonitoringController`, `AdminAnalyticsController` | AI, Redis, MQ, Outbox, 신고/매칭 지표를 운영자가 한 화면에서 감시할 수 있습니다. |
| 2. 신고 우선순위 처리 | `/admin/reports` | `AdminReportController`, `ReportPriorityCalculator` | 신고를 접수 순서가 아니라 위험도와 SLA 기준으로 정렬해 대응 우선순위를 명확히 합니다. |
| 3. 외부 연락처 감지 | `/admin/reports/contacts` 또는 신고 관리 하위 화면 | `AdminContactDetectionController`, `ContentScanService`, `ai/api/content_scan.py` | 일기/채팅 제출 단계의 패턴 차단과 관리자 수동 조치 화면을 구분해서 시연합니다. |
| 4. 금칙어/URL 운영 | `/admin/content` | `BannedWordAdminController`, `UrlWhitelistAdminController`, `ModerationCacheEvictionListener` | 정책 변경 시 DB와 Redis 캐시가 함께 갱신되어 운영 정책 반영 속도가 빠릅니다. |
| 5. AI 모니터링 | `/admin/ai`, `/admin/system` | `AdminMonitoringController`, `AiMetrics`, `MqConsumer` | AI 서버 상태, MQ 처리, 실패 재시도, DLQ 이동까지 운영 관점에서 설명할 수 있습니다. |
| 6. 분석 대시보드 | `/admin/analytics` | `AdminAnalyticsController` | 매칭, 리텐션, 일기, 퍼널 지표를 통해 서비스 개선 근거를 확보합니다. |

## 발표 대비 HTML

백엔드 팀 발표 지원용 고밀도 자료는 로컬 전용 문서로 별도 관리합니다.

- 파일: `../../docs/html/발표_대비_대시보드_백엔드팀_v1.0.html`
- 포함 내용: 발표 어필 포인트, 경쟁 서비스 벤치마킹, 구현 근거 인덱스, 약점 방어, 100개 예상 질문/답변
- 사용 방식: 브라우저로 HTML 파일을 열고, 검색창에서 `SLA`, `Outbox`, `외부 연락처`, `degraded`, `KcELECTRA`, `KoSimCSE` 같은 키워드를 검색합니다.

## Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn

### Installation

```bash
# Install dependencies
npm install

# Run development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser.

### Environment Variables

`.env.local` 파일을 생성하고 다음 변수를 설정하세요:

```env
NEXT_PUBLIC_API_URL=http://localhost:8080
```

## Project Structure

```
src/
├── app/
│   └── admin/
│       ├── dashboard/      # 대시보드
│       ├── members/        # 회원 관리
│       ├── reports/        # 신고 관리
│       ├── content/        # 콘텐츠 관리
│       ├── ai/             # AI 모니터링
│       ├── analytics/      # 분석
│       ├── marketing/      # 마케팅
│       ├── system/         # 시스템
│       └── support/        # 고객지원
├── components/
│   ├── ui/                 # shadcn/ui 컴포넌트
│   ├── layout/             # 레이아웃 (Sidebar, Header)
│   ├── dashboard/          # 대시보드 컴포넌트
│   └── common/             # 공통 컴포넌트
├── hooks/                  # Custom hooks
├── lib/
│   └── api/                # API 클라이언트
├── types/                  # TypeScript 타입 정의
└── stores/                 # Zustand stores
```

## Scripts

```bash
npm run dev      # 개발 서버 실행
npm run build    # 프로덕션 빌드
npm run start    # 프로덕션 서버 실행
npm run lint     # ESLint 실행
```

## Related Repositories

- [Ember Monorepo](https://github.com/gc-code1piece/main.git)
- Backend: `../../Backend/`
- AI Server: `../../ai/`
- Mobile App: `../../lib/`, `../../android/`, `../../ios/`

## License

Private - All rights reserved
