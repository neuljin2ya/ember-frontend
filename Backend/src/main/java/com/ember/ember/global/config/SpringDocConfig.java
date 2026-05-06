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
@OpenAPIDefinition(info = @Info(
        title = "Ember API 서버",
        version = "v2.1",
        description = """
                ## WebSocket 채팅 (Swagger 외 별도 연결)

                실시간 채팅은 REST가 아닌 **WebSocket STOMP** 프로토콜을 사용합니다.

                ### 연결 정보
                - **엔드포인트**: `wss://ember-app.duckdns.org/ws/chat` (SockJS)
                - **인증**: 연결 시 STOMP 헤더에 `Authorization: Bearer {accessToken}` 포함

                ### 메시지 전송
                - **Destination**: `/app/chat/{roomId}`
                - **Body**: `{ "content": "메시지 내용", "type": "TEXT" }`

                ### 메시지 수신 (구독)
                - **Subscribe**: `/topic/chat/{roomId}`
                - **응답**: `{ "messageId", "senderId", "content", "type", "sequenceId", "createdAt" }`

                ### 읽음 처리
                - **Destination**: `/app/chat/{roomId}/read`
                - **Body**: `{ "lastReadSequenceId": 10 }`

                ### Flutter 예시 (stomp_dart_client)
                ```dart
                final client = StompClient(
                  config: StompConfig.sockJS(
                    url: 'https://ember-app.duckdns.org/ws/chat',
                    stompConnectHeaders: {'Authorization': 'Bearer $token'},
                  ),
                );
                client.activate();
                // 구독
                client.subscribe(destination: '/topic/chat/$roomId', callback: (frame) { ... });
                // 전송
                client.send(destination: '/app/chat/$roomId', body: jsonEncode({...}));
                ```

                > **참고**: 메시지 전송은 `POST /api/chat-rooms/{roomId}/messages` REST API로도 가능합니다 (테스트용).
                """
))
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
