package com.ember.ember.global.system.domain;

import com.ember.ember.admin.domain.AdminAccount;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "terms_history")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TermsHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "term_id", nullable = false)
    private Terms term;

    @Column(name = "changed_field", nullable = false, length = 50)
    private String changedField;

    @Column(name = "before_value", columnDefinition = "TEXT")
    private String beforeValue;

    @Column(name = "after_value", columnDefinition = "TEXT")
    private String afterValue;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "changed_by", nullable = false)
    private AdminAccount changedBy;

    @Column(name = "changed_at", nullable = false)
    private LocalDateTime changedAt;
}
