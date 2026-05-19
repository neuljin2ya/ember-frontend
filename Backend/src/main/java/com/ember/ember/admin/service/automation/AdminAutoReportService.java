package com.ember.ember.admin.service.automation;

import com.ember.ember.admin.domain.automation.AutoReportSchedule;
import com.ember.ember.admin.dto.automation.AutoReportScheduleCreateRequest;
import com.ember.ember.admin.dto.automation.AutoReportScheduleResponse;
import com.ember.ember.admin.repository.automation.AutoReportScheduleRepository;
import com.ember.ember.global.exception.BusinessException;
import com.ember.ember.global.response.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminAutoReportService {

    private final AutoReportScheduleRepository autoReportScheduleRepository;

    /** 자동 리포트 스케줄 목록 조회 */
    public List<AutoReportScheduleResponse> getSchedules() {
        return autoReportScheduleRepository.findAll().stream()
                .map(AutoReportScheduleResponse::from)
                .toList();
    }

    /** 자동 리포트 스케줄 생성 */
    @Transactional
    public AutoReportScheduleResponse createSchedule(AutoReportScheduleCreateRequest request) {
        AutoReportSchedule schedule = AutoReportSchedule.create(
                request.name(),
                request.description(),
                request.reportType(),
                request.cronExpression()
        );
        autoReportScheduleRepository.save(schedule);
        return AutoReportScheduleResponse.from(schedule);
    }

    /** 자동 리포트 스케줄 활성/비활성 토글 */
    @Transactional
    public AutoReportScheduleResponse toggleSchedule(Long scheduleId) {
        AutoReportSchedule schedule = autoReportScheduleRepository.findById(scheduleId)
                .orElseThrow(() -> new BusinessException(ErrorCode.ADM_AUTO_RULE_NOT_FOUND));
        schedule.toggle();
        return AutoReportScheduleResponse.from(schedule);
    }

    /** 수동 실행 (실행 카운트 증가) */
    @Transactional
    public AutoReportScheduleResponse executeNow(Long scheduleId) {
        AutoReportSchedule schedule = autoReportScheduleRepository.findById(scheduleId)
                .orElseThrow(() -> new BusinessException(ErrorCode.ADM_AUTO_RULE_NOT_FOUND));
        schedule.markExecuted();
        return AutoReportScheduleResponse.from(schedule);
    }
}
