package com.ember.ember.couple.service;

import com.ember.ember.chat.domain.ChatRoom;
import com.ember.ember.chat.repository.ChatRoomRepository;
import com.ember.ember.couple.domain.Couple;
import com.ember.ember.couple.domain.CoupleRequest;
import com.ember.ember.couple.domain.CoupleRequest.CoupleRequestStatus;
import com.ember.ember.couple.dto.CoupleAcceptResponse;
import com.ember.ember.couple.dto.CoupleRequestResponse;
import com.ember.ember.couple.repository.CoupleRepository;
import com.ember.ember.couple.repository.CoupleRequestRepository;
import com.ember.ember.global.exception.BusinessException;
import com.ember.ember.global.response.ErrorCode;
import com.ember.ember.notification.domain.Notification;
import com.ember.ember.notification.repository.NotificationRepository;
import com.ember.ember.user.domain.User;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;

/**
 * 커플 서비스 (도메인 8)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CoupleService {

    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

    private final CoupleRepository coupleRepository;
    private final CoupleRequestRepository coupleRequestRepository;
    private final ChatRoomRepository chatRoomRepository;
    private final NotificationRepository notificationRepository;

    /** 7.1 커플 요청 전송 */
    @Transactional
    public CoupleRequestResponse sendCoupleRequest(Long userId, Long chatRoomId) {
        ChatRoom chatRoom = findChatRoomOrThrow(chatRoomId);
        validateChatParticipant(chatRoom, userId);

        // 이미 커플 확정 확인
        if (coupleRepository.existsByChatRoomId(chatRoomId)) {
            throw new BusinessException(ErrorCode.COUPLE_ALREADY_CONFIRMED);
        }

        // 기존 PENDING 확인
        if (coupleRequestRepository.existsByChatRoomIdAndStatus(chatRoomId, CoupleRequestStatus.PENDING)) {
            throw new BusinessException(ErrorCode.COUPLE_REQUEST_ALREADY_SENT);
        }

        User requester = chatRoom.getUserA().getId().equals(userId) ? chatRoom.getUserA() : chatRoom.getUserB();
        User receiver = chatRoom.getPartner(userId);

        CoupleRequest request = CoupleRequest.create(chatRoom, requester, receiver);
        coupleRequestRepository.save(request);

        // 수신자에게 FCM 알림
        Notification notification = Notification.create(receiver, "COUPLE_REQUEST",
                "커플 요청이 도착했어요!",
                requester.getNickname() + "님이 커플 요청을 보냈어요.",
                "/chat-rooms/" + chatRoomId + "/couple");
        notificationRepository.save(notification);

        // 리마인드 스케줄 (24h, 48h)
        LocalDateTime now = LocalDateTime.now();
        List<String> reminderSchedule = List.of(
                now.plusHours(24).format(ISO),
                now.plusHours(48).format(ISO)
        );

        log.info("[CoupleService] 커플 요청 전송 — chatRoomId={}, requesterId={}, receiverId={}",
                chatRoomId, userId, receiver.getId());

        return CoupleRequestResponse.builder()
                .requestId(request.getId())
                .expiresAt(request.getExpiresAt().format(ISO))
                .reminderSchedule(reminderSchedule)
                .build();
    }

    /** 7.2 커플 요청 수락 */
    @Transactional
    public CoupleAcceptResponse acceptCoupleRequest(Long userId, Long chatRoomId) {
        ChatRoom chatRoom = findChatRoomOrThrow(chatRoomId);
        validateChatParticipant(chatRoom, userId);

        CoupleRequest request = coupleRequestRepository
                .findByChatRoomIdAndStatus(chatRoomId, CoupleRequestStatus.PENDING)
                .orElseThrow(() -> new BusinessException(ErrorCode.COUPLE_REQUEST_NOT_FOUND));

        // 수신자만 수락 가능
        if (!request.getReceiver().getId().equals(userId)) {
            throw new BusinessException(ErrorCode.COUPLE_REQUEST_NOT_FOUND);
        }

        // 만료 확인
        if (request.isExpired()) {
            request.expire();
            throw new BusinessException(ErrorCode.COUPLE_REQUEST_EXPIRED);
        }

        // 트랜잭션 내 일괄 처리
        request.accept();

        Couple couple = Couple.create(chatRoom.getUserA(), chatRoom.getUserB(), chatRoom);
        coupleRepository.save(couple);

        chatRoom.confirmCouple();

        // 양측 알림
        Notification notifA = Notification.create(chatRoom.getUserA(), "COUPLE_CONFIRMED",
                "커플이 되었습니다!", "축하합니다! 커플이 확정되었어요.",
                "/chat-rooms/" + chatRoomId);
        Notification notifB = Notification.create(chatRoom.getUserB(), "COUPLE_CONFIRMED",
                "커플이 되었습니다!", "축하합니다! 커플이 확정되었어요.",
                "/chat-rooms/" + chatRoomId);
        notificationRepository.save(notifA);
        notificationRepository.save(notifB);

        log.info("[CoupleService] 커플 확정 — chatRoomId={}, coupleId={}", chatRoomId, couple.getId());

        return CoupleAcceptResponse.builder()
                .coupleId(couple.getId())
                .status("ACCEPTED")
                .build();
    }

    /** 7.3 커플 요청 거절 */
    @Transactional
    public void rejectCoupleRequest(Long userId, Long chatRoomId) {
        ChatRoom chatRoom = findChatRoomOrThrow(chatRoomId);
        validateChatParticipant(chatRoom, userId);

        CoupleRequest request = coupleRequestRepository
                .findByChatRoomIdAndStatus(chatRoomId, CoupleRequestStatus.PENDING)
                .orElseThrow(() -> new BusinessException(ErrorCode.COUPLE_REQUEST_NOT_FOUND));

        if (!request.getReceiver().getId().equals(userId)) {
            throw new BusinessException(ErrorCode.COUPLE_REQUEST_NOT_FOUND);
        }

        request.reject();

        // 요청자에게 알림
        Notification notification = Notification.create(request.getRequester(), "COUPLE_REJECTED",
                "커플 요청이 거절되었습니다.",
                "상대방이 커플 요청을 정중히 거절했습니다.",
                "/chat-rooms/" + chatRoomId);
        notificationRepository.save(notification);

        log.info("[CoupleService] 커플 요청 거절 — chatRoomId={}", chatRoomId);
    }

    // ── Private 헬퍼 ──

    private ChatRoom findChatRoomOrThrow(Long chatRoomId) {
        return chatRoomRepository.findById(chatRoomId)
                .orElseThrow(() -> new BusinessException(ErrorCode.CHATROOM_NOT_FOUND));
    }

    private void validateChatParticipant(ChatRoom room, Long userId) {
        if (!room.isParticipant(userId)) {
            throw new BusinessException(ErrorCode.CHATROOM_NOT_PARTICIPANT);
        }
    }
}
