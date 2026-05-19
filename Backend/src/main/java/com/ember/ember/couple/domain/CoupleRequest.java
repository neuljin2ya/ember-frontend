package com.ember.ember.couple.domain;

import com.ember.ember.chat.domain.ChatRoom;
import com.ember.ember.global.jpa.entity.BaseEntity;
import com.ember.ember.user.domain.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "couple_requests")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class CoupleRequest extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chat_room_id", nullable = false)
    private ChatRoom chatRoom;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "requester_id", nullable = false)
    private User requester;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "receiver_id", nullable = false)
    private User receiver;

    @Column(nullable = false, length = 15)
    @Enumerated(EnumType.STRING)
    private CoupleRequestStatus status = CoupleRequestStatus.PENDING;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(name = "last_reminder_at")
    private LocalDateTime lastReminderAt;

    @Column(name = "reminder_count", nullable = false)
    private Short reminderCount = 0;

    public enum CoupleRequestStatus {
        PENDING, ACCEPTED, REJECTED, EXPIRED, CANCELLED
    }

    /** 커플 요청 생성 */
    public static CoupleRequest create(ChatRoom chatRoom, User requester, User receiver) {
        CoupleRequest req = new CoupleRequest();
        req.chatRoom = chatRoom;
        req.requester = requester;
        req.receiver = receiver;
        req.status = CoupleRequestStatus.PENDING;
        req.expiresAt = LocalDateTime.now().plusHours(72);
        req.reminderCount = 0;
        return req;
    }

    /** 수락 */
    public void accept() {
        this.status = CoupleRequestStatus.ACCEPTED;
    }

    /** 거절 */
    public void reject() {
        this.status = CoupleRequestStatus.REJECTED;
    }

    /** 만료 */
    public void expire() {
        this.status = CoupleRequestStatus.EXPIRED;
    }

    /** 만료 확인 */
    public boolean isExpired() {
        return LocalDateTime.now().isAfter(this.expiresAt);
    }
}
