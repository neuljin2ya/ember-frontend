package com.ember.ember.monitoring.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

/**
 * AI 모니터링 대시보드 외부 시스템 접속 설정.
 * application.yml 의 {@code app.monitoring.*} 하위 설정을 바인딩한다.
 *
 * <ul>
 *   <li>{@code prometheus.url} — Prometheus HTTP Query API 베이스 URL (ex: http://prometheus:9090)</li>
 *   <li>{@code prometheus.timeout} — HTTP read timeout (기본 3s)</li>
 *   <li>{@code rabbitMgmt.url} — RabbitMQ Management API 베이스 URL (ex: http://rabbitmq:15672)</li>
 *   <li>{@code rabbitMgmt.username/password} — Basic Auth 자격</li>
 *   <li>{@code rabbitMgmt.timeout} — HTTP read timeout (기본 3s)</li>
 * </ul>
 */
@ConfigurationProperties(prefix = "app.monitoring")
public record MonitoringProperties(
        PrometheusConfig prometheus,
        RabbitMgmtConfig rabbitMgmt
) {

    public record PrometheusConfig(
            String url,
            Duration timeout
    ) {
        public PrometheusConfig {
            if (url == null || url.isBlank()) {
                url = "http://prometheus:9090";
            }
            if (timeout == null) {
                timeout = Duration.ofSeconds(3);
            }
        }
    }

    public record RabbitMgmtConfig(
            String url,
            String username,
            String password,
            Duration timeout
    ) {
        public RabbitMgmtConfig {
            if (url == null || url.isBlank()) {
                url = "http://rabbitmq:15672";
            }
            if (username == null || username.isBlank()) {
                username = "guest";
            }
            if (password == null || password.isBlank()) {
                password = "guest";
            }
            if (timeout == null) {
                timeout = Duration.ofSeconds(3);
            }
        }
    }
}
