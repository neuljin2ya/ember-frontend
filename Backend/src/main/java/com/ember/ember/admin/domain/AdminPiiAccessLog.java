package com.ember.ember.admin.domain;

import com.ember.ember.user.domain.User;
import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "admin_pii_access_log")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AdminPiiAccessLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "admin_id", nullable = false)
    private AdminAccount admin;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "target_user_id", nullable = false)
    private User targetUser;

    @Column(name = "access_type", nullable = false, length = 30)
    private String accessType;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "accessed_at", nullable = false)
    private LocalDateTime accessedAt;

    /**
     * AOP에서 PII 접근 로그를 생성할 때 사용하는 static 팩터리 메서드.
     * admin, targetUser 모두 {@code EntityManager.getReferenceById()} proxy를 전달하여 추가 쿼리를 방지한다.
     *
     * @param admin      PII를 조회한 관리자 (proxy 가능)
     * @param targetUser PII 조회 대상 사용자 (proxy 가능)
     * @param accessType 접근 타입 (예: "EMAIL_VIEW", "REAL_NAME_VIEW")
     * @param ipAddress  요청 IP 주소, 없으면 null
     */
    public static AdminPiiAccessLog of(AdminAccount admin, com.ember.ember.user.domain.User targetUser,
                                        String accessType, String ipAddress) {
        AdminPiiAccessLog log = new AdminPiiAccessLog();
        log.admin = admin;
        log.targetUser = targetUser;
        log.accessType = accessType;
        log.ipAddress = ipAddress;
        log.accessedAt = java.time.LocalDateTime.now();
        return log;
    }
}
