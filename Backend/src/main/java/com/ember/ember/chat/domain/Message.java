package com.ember.ember.chat.domain;

import com.ember.ember.global.jpa.entity.BaseEntity;
import com.ember.ember.user.domain.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "messages",
        indexes = @Index(name = "idx_messages_room_seq", columnList = "chat_room_id, sequence_id"))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Message extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "chat_room_id", nullable = false)
    private ChatRoom chatRoom;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "sender_id")
    private User sender;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(nullable = false, length = 10)
    @Enumerated(EnumType.STRING)
    private MessageType type = MessageType.TEXT;

    @Column(name = "sequence_id", nullable = false)
    private Long sequenceId;

    @Column(name = "is_read", nullable = false)
    private Boolean isRead = false;

    @Column(name = "read_at")
    private LocalDateTime readAt;

    @Column(name = "is_flagged", nullable = false)
    private Boolean isFlagged = false;

    public enum MessageType {
        TEXT, EMOJI, SYSTEM
    }

    /** 메시지 생성 */
    public static Message create(ChatRoom chatRoom, User sender, String content,
                                  MessageType type, Long sequenceId) {
        Message msg = new Message();
        msg.chatRoom = chatRoom;
        msg.sender = sender;
        msg.content = content;
        msg.type = type;
        msg.sequenceId = sequenceId;
        return msg;
    }

    /** 시스템 메시지 생성 */
    public static Message createSystem(ChatRoom chatRoom, String content, Long sequenceId) {
        Message msg = new Message();
        msg.chatRoom = chatRoom;
        msg.sender = null;
        msg.content = content;
        msg.type = MessageType.SYSTEM;
        msg.sequenceId = sequenceId;
        return msg;
    }

    /** 읽음 처리 */
    public void markRead() {
        if (!this.isRead) {
            this.isRead = true;
            this.readAt = LocalDateTime.now();
        }
    }

    /** 외부 연락처 플래그 */
    public void flag() {
        this.isFlagged = true;
    }
}
