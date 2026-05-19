package com.ember.ember.exchange.domain;

import com.ember.ember.chat.domain.ChatRoom;
import com.ember.ember.global.jpa.entity.BaseEntity;
import com.ember.ember.matching.domain.Matching;
import com.ember.ember.user.domain.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "exchange_rooms")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ExchangeRoom extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "room_uuid", nullable = false, unique = true, updatable = false)
    private UUID roomUuid;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_a_id", nullable = false)
    private User userA;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_b_id", nullable = false)
    private User userB;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "matching_id", nullable = false)
    private Matching matching;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "current_turn_user_id", nullable = false)
    private User currentTurnUser;

    @Column(name = "turn_count", nullable = false)
    private Integer turnCount = 0;

    @Column(name = "round_count", nullable = false)
    private Integer roundCount = 1;

    @Column(nullable = false, length = 15)
    @Enumerated(EnumType.STRING)
    private RoomStatus status = RoomStatus.ACTIVE;

    @Column(name = "deadline_at", nullable = false)
    private LocalDateTime deadlineAt;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chat_room_id")
    private ChatRoom chatRoom;

    @PrePersist
    private void generateUuid() {
        if (this.roomUuid == null) {
            this.roomUuid = UUID.randomUUID();
        }
    }

    public enum RoomStatus {
        ACTIVE, EXPIRED, COMPLETED, TERMINATED, ARCHIVED, CHAT_CONNECTED, ENDED
    }

    /** 다음 단계 선택 기한 (72시간) */
    @Column(name = "next_step_deadline_at")
    private LocalDateTime nextStepDeadlineAt;

    /** 매칭 성사 시 교환일기 방 생성 */
    public static ExchangeRoom create(User userA, User userB, Matching matching) {
        ExchangeRoom room = new ExchangeRoom();
        room.userA = userA;
        room.userB = userB;
        room.matching = matching;
        room.currentTurnUser = userA;
        room.turnCount = 0;
        room.roundCount = 1;
        room.status = RoomStatus.ACTIVE;
        room.deadlineAt = LocalDateTime.now().plusHours(48);
        return room;
    }

    /** 참여자인지 확인 */
    public boolean isParticipant(Long userId) {
        return userA.getId().equals(userId) || userB.getId().equals(userId);
    }

    /** 상대방 조회 */
    public User getPartner(Long userId) {
        return userA.getId().equals(userId) ? userB : userA;
    }

    /** 턴 진행 (일기 작성 완료 시) */
    public void advanceTurn() {
        this.turnCount += 1;
        int maxTurns = (this.roundCount == 1) ? 4 : 2; // 라운드1: 4턴, 라운드2(추가): 2턴
        if (this.turnCount >= maxTurns) {
            this.status = RoomStatus.COMPLETED;
            this.nextStepDeadlineAt = LocalDateTime.now().plusHours(72);
        } else {
            this.currentTurnUser = getPartner(this.currentTurnUser.getId());
            this.deadlineAt = LocalDateTime.now().plusHours(48);
        }
    }

    /** 만료 처리 */
    public void expire() {
        this.status = RoomStatus.EXPIRED;
    }

    /** 채팅방 연결 */
    public void connectChat(ChatRoom chatRoom) {
        this.chatRoom = chatRoom;
        this.status = RoomStatus.CHAT_CONNECTED;
    }

    /** 추가 1턴 연장 (라운드 2) */
    public void extendRound() {
        this.roundCount = 2;
        this.turnCount = 0;
        this.status = RoomStatus.ACTIVE;
        this.deadlineAt = LocalDateTime.now().plusHours(48);
        this.nextStepDeadlineAt = null;
    }

    /** 아카이브 처리 (매칭 종료) */
    public void archive() {
        this.status = RoomStatus.ARCHIVED;
    }

    /** 종료 처리 (차단/탈퇴) */
    public void terminate() {
        this.status = RoomStatus.TERMINATED;
    }
}
