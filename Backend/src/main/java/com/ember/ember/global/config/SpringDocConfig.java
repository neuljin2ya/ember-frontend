package com.ember.ember.global.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

@Configuration
@OpenAPIDefinition(info = @Info(title = "Ember API 서버", version = "v2.1"))
@SecurityScheme(
        name = "bearerAuth",
        type = SecuritySchemeType.HTTP,
        scheme = "bearer",
        bearerFormat = "JWT"
)
public class SpringDocConfig {

    /**
     * 사용자 API 전체 (관리자/dev 제외) — 모든 환경에서 노출
     */
    @Bean
    public GroupedOpenApi userAllApi() {
        return GroupedOpenApi.builder()
                .group("user-api")
                .pathsToMatch("/api/**")
                .pathsToExclude("/api/admin/**")
                .addOpenApiCustomizer(openApi ->
                        openApi.addSecurityItem(new SecurityRequirement().addList("bearerAuth")))
                .build();
    }

    /**
     * 전체 API — local/dev에서만 노출
     */
    @Bean
    @Profile("!prod")
    public GroupedOpenApi allApi() {
        return GroupedOpenApi.builder()
                .group("all")
                .pathsToMatch("/api/**")
                .addOpenApiCustomizer(openApi ->
                        openApi.addSecurityItem(new SecurityRequirement().addList("bearerAuth")))
                .build();
    }

    @Bean
    @Profile("!prod")
    public GroupedOpenApi authApi() {
        return GroupedOpenApi.builder()
                .group("auth")
                .pathsToMatch("/api/auth/**")
                .build();
    }

    @Bean
    @Profile("!prod")
    public GroupedOpenApi userApi() {
        return GroupedOpenApi.builder()
                .group("user")
                .pathsToMatch("/api/users/**")
                .build();
    }

    @Bean
    @Profile("!prod")
    public GroupedOpenApi adminApi() {
        return GroupedOpenApi.builder()
                .group("admin")
                .pathsToMatch("/api/admin/**")
                .build();
    }
}
