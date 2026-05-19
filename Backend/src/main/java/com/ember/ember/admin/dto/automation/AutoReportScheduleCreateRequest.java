package com.ember.ember.admin.dto.automation;

import com.ember.ember.admin.domain.automation.AutoReportSchedule.ReportType;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record AutoReportScheduleCreateRequest(
        @NotBlank String name,
        String description,
        @NotNull ReportType reportType,
        @NotBlank String cronExpression
) {
}
