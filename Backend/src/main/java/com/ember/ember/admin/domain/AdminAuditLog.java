package com.ember.ember.admin.domain;

import jakarta.persistence.*;
import lombok.*;

import java.time.LocalDateTime;

@Entity
@Table(name = "admin_audit_logs")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AdminAuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "admin_id", nullable = false)
    private AdminAccount admin;

    @Column(nullable = false, length = 100)
    private String action;

    @Column(name = "target_type", length = 30)
    private String targetType;

    @Column(name = "target_id")
    private Long targetId;

    @Column(columnDefinition = "TEXT")
    private String detail;

    @Column(name = "ip_address", length = 45)
    private String ipAddress;

    @Column(name = "performed_at", nullable = false)
    private LocalDateTime performedAt;

    /**
     * AOP에서 감사 로그를 생성할 때 사용하는 static 팩터리 메서드.
     * admin은 {@code EntityManager.getReferenceById()}로 얻은 proxy를 그대로 전달하여 추가 쿼리를 방지한다.
     *
     * @param admin      행위를 수행한 관리자 (proxy 가능)
     * @param action     감사 action 코드 (예: "REPORT_PROCESS")
     * @param targetType 대상 엔티티 타입 (예: "REPORT"), 없으면 null
     * @param targetId   대상 엔티티 id, 없으면 null
     * @param detail     추가 설명, 없으면 null
     * @param ipAddress  요청 IP 주소, 없으면 null
     */
    public static AdminAuditLog of(AdminAccount admin, String action, String targetType,
                                    Long targetId, String detail, String ipAddress) {
        AdminAuditLog log = new AdminAuditLog();
        log.admin = admin;
        log.action = action;
        log.targetType = targetType;
        log.targetId = targetId;
        log.detail = detail;
        log.ipAddress = ipAddress;
        log.performedAt = java.time.LocalDateTime.now();
        return log;
    }
}
