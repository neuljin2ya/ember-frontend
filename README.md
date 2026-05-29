# Ember Frontend

Ember 사용자 앱 프론트엔드입니다. Flutter로 개발되었고 Android APK 및 iOS 실행을 지원합니다.

## 레포지토리 전체 구조

Ember는 교환일기 기반 소개팅 앱이며, 사용자 앱만이 아니라 백엔드, AI 서버, 관리자 대시보드가 함께 동작하는 구조입니다. 발표 준비나 코드 리뷰를 할 때는 아래 순서로 보면 전체 흐름을 빠르게 잡을 수 있습니다.

| 영역 | 위치 | 역할 | 발표 시 어필 포인트 |
|---|---|---|---|
| 사용자 앱 | `lib/`, `android/`, `ios/`, `assets/` | Flutter 기반 모바일 앱. 온보딩, 일기 작성, AI 분석 결과, 매칭, 교환일기, 채팅, 알림, 마이페이지를 담당합니다. | 단순 스와이프형 소개팅이 아니라 일기와 상호작용 이력을 기반으로 관계를 점진적으로 여는 UX입니다. |
| 관리자 웹 | `Frontend/admin/` | Next.js 14 기반 운영 대시보드. 회원, 신고, 콘텐츠, AI 모니터링, 분석, 시스템 관리 화면을 담당합니다. | 발표 심사에서 "운영 가능성"과 "신뢰 확보 장치"를 보여주는 핵심 화면입니다. |
| 백엔드 | `Backend/` | Spring Boot 3.x 기반 API 서버. 인증, 회원, 일기, 매칭, 신고, 관리자, AI 연동, MQ/Outbox, 마이그레이션을 담당합니다. | 안전성, 확장성, 장애 격리, 데이터 정합성을 방어하는 근거 코드가 모여 있습니다. |
| AI 서버 | `ai/` | FastAPI 기반 분석 서버. KcELECTRA, KoSimCSE, 콘텐츠 스캔, 매칭 보조, MQ 소비자를 담당합니다. | "AI를 붙였다"가 아니라 모델 역할과 비동기 파이프라인을 분리했다는 점을 설명할 수 있습니다. |
| 로컬 명세서 | `docs/` | API, ERD, 기능명세, 발표 대비 HTML 등 로컬 전용 문서입니다. `.gitignore` 대상이므로 협업 레포에는 푸시하지 않습니다. | 심층 질의 시 명세와 코드 위치를 함께 제시하는 근거 창고입니다. |

## 발표 대비 자료

백엔드 팀 발표 지원용 대시보드는 로컬 전용 HTML로 관리합니다.

- 파일: `docs/html/발표_대비_대시보드_백엔드팀_v1.0.html`
- 성격: 발표 어필 포인트, 경쟁 서비스 벤치마킹, 구현 근거, 100개 예상 공격 질문/방어 답변을 한 화면에 묶은 고밀도 자료
- 주의: `docs/`는 로컬 전용 폴더이므로 PR에 포함되지 않습니다. 발표 전에는 로컬 파일을 브라우저로 열어 사용합니다.

## 제출 구성

- Flutter 전체 소스코드
  - `lib/`
  - `android/`
  - `ios/`
  - `assets/`
  - `pubspec.yaml`
  - `pubspec.lock`
- Android 릴리즈 APK
  - `build/app/outputs/flutter-apk/app-release.apk`
- 실행 및 빌드 방법
  - 이 `README.md` 문서 참고

## 프로젝트 위치

현재 Flutter 프로젝트 루트는 이 레포지토리의 루트입니다.

```bash
<프로젝트-루트>
```

중요: Android/iOS 빌드는 `Frontend/` 폴더가 아니라 프로젝트 루트에서 실행합니다.

## 개발 환경

- Flutter 3.x
- Dart
- Android Studio 또는 Xcode
- Android SDK
- iOS 실행 시 Xcode 및 Apple 개발자 계정 설정 필요

의존성 설치:

```bash
cd <프로젝트-루트>
flutter pub get
```

## Android 실행

연결된 Android 기기 또는 에뮬레이터 확인:

```bash
flutter devices
```

실행:

```bash
flutter run
```

특정 Android 기기로 실행:

```bash
flutter run -d <device-id>
```

## iOS 실행

연결된 iPhone 또는 iOS Simulator 확인:

```bash
flutter devices
```

실행:

```bash
flutter run
```

특정 iOS 기기로 실행:

```bash
flutter run -d <device-id>
```

## Android APK 빌드

릴리즈 APK 빌드:

```bash
cd <프로젝트-루트>
flutter clean
flutter pub get
flutter build apk --release
```

빌드 성공 시 APK 위치:

```bash
build/app/outputs/flutter-apk/app-release.apk
```

Finder에서 APK 폴더 열기:

```bash
open build/app/outputs/flutter-apk
```

## iOS 빌드

```bash
cd <프로젝트-루트>
flutter clean
flutter pub get
flutter build ios --release
```

iOS 실기기 배포는 Xcode Signing & Capabilities에서 Team, Bundle Identifier, Provisioning 설정이 필요합니다.

## 검증 명령어

정적 분석:

```bash
flutter analyze
```

릴리즈 APK 빌드 확인:

```bash
flutter build apk --release
```

현재 확인된 빌드 결과:

```text
✓ Built build/app/outputs/flutter-apk/app-release.apk
```

## 주요 기능 연동 현황

- 카카오 로그인
- 온보딩 약관 동의
- 프로필 등록
- 이상형 키워드 선택
- 필수 첫 일기 작성
- AI 분석 결과 화면
- 튜토리얼 화면
- 최근 일기 / 추천 일기 / 내 일기 목록
- 일기 상세 및 매칭 신청
- 받은 매칭 요청 목록 및 수락
- 교환일기 방 목록 및 상세
- 채팅방 목록 및 채팅
- 알림 목록
- 마이페이지 / 계정 정보 / 로그아웃 / 회원 탈퇴
- 앱 버전 체크
- FCM 토큰 등록

## API 서버

앱은 기본적으로 운영 API 서버를 사용합니다.

```text
https://ember-app.duckdns.org
```

API 주소는 `lib/api_service.dart`의 `baseUrl`에서 관리합니다.

## APK 공유 방법

빌드 후 아래 파일을 공유하면 됩니다.

```text
build/app/outputs/flutter-apk/app-release.apk
```

APK를 받은 Android 사용자는 파일을 설치해서 테스트할 수 있습니다. 단, 카카오 로그인 테스트를 위해서는 해당 APK의 Android key hash가 카카오 디벨로퍼 콘솔에 등록되어 있어야 합니다.

## 카카오 로그인 주의사항

Android 릴리즈 APK에서 카카오 로그인이 실패하면 보통 key hash 미등록 문제입니다.

릴리즈 APK key hash 확인:

```bash
cd <프로젝트-루트>
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

출력된 인증서 정보의 SHA-1을 기반으로 카카오 디벨로퍼 콘솔의 Android 플랫폼 key hash를 확인해야 합니다.

## 협업 규칙

- `main` 브랜치 직접 커밋 금지
- 작업 시 새 브랜치 생성
- 프론트 작업은 Flutter 루트 프로젝트 기준으로 진행
- 작업 완료 후 PR 생성
- PR에는 작업 내용과 확인한 명령어를 작성

기본 흐름:

```bash
git pull origin main
git checkout -b feature/frontend-작업내용
git add .
git commit -m "fix: 작업 내용"
git push origin feature/frontend-작업내용
gh pr create --base main --head feature/frontend-작업내용
```
