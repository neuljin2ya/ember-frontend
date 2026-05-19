package com.ember.ember.admin.annotation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * PII(개인식별정보) 접근 감사 로그를 AOP로 자동 기록하기 위한 어노테이션.
 * {@code PiiAccessAspect}가 이 어노테이션이 붙은 메서드 실행 <b>전</b>에
 * {@code admin_pii_access_log} 테이블에 로그를 저장한다 (Fail-Closed).
 * 로그 저장 실패 시 메서드 실행 자체가 차단된다.
 *
 * <pre>{@code
 * @AdminOnly
 * @PiiAccess(accessType = "EMAIL_VIEW", targetUserIdParam = "userId")
 * public UserPiiResponse getUserPii(Long userId) { ... }
 * }</pre>
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface PiiAccess {

    /**
     * PII 접근 타입.
     * 예: "EMAIL_VIEW", "REAL_NAME_VIEW", "PHONE_VIEW"
     */
    String accessType();

    /**
     * 대상 사용자 id를 담은 메서드 파라미터 이름.
     * 예: "targetUserId", "userId"
     */
    String targetUserIdParam();
}
