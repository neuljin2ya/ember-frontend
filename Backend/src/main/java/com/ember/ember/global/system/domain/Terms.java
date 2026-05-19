package com.ember.ember.global.system.domain;

import com.ember.ember.global.jpa.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "terms",
        uniqueConstraints = @UniqueConstraint(columnNames = {"type", "version"}))
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Terms extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 30)
    @Enumerated(EnumType.STRING)
    private TermsType type;

    @Column(nullable = false, length = 10)
    private String version;

    @Column(nullable = false, length = 100)
    private String title;

    @Column(nullable = false, columnDefinition = "TEXT")
    private String content;

    @Column(nullable = false, length = 15)
    @Enumerated(EnumType.STRING)
    private TermsStatus status = TermsStatus.ACTIVE;

    @Column(name = "effective_at", nullable = false)
    private LocalDateTime effectiveAt;

    @Column(name = "accept_count", nullable = false)
    private Integer acceptCount = 0;

    public enum TermsType {
        SERVICE, PRIVACY, LOCATION, MARKETING, AI_ANALYSIS
    }

    public enum TermsStatus {
        ACTIVE, DRAFT, ARCHIVED
    }
}
