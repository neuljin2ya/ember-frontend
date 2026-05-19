# Design System — Ember Admin

> 교환일기 기반 소개팅 앱 'Ember'의 관리자 대시보드 디자인 시스템
> /design-consultation (Gstack) 로 구축 · **v1.0.1 · 2026-04-21 (Phase 1 문구 패치)**
> 패치 요약: Sidebar 폭 w-64 [D-02], Input radius md [D-01], Badge radius 이원화, KPI Card variant 스펙 명시

---

## 1. Product Context

- **What this is**: Ember 관리자 대시보드 — 회원/신고/콘텐츠/AI/분석 35개 페이지
- **Who it's for**: 서비스 운영진 (VIEWER / ADMIN / SUPER_ADMIN). 장시간 반복 사용, 높은 데이터 밀도 요구.
- **Space**: 소셜·매칭 앱 어드민 (Notion·Linear·Stripe dashboard 계열)
- **Project type**: internal web app (관리 도구)
- **Core tension**: 서비스 본체는 감성적·따뜻함(교환일기), 관리 도구는 기능적·데이터 중심 → 관리 도구에 브랜드 DNA를 과하지 않게 녹여야 함.

## 2. Aesthetic Direction

- **Direction**: **Warm Industrial** — 데이터 밀도 중심 관리 도구(industrial)에 Ember(불씨)의 따뜻함을 accent · 타이포 · warm neutral 로 덧입힌 방향
- **Decoration level**: **intentional** — 장식 최소화, 단 서체 선택·색 온도·그림자 톤으로 온기 표현
- **Mood**: "조용한 새벽 작업실, 따뜻한 등불 아래 데이터를 보는 관리자"
- **Reference direction**: Linear(정보 밀도) + Stripe Dashboard(톤) + Vercel Admin(다크 퀄리티)을 benchmark, 단 모두 쓰는 blue/slate 팔레트는 거부하고 warm orange 로 분기

## 3. Typography

한국어 제품이므로 **Pretendard** 를 기본 패밀리로 채택. Inter / Roboto / 시스템 기본은 전부 제외.

| Role | Font | Weight | Rationale |
|------|------|--------|-----------|
| **Hero / Display** | `Instrument Serif` | 400 | **RISK**: 관리자 툴에 세리프는 드물어 editorial 감성으로 AI slop 제거 |
| **Heading (H1~H3)** | `Pretendard Variable` | 600~700 | 한국어 본문 대응, 깔끔한 현대성 |
| **Body** | `Pretendard` | 400~500 | 가독성 최고, 국내 디자인 표준 |
| **UI Label** | `Pretendard` | 500 | 버튼·뱃지·테이블 헤더 |
| **Data / Tabular** | `JetBrains Mono` | 400~500 | 숫자 정렬·코드·로그. `tabular-nums` 필수 |
| **KPI Number** | `Instrument Serif` | 400 | **RISK**: 큰 숫자만 세리프 → 카드가 잡지 표지 느낌 |

### Scale (1.25 modular)

| Token | px | Usage |
|-------|----|----|
| `text-xs` | 12 | 캡션·메타 |
| `text-sm` | 14 | UI 기본 |
| `text-base` | 16 | 본문 |
| `text-lg` | 18 | H4 |
| `text-xl` | 20 | H3 |
| `text-2xl` | 24 | H2 |
| `text-3xl` | 32 | H1 |
| `text-4xl` | 48 | Hero |
| `text-display` | 64 | KPI 숫자 (Instrument Serif) |

## 4. Color — "Ember Signal"

Primary accent는 관리자 툴에서 거의 안 쓰는 **orange**. 경고색은 red-rose 계열로 분리해 충돌 방지.

### 4.1 Light Mode

| Token | HSL | Hex | Usage |
|-------|-----|-----|-------|
| `--background` | `60 9% 98%` | `#FAFAF9` | 페이지 베이스 (warm stone) |
| `--foreground` | `20 14% 10%` | `#1C1917` | 본문 텍스트 |
| `--card` | `0 0% 100%` | `#FFFFFF` | 카드 · 패널 |
| `--card-foreground` | `20 14% 10%` | `#1C1917` | 카드 텍스트 |
| `--primary` | `17 88% 40%` | `#C2410C` | 주요 액션 (Ember orange-700, 대비 확보) |
| `--primary-foreground` | `60 9% 98%` | `#FAFAF9` | 주요 액션 텍스트 |
| `--secondary` | `24 10% 95%` | `#F5F5F4` | 보조 배경 (stone-100) |
| `--secondary-foreground` | `20 14% 10%` | `#1C1917` | 보조 텍스트 |
| `--muted` | `24 10% 95%` | `#F5F5F4` | 약화 배경 |
| `--muted-foreground` | `24 6% 45%` | `#78716C` | 약화 텍스트 (stone-500) |
| `--accent` | `30 100% 94%` | `#FFEDD5` | Ember accent (orange-100, 하이라이트) |
| `--accent-foreground` | `17 88% 25%` | `#7C2D12` | Accent 텍스트 |
| `--destructive` | `0 72% 45%` | `#DC2626` | 파괴 액션 (red-600) |
| `--destructive-foreground` | `60 9% 98%` | `#FAFAF9` | 파괴 텍스트 |
| `--border` | `24 6% 90%` | `#E7E5E4` | 경계 (stone-200) |
| `--input` | `24 6% 90%` | `#E7E5E4` | 입력 경계 |
| `--ring` | `17 88% 40%` | `#C2410C` | 포커스 링 |
| `--success` | `142 71% 36%` | `#16A34A` | 성공 (green-600) |
| `--warning` | `38 92% 50%` | `#F59E0B` | 경고 (amber-500, primary와 분리) |
| `--info` | `199 89% 48%` | `#0EA5E9` | 정보 (sky-500) |

### 4.2 Dark Mode — Warm Black

일반 slate-900(cool) 대신 **stone-950(warm)** 기반. 장시간 대시보드 시청에 눈 피로도 낮음.

| Token | HSL | Hex | Usage |
|-------|-----|-----|-------|
| `--background` | `20 14% 4%` | `#0C0A09` | 페이지 베이스 |
| `--foreground` | `60 9% 98%` | `#FAFAF9` | 본문 텍스트 |
| `--card` | `20 14% 7%` | `#1C1917` | 카드 (stone-900) |
| `--card-foreground` | `60 9% 98%` | `#FAFAF9` | 카드 텍스트 |
| `--primary` | `17 88% 55%` | `#F97316` | 주요 액션 (orange-500, 다크에 밝게) |
| `--primary-foreground` | `20 14% 4%` | `#0C0A09` | 주요 액션 텍스트 |
| `--secondary` | `20 10% 15%` | `#292524` | 보조 (stone-800) |
| `--secondary-foreground` | `60 9% 98%` | `#FAFAF9` | 보조 텍스트 |
| `--muted` | `20 10% 15%` | `#292524` | 약화 배경 |
| `--muted-foreground` | `24 5% 64%` | `#A8A29E` | 약화 텍스트 (stone-400) |
| `--accent` | `20 10% 20%` | `#44403C` | Accent 면 (stone-700) |
| `--accent-foreground` | `30 100% 85%` | `#FED7AA` | Accent 텍스트 |
| `--destructive` | `0 63% 45%` | `#B91C1C` | 파괴 |
| `--destructive-foreground` | `60 9% 98%` | `#FAFAF9` | 파괴 텍스트 |
| `--border` | `20 10% 15%` | `#292524` | 경계 |
| `--input` | `20 10% 15%` | `#292524` | 입력 경계 |
| `--ring` | `17 88% 55%` | `#F97316` | 포커스 링 |
| `--success` | `142 71% 45%` | `#22C55E` | 성공 |
| `--warning` | `38 92% 60%` | `#FBBF24` | 경고 |
| `--info` | `199 89% 55%` | `#38BDF8` | 정보 |

### 4.3 색상 사용 규칙

- **Primary Orange**: 주요 CTA, active nav, 강조 포인트. 페이지당 **1~2회** 이상 남용 금지.
- **Accent (orange-100/stone-700)**: 선택된 행·챕터 표기, "내 담당" 배지 배경 등 은은한 하이라이트.
- **Warning(amber)은 primary와 분리**: primary가 orange이므로 경고는 반드시 **amber** 또는 **red-rose**. 같은 hue 충돌 금지.
- **Destructive는 red-only**: 삭제·영구정지만. 일반 "주의" 표기는 warning.

## 5. Spacing

- **Base unit**: 4px
- **Density**: compact-comfortable (관리 도구용)
- **Scale**:

| Token | px | Usage |
|-------|----|----|
| `0.5` | 2 | 세밀 틈 |
| `1` | 4 | 아이콘·텍스트 틈 |
| `2` | 8 | 컴포넌트 내부 패딩 |
| `3` | 12 | 인라인 요소 |
| `4` | 16 | 기본 섹션 여백 |
| `6` | 24 | 카드 내부 패딩 |
| `8` | 32 | 섹션 사이 |
| `12` | 48 | 페이지 섹션 간 |
| `16` | 64 | 페이지 상단 여백 |

## 6. Layout

- **Approach**: grid-disciplined (관리 도구 정체성)
- **Grid**: 12 col, 페이지 max-w `1440px`
- **Breakpoints**: `sm 640` · `md 768` · `lg 1024` · `xl 1280` · `2xl 1536`
- **Sidebar**: **`w-64`(256px) 고정**, 다크에서는 `stone-900` · _[D-02 · 2026-04-21] w-60(240px)에서 변경. 한국어 네비 레이블·서브메뉴 7개 폭 수요 및 Vercel/shadcn 실무 표준(256px) 부합_
- **Page padding**: `px-6 py-8`

## 7. Border Radius — 계층화 (AI slop 방지 핵심)

전체 요소에 동일 radius 금지. 크기별 역할 구분.

| Token | px | Usage |
|-------|----|----|
| `--radius-sm` | 4 | Badge(기본) · 작은 칩 · 인라인 인디케이터 |
| `--radius-md` | 8 | **Input · Button · Card · Dropdown** |
| `--radius-lg` | 12 | Modal · Popover · Hero Card |
| `--radius-xl` | 16 | KPI Hero Card |
| `--radius-full` | 9999 | Avatar · Pill 변형 Badge |

### 7.1 Input radius 기준 · [D-01 · 2026-04-21]

- Input은 `radius-md`(8px) 사용. 초안 v1.0의 `radius-sm`(4px)에서 변경.
- 근거: shadcn/ui 기본값 `rounded-md`, Linear/Vercel/Stripe Dashboard 실무 대역 6~8px. 4px은 샤프해서 현대 UI 트렌드에서 이탈. Button/Card와 동일 계층으로 시각 일관성 확보.
- 실제 `Frontend/admin/src/components/ui/input.tsx`는 이미 `rounded-md`로 구현되어 있어 코드 변경 없음.

### 7.2 Badge radius 이원화 · [2026-04-21]

- **기본 Badge**: `radius-sm`(4px). 상태/카테고리/숫자 표기.
- **Pill 변형 Badge**: `radius-full`. 필터 태그, 사용자 역할 라벨 등 부유감이 필요한 경우.
- 현 `ui/badge.tsx`는 전량 `rounded-full` 사용 중 → Phase 1-C 코드 수정에서 `pill?: boolean` prop 추가 또는 variant 분기로 이원화.

## 8. Motion

- **Approach**: minimal-functional. 관리자 툴에는 과한 모션 금물.
- **Easing**: enter `ease-out`, exit `ease-in`, move `ease-in-out`
- **Duration**:
  - micro (focus ring, hover): 100ms
  - short (tooltip, dropdown): 180ms
  - medium (modal, drawer): 240ms
  - long (page transition): 적용 안 함

## 9. Shadow

| Token | Usage |
|-------|-------|
| `shadow-xs` | 버튼 hover 정도 (`0 1px 2px 0 rgb(0 0 0 / 0.05)`) |
| `shadow-sm` | Card 기본 |
| `shadow-md` | Dropdown · Popover |
| `shadow-lg` | Modal |

다크 모드에서는 `shadow-md` 이상을 `ring-1 ring-border` 로 대체해 탁한 그림자 대신 테두리로 분리감 확보.

## 10. AI Slop 금지 체크리스트

다음 패턴 **금지**:

- ❌ 보라/바이올렛 그라데이션 (Ember 컬러 시스템 외)
- ❌ 3칸 아이콘 그리드 (컬러 원 안에 아이콘)
- ❌ 모든 요소에 동일 radius (계층 무시)
- ❌ "✨ AI Powered" 류 이모지 남발 배지
- ❌ 센터 얼라인 히어로 + 과한 whitespace (관리자 툴에 부적합)
- ❌ 그라데이션 CTA 버튼
- ❌ Inter/Roboto/System default 폰트
- ❌ 순수 slate-900 차가운 다크 (cool-black)

## 11. Components — 우선 적용 대상

1. **KPI Card** — Instrument Serif 큰 숫자, Pretendard 레이블, tabular-nums
   - **variant 명세** [2026-04-21 추가]
     - `hero` (첫 줄 핵심 4장): `rounded-xl` (16px) · `shadow-md` · `p-8` · 숫자 `text-display`(64px)
     - `compact` (보조 2열 그리드): `rounded-lg` (12px) · `shadow-sm` · `p-6` · 숫자 `text-4xl`(48px)
   - 공통: 숫자는 `.kpi-number` class + `tabular-nums`, 레이블 `text-xs uppercase tracking-wider text-muted-foreground`
2. **Page Header** — 좌측 타이틀(Pretendard 2xl/700) + 우측 액션 영역, 하단 1px border
3. **Data Table** — JetBrains Mono 숫자 컬럼, 호버 시 `bg-muted/50`, SLA 뱃지 색상 계층
4. **Status Badge** — 4단계 계층 (outline / soft / solid / destructive), 세만틱 토큰 기반 (`bg-success/10 text-success` 등 — Tailwind 팔레트 하드코딩 금지)
5. **Sidebar Nav** — 좌측 orange active indicator(4px 세로 막대) + accent 배경, 폭 `w-64`(§6 참조)
6. **Theme Toggle** — 헤더 우측, light/dark/system 3-way

## 12. Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-04-20 | Ember Signal 팔레트 확정 | `/design-consultation` Q1 사용자 선택, 브랜드 DNA 직결·차별화 최대 |
| 2026-04-20 | Instrument Serif RISK 채택 | KPI 숫자·Hero에만 세리프, AI slop 제거 장치 |
| 2026-04-20 | Pretendard 전면 적용 | Inter 제거, 한국어 제품 사실상 표준 |
| 2026-04-20 | Warm stone 베이스 채택 | 일반 slate(cool) 대신 stone(warm), 장시간 시청 눈 피로도 |
| 2026-04-20 | Radius 계층화 | sm4 / md8 / lg12 / xl16 / full — 동일 radius 금지 규칙 |
| **2026-04-21** | **[D-01] Input radius `sm`→`md`** | shadcn/Linear/Vercel 실무 표준 6~8px. Button/Card와 통일. 코드는 기존에도 `rounded-md`라 변경 없음 |
| **2026-04-21** | **[D-02] Sidebar 폭 `w-60`→`w-64`** | 한국어 레이블·서브메뉴 7개 폭 수요. Vercel/shadcn 256px 부합. 코드는 기존에도 `w-64`라 변경 없음 |
| **2026-04-21** | **Badge radius 이원화 (sm 기본 / full pill 변형)** | 현 `rounded-full` 전량 사용과 §7 sm 명시의 충돌 해소. 상태 Badge=sm, 태그/역할 라벨=full |
| **2026-04-21** | **KPI Card variant 2종(hero/compact) 명시** | 대시보드 첫 줄과 보조 그리드 시각 밀도 분리. hero는 radius-xl+shadow-md+display64, compact는 radius-lg+shadow-sm+4xl48 |

---

## Appendix A. Claude Code / Gstack 연동

이 파일은 `/design-consultation` 결과물이며 이후 `/design-review` · `/qa` · 모든 UI 작업의 **단일 진실 소스(Single Source of Truth)** 다. 모든 신규 컴포넌트는 이 토큰을 따르고, 위반 시 `/design-review` 에서 플래그.

`CLAUDE.md` 에 "항상 `DESIGN.md`를 먼저 읽고 UI 작업" 규칙이 추가되어 있음.
