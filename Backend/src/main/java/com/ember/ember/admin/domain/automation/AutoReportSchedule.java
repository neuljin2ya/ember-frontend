package com.ember.ember.admin.domain.automation;

import com.ember.ember.global.jpa.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 자동 리포트 스케줄 — 주기적으로 리포트를 자동 생성하는 스케줄 설정.
 */
@Entity
@Table(name = "auto_report_schedules")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class AutoReportSchedule extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(length = 500)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "report_type", nullable = false, length = 30)
    private ReportType reportType;

    @Column(name = "cron_expression", nullable = false, length = 50)
    private String cronExpression;

    @Column(nullable = false)
    private boolean enabled;

    @Column(name = "execution_count", nullable = false)
    private int executionCount;

    @Column(name = "last_executed_at")
    private LocalDateTime lastExecutedAt;

    public enum ReportType {
        USER_ANALYTICS,
        MATCHING_PERFORMANCE,
        OPERATIONS_SUMMARY,
        DIARY_STATISTICS,
        RETENTION_ANALYSIS
    }

    public static AutoReportSchedule create(String name, String description,
                                             ReportType reportType, String cronExpression) {
        AutoReportSchedule schedule = new AutoReportSchedule();
        schedule.name = name;
        schedule.description = description;
        schedule.reportType = reportType;
        schedule.cronExpression = cronExpression;
        schedule.enabled = true;
        schedule.executionCount = 0;
        return schedule;
    }

    public void toggle() {
        this.enabled = !this.enabled;
    }

    public void markExecuted() {
        this.executionCount++;
        this.lastExecutedAt = LocalDateTime.now();
    }
}
