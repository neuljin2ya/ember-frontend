-- =============================================================================
-- V6: 관리자 계정 초기 seed (dev/staging 전용)
-- 작성일: 2026-04-22
-- 변경 내용:
--   - 관리자 API 통합명세서 v2.1 §1.1의 Mock 계정과 동일한 3종 관리자를 seed
--     · super@ember.com  / SUPER_ADMIN / 최고관리자
--     · admin@ember.com  / ADMIN       / 운영관리자
--     · viewer@ember.com / VIEWER      / 읽기전용
--   - 비밀번호 해시는 pgcrypto crypt(plain, gen_salt('bf', 10))로 DB 차원에서 생성
--     → Spring Security BCryptPasswordEncoder와 호환되는 $2a$ 포맷
--
-- 설계 기준 및 근거:
--   1. 이메일 도메인은 @ember.com으로 통일
--      (사유: 프런트엔드 Mock 모드 MOCK_ACCOUNTS와 일치시켜 E2E 테스트 간편화 —
--       관리자 API 통합명세서 v2.1 §1.1 UI 처리 블록 참조)
--   2. 평문 비밀번호 "admin123"은 Mock과 동일하게 설정
--      (사유: 로그인 검증만 하는 초기 단계에서 BE-FE 연동 테스트 시 바로 사용 가능)
--      ※ 로그인 5회 실패 15분 차단 / 비밀번호 강도 검사는 "변경" 시점에만 적용되므로
--         로그인만 하는 seed 계정은 단순 비번으로도 안전하게 검증 가능
--   3. BCrypt strength 10: AdminAuthService.changePassword()와 동일한 cost factor
--   4. 이메일 UNIQUE 제약 충돌 방지를 위해 ON CONFLICT (email) DO NOTHING 사용
--      (재실행 시에도 안전 — 수동 변경 이력 보존)
--   5. prod 프로파일은 application.yml에서 flyway.enabled=false이므로 운영 DB에는
--      절대 실행되지 않음 (실 운영은 별도 시크릿 채널로 최초 계정 배포)
--
-- 주의:
--   - 첫 로그인 후 반드시 /api/v1/admin/auth/password-change로 강한 비밀번호로 교체 필요
--     (강도 규칙: 영대문자 + 영소문자 + 숫자 + 특수문자 — AdminAuthService.isStrongPassword)
-- =============================================================================

-- pgcrypto 확장: Supabase는 기본 활성이나, 로컬 PostgreSQL 환경 안전장치
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO admin_accounts (email, password_hash, name, role, status, created_at, modified_at)
VALUES
    ('super@ember.com',  crypt('admin123', gen_salt('bf', 10)), '최고관리자', 'SUPER_ADMIN', 'ACTIVE', NOW(), NOW()),
    ('admin@ember.com',  crypt('admin123', gen_salt('bf', 10)), '운영관리자', 'ADMIN',       'ACTIVE', NOW(), NOW()),
    ('viewer@ember.com', crypt('admin123', gen_salt('bf', 10)), '읽기전용',   'VIEWER',      'ACTIVE', NOW(), NOW())
ON CONFLICT (email) DO NOTHING;
