package com.ember.ember.global.config;

import com.ember.ember.global.security.jwt.JwtTokenProvider;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Component;

/**
 * WebSocket STOMP 연결 시 JWT 인증 처리
 * - CONNECT 프레임의 Authorization 헤더에서 Bearer 토큰 추출
 * - 유효한 토큰이면 Authentication 객체를 세션에 설정
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class WebSocketAuthInterceptor implements ChannelInterceptor {

    private final JwtTokenProvider jwtTokenProvider;

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null) return message;

        if (StompCommand.CONNECT.equals(accessor.getCommand())) {
            String authHeader = accessor.getFirstNativeHeader("Authorization");
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                log.warn("[WebSocket] CONNECT 시 Authorization 헤더 없음");
                throw new IllegalArgumentException("WebSocket 연결에 인증 토큰이 필요합니다.");
            }

            String token = authHeader.substring(7);
            if (!jwtTokenProvider.validateToken(token)) {
                log.warn("[WebSocket] 유효하지 않은 토큰으로 CONNECT 시도");
                throw new IllegalArgumentException("유효하지 않은 인증 토큰입니다.");
            }

            Authentication auth = jwtTokenProvider.getAuthentication(token);
            accessor.setUser(auth);
            log.debug("[WebSocket] 인증 성공 — userId={}", jwtTokenProvider.getUserIdFromToken(token));
        }

        return message;
    }
}
