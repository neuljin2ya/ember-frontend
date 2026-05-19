package com.ember.ember.idealtype.domain;

import com.ember.ember.user.domain.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "keyword_change_history")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class KeywordChangeHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "before_keyword_ids", nullable = false, columnDefinition = "TEXT")
    private String beforeKeywordIds;

    @Column(name = "after_keyword_ids", nullable = false, columnDefinition = "TEXT")
    private String afterKeywordIds;

    @Column(name = "changed_at", nullable = false)
    private LocalDateTime changedAt;
}
