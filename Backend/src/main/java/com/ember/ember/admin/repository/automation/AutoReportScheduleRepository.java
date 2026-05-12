package com.ember.ember.admin.repository.automation;

import com.ember.ember.admin.domain.automation.AutoReportSchedule;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AutoReportScheduleRepository extends JpaRepository<AutoReportSchedule, Long> {
}
