package com.ember.ember.admin.dto.automation;

import com.ember.ember.admin.domain.automation.AutoReportSchedule;
import com.ember.ember.admin.domain.automation.AutoReportSchedule.ReportType;

import java.time.LocalDateTime;

public record AutoReportScheduleResponse(
        Long id,
        String name,
        String description,
        ReportType reportType,
        String cronExpression,
        boolean enabled,
        int executionCount,
        LocalDateTime lastExecutedAt,
        LocalDateTime createdAt
) {
    public static AutoReportScheduleResponse from(AutoReportSchedule schedule) {
        return new AutoReportScheduleResponse(
                schedule.getId(),
                schedule.getName(),
                schedule.getDescription(),
                schedule.getReportType(),
                schedule.getCronExpression(),
                schedule.isEnabled(),
                schedule.getExecutionCount(),
                schedule.getLastExecutedAt(),
                schedule.getCreatedAt()
        );
    }
}
