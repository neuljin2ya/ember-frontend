package com.ember.ember.admin.annotation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 관리자 행위 감사 로그를 AOP로 자동 기록하기 위한 메타데이터 어노테이션.
 * {@code AdminAuditAspect}가 이 어노테이션이 붙은 메서드 실행 성공 후
 * {@code admin_audit_logs} 테이블에 로그를 저장한다.
 *
 * <pre>{@code
 * @AdminOperator
 * @AdminAction(action = "REPORT_PROCESS", targetType = "REPORT", targetIdParam = "reportId")
 * public void processReport(Long reportId, ...) { ... }
 * }</pre>
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface AdminAction {

    /**
     * 감사 로그 action 코드.
     * 예: "REPORT_PROCESS", "USER_SUSPEND", "DIARY_FORCE_DELETE"
     */
    String action();

    /**
     * 대상 엔티티 타입.
     * 예: "USER", "REPORT", "DIARY". 해당 없으면 빈 문자열.
     */
    String targetType() default "";

    /**
     * 대상 엔티티 id를 담은 메서드 파라미터 이름.
     * 예: "userId" — 메서드 파라미터 중 이 이름을 가진 값을 targetId로 기록.
     * 해당 없으면 빈 문자열.
     */
    String targetIdParam() default "";

    /**
     * 정적 설명 문자열 (선택).
     * 동적 값이 필요한 경우는 비워두고 서비스 계층에서 별도 처리한다.
     */
    String detail() default "";
}
