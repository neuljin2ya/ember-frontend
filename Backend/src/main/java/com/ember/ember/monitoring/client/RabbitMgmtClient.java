package com.ember.ember.monitoring.client;

import com.fasterxml.jackson.databind.JsonNode;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * RabbitMQ Management API 클라이언트.
 * <p>주 용도: 큐별 메시지/컨슈머 수, DLQ 상태 조회, DLQ 재처리용 메시지 이동.
 *
 * <p>엔드포인트:
 * <ul>
 *   <li>{@code GET /api/queues} — 모든 큐 상태 조회</li>
 *   <li>{@code GET /api/queues/{vhost}/{queue}} — 특정 큐 상세</li>
 *   <li>{@code POST /api/queues/{vhost}/{queue}/get} — 큐 메시지 샘플링(peek)</li>
 * </ul>
 * <p>DLQ 재처리는 FastAPI 재시도 API 또는 Shovel 플러그인과 연동하는 것이 이상적이지만,
 * 본 클라이언트는 읽기 전용으로 구현하고 재처리는 MonitoringActionService 에서 별도 처리한다.
 */
@Slf4j
@Component
public class RabbitMgmtClient {

    private static final String VHOST_DEFAULT = "%2F"; // URL-encoded '/'

    private final RestClient restClient;

    public RabbitMgmtClient(@Qualifier("rabbitMgmtRestClient") RestClient restClient) {
        this.restClient = restClient;
    }

    /** 전체 큐 상태 목록. 장애 시 빈 리스트 반환. */
    public List<QueueSnapshot> listQueues() {
        try {
            JsonNode arr = restClient.get()
                    .uri("/api/queues")
                    .retrieve()
                    .body(JsonNode.class);
            if (arr == null || !arr.isArray()) {
                return Collections.emptyList();
            }
            List<QueueSnapshot> result = new ArrayList<>();
            for (JsonNode q : arr) {
                result.add(toSnapshot(q));
            }
            return result;
        } catch (RestClientException e) {
            log.warn("[RabbitMgmt] 큐 목록 조회 실패: {}", e.getMessage());
            return Collections.emptyList();
        }
    }

    /** 특정 큐 조회. 기본 vhost('/') 사용. */
    public QueueSnapshot getQueue(String queueName) {
        try {
            JsonNode q = restClient.get()
                    .uri("/api/queues/{vhost}/{name}", VHOST_DEFAULT, queueName)
                    .retrieve()
                    .body(JsonNode.class);
            if (q == null) {
                return QueueSnapshot.unavailable(queueName);
            }
            return toSnapshot(q);
        } catch (RestClientException e) {
            log.warn("[RabbitMgmt] 큐 조회 실패: queue={}, msg={}", queueName, e.getMessage());
            return QueueSnapshot.unavailable(queueName);
        }
    }

    public boolean isHealthy() {
        try {
            restClient.get()
                    .uri("/api/overview")
                    .retrieve()
                    .toBodilessEntity();
            return true;
        } catch (RestClientException e) {
            return false;
        }
    }

    private QueueSnapshot toSnapshot(JsonNode q) {
        return new QueueSnapshot(
                q.path("name").asText(""),
                q.path("messages").asLong(0L),
                q.path("messages_ready").asLong(0L),
                q.path("messages_unacknowledged").asLong(0L),
                q.path("consumers").asInt(0),
                q.path("state").asText("unknown")
        );
    }

    /** RabbitMQ Management API 응답을 축약한 DTO. */
    public record QueueSnapshot(
            String name,
            long messages,
            long messagesReady,
            long messagesUnacked,
            int consumers,
            String state
    ) {
        public static QueueSnapshot unavailable(String name) {
            return new QueueSnapshot(name, 0L, 0L, 0L, 0, "unavailable");
        }
    }
}
