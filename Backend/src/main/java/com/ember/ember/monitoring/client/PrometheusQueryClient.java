package com.ember.ember.monitoring.client;

import com.fasterxml.jackson.databind.JsonNode;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.util.Optional;

/**
 * Prometheus HTTP Query API 클라이언트.
 * <p>주 용도: 시계열 집계가 필요한 지표 조회 (hit ratio, p95 lag 등).
 * 단순 카운터/게이지는 내부 {@link io.micrometer.core.instrument.MeterRegistry}에서 직접 읽는 것을 권장.
 *
 * <p>Prometheus 응답 스키마:
 * <pre>
 * {
 *   "status": "success",
 *   "data": {
 *     "resultType": "vector",
 *     "result": [{"metric": {...}, "value": [1704096000.123, "0.95"]}]
 *   }
 * }
 * </pre>
 *
 * 장애 시 빈 {@link Optional}을 반환해 대시보드가 기본값(0)으로 렌더링되도록 한다.
 */
@Slf4j
@Component
public class PrometheusQueryClient {

    private static final String QUERY_PATH = "/api/v1/query";

    private final RestClient restClient;

    public PrometheusQueryClient(@Qualifier("prometheusRestClient") RestClient restClient) {
        this.restClient = restClient;
    }

    /**
     * 순간 쿼리(instant vector). 결과가 스칼라 또는 단일 벡터인 경우 double 값 하나로 축약.
     *
     * @param promQl PromQL 표현식
     * @return 첫 번째 결과값의 double. 결과 없음/오류 시 empty
     */
    public Optional<Double> queryScalar(String promQl) {
        try {
            JsonNode body = restClient.get()
                    .uri(uriBuilder -> uriBuilder.path(QUERY_PATH).queryParam("query", promQl).build())
                    .retrieve()
                    .body(JsonNode.class);

            if (body == null || !"success".equals(asText(body.get("status")))) {
                log.warn("[Prometheus] 질의 실패 응답: query={}, body={}", promQl, body);
                return Optional.empty();
            }

            JsonNode result = body.path("data").path("result");
            if (!result.isArray() || result.isEmpty()) {
                return Optional.empty();
            }

            JsonNode value = result.get(0).path("value");
            if (!value.isArray() || value.size() < 2) {
                return Optional.empty();
            }
            return Optional.of(Double.parseDouble(value.get(1).asText()));
        } catch (RestClientException | NumberFormatException e) {
            log.warn("[Prometheus] 질의 오류: query={}, msg={}", promQl, e.getMessage());
            return Optional.empty();
        }
    }

    /**
     * Prometheus 연결 헬스체크.
     *
     * @return 연결 가능 여부
     */
    public boolean isHealthy() {
        try {
            restClient.get()
                    .uri("/-/ready")
                    .retrieve()
                    .toBodilessEntity();
            return true;
        } catch (RestClientException e) {
            log.warn("[Prometheus] 헬스체크 실패: {}", e.getMessage());
            return false;
        }
    }

    private String asText(JsonNode node) {
        return node == null ? null : node.asText(null);
    }
}
