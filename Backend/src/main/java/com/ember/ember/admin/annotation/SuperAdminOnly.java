package com.ember.ember.admin.annotation;

import org.springframework.security.access.prepost.PreAuthorize;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 최고 관리자(SUPER_ADMIN) 전용.
 * 관리자 계정 CRUD, RBAC 변경, 시스템 설정 등
 * 가장 높은 권한이 필요한 작업에만 적용한다.
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@PreAuthorize("hasRole('SUPER_ADMIN')")
public @interface SuperAdminOnly {
}
