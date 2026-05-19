package com.ember.ember.monitoring.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.web.client.RestClient;

import java.net.http.HttpClient;
import java.util.Base64;

/**
 * 모니터링 외부 시스템(Prometheus/RabbitMQ Management)용 RestClient 빈 등록.
 * 각 클라이언트는 자체 baseUrl/timeout/Basic-Auth 를 가진 독립 RestClient 를 주입받는다.
 */
@Configuration
@EnableConfigurationProperties(MonitoringProperties.class)
public class MonitoringClientConfig {

    /** Prometheus HTTP Query API 용 RestClient (인증 없음, 내부망 전용). */
    @Bean(name = "prometheusRestClient")
    public RestClient prometheusRestClient(MonitoringProperties properties) {
        HttpClient httpClient = HttpClient.newBuilder()
                .connectTimeout(properties.prometheus().timeout())
                .build();
        return RestClient.builder()
                .baseUrl(properties.prometheus().url())
                .requestFactory(new JdkClientHttpRequestFactory(httpClient))
                .build();
    }

    /** RabbitMQ Management API 용 RestClient (Basic Auth). */
    @Bean(name = "rabbitMgmtRestClient")
    public RestClient rabbitMgmtRestClient(MonitoringProperties properties) {
        HttpClient httpClient = HttpClient.newBuilder()
                .connectTimeout(properties.rabbitMgmt().timeout())
                .build();
        String credentials = properties.rabbitMgmt().username() + ":" + properties.rabbitMgmt().password();
        String basicAuth = "Basic " + Base64.getEncoder().encodeToString(credentials.getBytes());
        return RestClient.builder()
                .baseUrl(properties.rabbitMgmt().url())
                .defaultHeader("Authorization", basicAuth)
                .requestFactory(new JdkClientHttpRequestFactory(httpClient))
                .build();
    }
}
