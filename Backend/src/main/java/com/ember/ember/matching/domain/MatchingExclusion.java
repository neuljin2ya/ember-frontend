package com.ember.ember.matching.domain;

import com.ember.ember.global.jpa.entity.BaseEntity;
import com.ember.ember.user.domain.User;
import jakarta.persistence.*;
import lombok.*;

@Entity
@Table(name = "matching_exclusions",
        uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "excluded_user_id"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class MatchingExclusion extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "excluded_user_id", nullable = false)
    private User excludedUser;

    @Column(nullable = false, length = 30)
    @Enumerated(EnumType.STRING)
    private ExclusionReason reason;

    public enum ExclusionReason {
        BLOCK, CHAT_LEFT, MATCH_ENDED
    }
}
