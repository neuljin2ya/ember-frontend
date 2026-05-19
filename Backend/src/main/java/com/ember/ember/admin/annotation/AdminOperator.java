package com.ember.ember.admin.annotation;

import org.springframework.security.access.prepost.PreAuthorize;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 운영 관리자 이상(ADMIN/SUPER_ADMIN) 전용.
 * 쓰기·처리 작업(신고 처리, 사용자 제재, 일기 강제 삭제 등)에 적용한다.
 * VIEWER는 접근 불가.
 */
@Target({ElementType.METHOD, ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@PreAuthorize("hasAnyRole('ADMIN','SUPER_ADMIN')")
public @interface AdminOperator {
}
