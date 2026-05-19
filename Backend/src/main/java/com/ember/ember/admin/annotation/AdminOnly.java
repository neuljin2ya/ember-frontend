package com.ember.ember.admin.annotation;

import org.springframework.security.access.prepost.PreAuthorize;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 관리자 전체(VIEWER 포함) 접근 허용.
 * VIEWER, ADMIN, SUPER_ADMIN 세 역할 모두 허용하는 메타 어노테이션.
 * 읽기 전용 조회 API에 적용한다.
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@PreAuthorize("hasAnyRole('VIEWER','ADMIN','SUPER_ADMIN')")
public @interface AdminOnly {
}
