package com.ember.ember.monitoring.service;

import com.ember.ember.diary.domain.Diary;
import com.ember.ember.diary.repository.DiaryRepository;
import com.ember.ember.global.exception.BusinessException;
import com.ember.ember.global.response.ErrorCode;
import com.ember.ember.messaging.outbox.repository.OutboxEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * AI 모니터링 대시보드 쓰기 액션 서비스 — Phase 3B §12.
 * SUPER_ADMIN 권한 필요 액션들을 모았다.
 *
 * <p>구현 범위:
 * <ul>
 *   <li>Outbox 재시도: FAILED → PENDING 상태 리셋 (스케줄러가 자동 재발행)</li>
 *   <li>일기 분석 강제 FAILED: Diary.failAnalysis() 호출</li>
 * </ul>
 *
 * <p>미구현(stub):
 * <ul>
 *   <li>DLQ 재처리: RabbitMQ Shovel/Reprocessor 연동 필요 — 현재는 로그만</li>
 *   <li>리포트 동의 리마인드: 알림 시스템 연동 필요 — 현재는 로그만</li>
 * </ul>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MonitoringActionService {

    private final OutboxEventRepository outboxEventRepository;
    private final DiaryRepository diaryRepository;

    /**
     * DLQ 재처리 요청 (stub).
     * 실제 재처리는 RabbitMQ Shovel 플러그인 또는 FastAPI 재시도 API 연동 후 구현 예정.
     *
     * @param queueName 재처리 대상 DLQ 이름
     * @return 현재는 항상 0 반환 (실제 연동 후 실제 건수 반환)
     */
    public int reprocessDlq(String queueName) {
        log.warn("[Monitoring] DLQ 재처리 요청 수신 (stub): queue={} — Shovel 연동 구현 필요", queueName);
        return 0;
    }

    /**
     * Outbox FAILED 이벤트를 PENDING 으로 리셋. 스케줄러가 재발행.
     *
     * @param eventIds null/empty 시 FAILED 전체, 지정 시 해당 ID 만
     * @return 리셋된 행 수
     */
    @Transactional
    public int retryOutbox(List<Long> eventIds) {
        List<Long> ids = (eventIds == null || eventIds.isEmpty()) ? null : eventIds;
        int affected = outboxEventRepository.resetFailedToPending(ids);
        log.info("[Monitoring] Outbox 재시도 리셋 완료: {} 건", affected);
        return affected;
    }

    /**
     * 일기 AI 분석 상태를 강제로 FAILED 전이 시킨다.
     *
     * @param diaryId 대상 일기 PK
     * @param reason  관리자 사유 (감사 로그용, 현재는 WARN 로그로만 기록)
     */
    @Transactional
    public void forceFailDiary(Long diaryId, String reason) {
        Diary diary = diaryRepository.findById(diaryId)
                .orElseThrow(() -> new BusinessException(ErrorCode.DIARY_NOT_FOUND));
        diary.failAnalysis();
        log.warn("[Monitoring] 일기 분석 강제 FAILED: diaryId={} reason={}", diaryId, reason);
        // TODO: admin_audit_logs 기록 (관리자 ID/사유를 AdminAuditLog 로 저장)
    }

    /**
     * 교환일기 리포트 동의 재획득 리마인드 (stub).
     * 푸시 알림/이메일 발송은 알림 시스템 연동 후 구현 예정.
     *
     * @param reportId 대상 리포트 PK
     */
    public void consentRemind(Long reportId) {
        log.warn("[Monitoring] 리포트 동의 리마인드 요청 수신 (stub): reportId={} — 알림 시스템 연동 구현 필요",
                reportId);
    }
}
