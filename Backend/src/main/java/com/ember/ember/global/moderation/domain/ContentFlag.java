package com.ember.ember.global.moderation.domain;

import com.ember.ember.user.domain.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "content_flags",
        indexes = @Index(name = "idx_content_flags_user_flagged", columnList = "user_id, flagged_at"))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ContentFlag {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "content_type", nullable = false, length = 10)
    private String contentType;

    @Column(name = "content_id", nullable = false)
    private Long contentId;

    @Column(name = "violation_category", nullable = false, length = 15)
    @Enumerated(EnumType.STRING)
    private ViolationCategory violationCategory;

    @Column(name = "detected_keyword", length = 100)
    private String detectedKeyword;

    @Column(name = "flagged_at", nullable = false)
    private LocalDateTime flaggedAt;

    public enum ViolationCategory {
        PROFANITY, VIOLENCE, HARASSMENT, CONTACT, URL
    }
}
