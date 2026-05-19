package com.ember.ember.notification.domain;

import com.ember.ember.user.domain.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "user_notice_reads",
        uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "notice_id"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class UserNoticeRead {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "notice_id", nullable = false)
    private Notice notice;

    @Column(name = "read_at", nullable = false)
    private LocalDateTime readAt;
}
