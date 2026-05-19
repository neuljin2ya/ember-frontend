package com.ember.ember.chat.controller;

import com.ember.ember.chat.dto.ChatMessageRequest;
import com.ember.ember.chat.dto.ChatMessageResponse;
import com.ember.ember.chat.service.ChatService;
import com.ember.ember.global.security.CustomUserDetails;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.stereotype.Controller;

import java.security.Principal;

/**
 * WebSocket STOMP 채팅 컨트롤러
 */
@Slf4j
@Controller
@RequiredArgsConstructor
public class ChatWebSocketController {

    private final ChatService chatService;
    private final SimpMessagingTemplate messagingTemplate;

    /** 메시지 전송: /app/chat/{roomId} → /topic/chat/{roomId} */
    @MessageMapping("/chat/{roomId}")
    public void sendMessage(@DestinationVariable Long roomId,
                            @Payload ChatMessageRequest request,
                            Principal principal) {
        Long userId = extractUserId(principal);
        ChatMessageResponse response = chatService.sendMessage(userId, roomId, request);

        // 구독자에게 브로드캐스트
        messagingTemplate.convertAndSend("/topic/chat/" + roomId, response);
    }

    /** 읽음 처리: /app/chat/{roomId}/read */
    @MessageMapping("/chat/{roomId}/read")
    public void markRead(@DestinationVariable Long roomId, Principal principal) {
        Long userId = extractUserId(principal);
        chatService.markRead(userId, roomId);

        // 읽음 상태 브로드캐스트
        messagingTemplate.convertAndSend("/topic/chat/" + roomId + "/read",
                java.util.Map.of("userId", userId, "roomId", roomId));
    }

    private Long extractUserId(Principal principal) {
        if (principal instanceof org.springframework.security.authentication.UsernamePasswordAuthenticationToken auth) {
            if (auth.getPrincipal() instanceof CustomUserDetails details) {
                return details.getUserId();
            }
        }
        throw new IllegalStateException("인증 정보를 추출할 수 없습니다.");
    }
}
