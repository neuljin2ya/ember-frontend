package com.ember.ember.messaging.outbox;

import com.ember.ember.messaging.outbox.entity.OutboxEvent;
import com.ember.ember.messaging.outbox.entity.OutboxEvent.OutboxStatus;
import com.ember.ember.messaging.outbox.repository.OutboxEventRepository;
import com.ember.ember.observability.metric.AiMetrics;
import jakarta.annotation.PostConstruct;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;

/**
 * Transactional Outbox Relay 스케줄러
 *
 * 동작 원리:
 *   1. 500ms 간격으로 outbox_events 테이블에서 PENDING 이벤트 최대 100건 조회
 *   2. 각 이벤트를 OutboxEventProcessor.processEvent()에 위임 (REQUIRES_NEW 독립 트랜잭션)
 *   3. 한 이벤트 실패가 다른 이벤트에 영향 없음
 *
 * 동시성:
 *   단일 인스턴스 + fixedDelay 방식이므로 relay()는 동시 실행되지 않는다.
 *   relay()에 @Transactional을 걸면 outer tx가 PESSIMISTIC_WRITE 락을 잡고,
 *   inner tx(REQUIRES_NEW)가 같은 row를 UPDATE할 때 self-deadlock이 발생한다.
 *   따라서 relay()는 트랜잭션 없이 실행하고, processEvent()의 독립 트랜잭션에 위임한다.
 *
 * 멱등성:
 *   Consumer 측 멱등성은 ProcessedMessage(PK 충돌)로 보장.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class OutboxRelay {

    private final OutboxEventRepository outboxEventRepository;
    private final OutboxEventProcessor outboxEventProcessor;
    private final AiMetrics aiMetrics;

    /**
     * 애플리케이션 시작 시 OutboxRelayLag 게이지 등록.
     */
    @PostConstruct
    public void registerRelayLagGauge() {
        aiMetrics.outboxRelayLag(() -> {
            LocalDateTime oldest = outboxEventRepository
                    .findOldestCreatedAtByStatus(OutboxStatus.PENDING)
                    .orElse(null);
            if (oldest == null) {
                return 0.0;
            }
            return (double) Duration.between(oldest, LocalDateTime.now()).toSeconds();
        });
    }

    /**
     * 500ms 간격으로 PENDING 이벤트 릴레이.
     * fixedDelay: 이전 실행이 끝난 후 500ms 대기 (적체 시 추월 방지).
     */
    @Scheduled(fixedDelay = 500)
    public void relay() {
        List<OutboxEvent> pendingEvents =
                outboxEventRepository.findTop100ByStatusOrderByCreatedAt(OutboxStatus.PENDING);

        if (pendingEvents.isEmpty()) {
            return;
        }

        log.debug("[OutboxRelay] PENDING 이벤트 {}건 처리 시작", pendingEvents.size());

        for (OutboxEvent event : pendingEvents) {
            outboxEventProcessor.processEvent(event);
        }
    }
}
