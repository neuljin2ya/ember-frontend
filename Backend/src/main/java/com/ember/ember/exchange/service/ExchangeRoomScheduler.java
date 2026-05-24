package com.ember.ember.exchange.service;

import com.ember.ember.exchange.domain.ExchangeRoom;
import com.ember.ember.exchange.repository.ExchangeRoomRepository;
import com.ember.ember.global.notification.FcmService;
import com.ember.ember.notification.domain.Notification;
import com.ember.ember.notification.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 교환일기 방 만료 처리 스케줄러 (10분 주기)
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ExchangeRoomScheduler {

    private final ExchangeRoomRepository exchangeRoomRepository;
    private final NotificationRepository notificationRepository;
    private final FcmService fcmService;

    /** 만료 대상 교환방 처리 (5초 버퍼) */
    @Scheduled(fixedRate = 600_000) // 10분
    @Transactional
    public void expireOverdueRooms() {
        LocalDateTime cutoff = LocalDateTime.now().minusSeconds(5);
        List<ExchangeRoom> expiredRooms = exchangeRoomRepository.findExpiredRooms(cutoff);

        for (ExchangeRoom room : expiredRooms) {
            room.expire();

            // 양측에 만료 알림
            sendExpireNotification(room, room.getUserA());
            sendExpireNotification(room, room.getUserB());

            log.info("[ExchangeRoomScheduler] 교환방 만료 — roomId={}", room.getId());
        }

        if (!expiredRooms.isEmpty()) {
            log.info("[ExchangeRoomScheduler] 만료 처리 완료 — {}건", expiredRooms.size());
        }
    }

    private void sendExpireNotification(ExchangeRoom room, com.ember.ember.user.domain.User user) {
        Notification notification = Notification.create(user, "EXCHANGE_EXPIRED",
                "교환일기 시간이 종료되었습니다.",
                "교환일기 작성 기한이 만료되었습니다.",
                "/exchange-rooms/" + room.getId());
        notificationRepository.save(notification);
        fcmService.sendPushToUser(user.getId(),
                "교환일기 시간이 종료되었습니다.",
                "교환일기 작성 기한이 만료되었습니다.");
    }
}
