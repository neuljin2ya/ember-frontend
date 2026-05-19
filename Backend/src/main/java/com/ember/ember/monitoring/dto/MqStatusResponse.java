package com.ember.ember.monitoring.dto;

import io.swagger.v3.oas.annotations.media.Schema;

import java.util.List;

/** RabbitMQ 큐/DLQ 상태 — 프런트 {@code MqStatusResponse} 일치. */
@Schema(description = "MQ 상태")
public record MqStatusResponse(List<QueueState> queues) {

    public record QueueState(
            @Schema(description = "큐 이름") String name,
            @Schema(description = "대기 메시지 수") long pending,
            @Schema(description = "컨슈머 수") int consumers,
            @Schema(description = "연결된 DLQ 메시지 수") long dlqSize
    ) {}
}
