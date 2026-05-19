package com.ember.ember.messaging.outbox;

import com.ember.ember.admin.domain.inbox.AdminNotification;
import com.ember.ember.admin.service.inbox.AdminInboxPublisher;
import com.ember.ember.aireport.repository.ExchangeReportRepository;
import com.ember.ember.consent.service.AiConsentService;
import com.ember.ember.diary.repository.DiaryRepository;
import com.ember.ember.messaging.event.DiaryAnalyzeRequestedEvent;
import com.ember.ember.messaging.event.ExchangeReportRequestedEvent;
import com.ember.ember.messaging.event.LifestyleAnalyzeRequestedEvent;
import com.ember.ember.messaging.event.UserVectorGenerateRequestedEvent;
import com.ember.ember.messaging.outbox.entity.OutboxEvent;
import com.ember.ember.messaging.outbox.repository.OutboxEventRepository;
import com.ember.ember.messaging.publisher.AiMessagePublisher;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * OutboxRelay에서 분리된 이벤트 처리기.
 * 별도 Bean이므로 REQUIRES_NEW 트랜잭션이 AOP 프록시를 통해 정상 동작한다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class OutboxEventProcessor {

    private static final int MAX_RETRY = 5;

    private final OutboxEventRepository outboxEventRepository;
    private final AiMessagePublisher aiMessagePublisher;
    private final AiConsentService aiConsentService;
    private final DiaryRepository diaryRepository;
    private final ExchangeReportRepository exchangeReportRepository;
    private final ObjectMapper objectMapper;
    private final AdminInboxPublisher adminInboxPublisher;

    /**
     * 단일 이벤트 처리 — 독립 트랜잭션.
     * 한 이벤트 실패가 다른 이벤트에 영향 없음.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processEvent(OutboxEvent event) {
        MDC.put("outboxEventId", String.valueOf(event.getId()));
        MDC.put("eventType", event.getEventType());
        try {
            switch (event.getEventType()) {
                case "DIARY_ANALYZE_REQUESTED"         -> processDiaryAnalyzeRequested(event);
                case "EXCHANGE_REPORT_REQUESTED"       -> processExchangeReportRequested(event);
                case "LIFESTYLE_ANALYZE_REQUESTED"     -> processLifestyleAnalyzeRequested(event);
                case "USER_VECTOR_GENERATE_REQUESTED"  -> processUserVectorGenerateRequested(event);
                default -> {
                    log.debug("[OutboxRelay] 처리 대상 아닌 이벤트 타입 — eventType={}, eventId={}",
                            event.getEventType(), event.getId());
                    event.markProcessed();
                    outboxEventRepository.save(event);
                }
            }
        } catch (Exception e) {
            event.incrementRetryOrFail(MAX_RETRY);
            outboxEventRepository.save(event);
            log.warn("[OutboxRelay] 발행 실패 — eventId={}, retry={}, 이유={}",
                    event.getId(), event.getRetryCount(), e.getMessage());

            // FAILED로 전이된 1회만 관리자 알림 발행 (CRITICAL — 5분 묶음 자동 적용).
            // publish 실패가 본 catch 흐름을 깨지 않도록 내부에서 또 try/catch로 방어.
            if (event.getStatus() == OutboxEvent.OutboxStatus.FAILED) {
                try {
                    adminInboxPublisher.publish(AdminInboxPublisher.NotificationCommand.builder()
                            .type(AdminNotification.NotificationType.CRITICAL)
                            .category("MESSAGING")
                            .title("Outbox 이벤트 최대 재시도 초과")
                            .message(String.format("eventId=%d eventType=%s 최대 재시도(%d) 초과",
                                    event.getId(), event.getEventType(), MAX_RETRY))
                            .sourceType("OUTBOX_DLQ")
                            .sourceId(String.valueOf(event.getId()))
                            .actionUrl("/admin/system/messaging")
                            .build());
                } catch (Exception ex) {
                    log.warn("[OutboxRelay] 관리자 알림 발행 실패 (Outbox FAILED 처리는 정상) — eventId={}, 이유={}",
                            event.getId(), ex.getMessage());
                }
            }
        } finally {
            MDC.remove("outboxEventId");
            MDC.remove("eventType");
        }
    }

    private void processExchangeReportRequested(OutboxEvent event) throws Exception {
        ExchangeReportRequestedEvent requestEvent = objectMapper.readValue(
                event.getPayload(), ExchangeReportRequestedEvent.class);

        Long reportId  = requestEvent.reportId();
        Long userAId   = requestEvent.userAId();
        Long userBId   = requestEvent.userBId();

        boolean consentA = aiConsentService.hasGrantedConsent(userAId, "AI_DATA_USAGE");
        boolean consentB = aiConsentService.hasGrantedConsent(userBId, "AI_DATA_USAGE");

        if (!consentA || !consentB) {
            exchangeReportRepository.findById(reportId).ifPresent(report -> {
                report.markConsentRequired();
                exchangeReportRepository.save(report);
            });
            event.markProcessed();
            outboxEventRepository.save(event);
            log.info("[OutboxRelay] EXCHANGE_REPORT_REQUESTED — 재검증 동의 미획득, 발행 생략 " +
                     "reportId={}, consentA={}, consentB={}", reportId, consentA, consentB);
            return;
        }

        aiMessagePublisher.publishExchangeReport(requestEvent);
        event.markProcessed();
        outboxEventRepository.save(event);
        log.debug("[OutboxRelay] EXCHANGE_REPORT_REQUESTED 발행 완료 — eventId={}, reportId={}",
                event.getId(), reportId);
    }

    private void processLifestyleAnalyzeRequested(OutboxEvent event) throws Exception {
        LifestyleAnalyzeRequestedEvent requestEvent = objectMapper.readValue(
                event.getPayload(), LifestyleAnalyzeRequestedEvent.class);

        Long userId = requestEvent.userId();

        boolean hasConsent = aiConsentService.hasGrantedConsent(userId, "AI_DATA_USAGE");

        if (!hasConsent) {
            event.markProcessed();
            outboxEventRepository.save(event);
            log.info("[OutboxRelay] LIFESTYLE_ANALYZE_REQUESTED — AI_DATA_USAGE 동의 미획득, 발행 생략 userId={}",
                    userId);
            return;
        }

        aiMessagePublisher.publishLifestyleAnalyze(requestEvent);
        event.markProcessed();
        outboxEventRepository.save(event);
        log.debug("[OutboxRelay] LIFESTYLE_ANALYZE_REQUESTED 발행 완료 — eventId={}, userId={}",
                event.getId(), userId);
    }

    private void processUserVectorGenerateRequested(OutboxEvent event) throws Exception {
        UserVectorGenerateRequestedEvent requestEvent = objectMapper.readValue(
                event.getPayload(), UserVectorGenerateRequestedEvent.class);

        aiMessagePublisher.publishUserVectorGenerate(requestEvent);
        event.markProcessed();
        outboxEventRepository.save(event);
        log.debug("[OutboxRelay] USER_VECTOR_GENERATE_REQUESTED 발행 완료 — eventId={}, userId={}",
                event.getId(), requestEvent.userId());
    }

    private void processDiaryAnalyzeRequested(OutboxEvent event) throws Exception {
        DiaryAnalyzeRequestedEvent requestEvent = objectMapper.readValue(
                event.getPayload(), DiaryAnalyzeRequestedEvent.class);

        Long userId = requestEvent.userId();
        Long diaryId = requestEvent.diaryId();
        MDC.put("messageId", requestEvent.messageId());

        boolean hasConsent = aiConsentService.hasGrantedConsent(userId, "AI_ANALYSIS");

        if (!hasConsent) {
            diaryRepository.findById(diaryId).ifPresent(diary -> {
                diary.skipAnalysis();
                diaryRepository.save(diary);
            });
            event.markProcessed();
            outboxEventRepository.save(event);
            log.info("[OutboxRelay] AI 동의 미획득 — 분석 생략 처리 diaryId={}, userId={}", diaryId, userId);
            return;
        }

        aiMessagePublisher.publishDiaryAnalyze(requestEvent);
        event.markProcessed();
        outboxEventRepository.save(event);
        log.debug("[OutboxRelay] DIARY_ANALYZE_REQUESTED 발행 완료 — eventId={}, diaryId={}",
                event.getId(), diaryId);
    }
}
