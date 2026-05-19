package com.ember.ember.monitoring.service;

import com.ember.ember.consent.repository.AiConsentLogDashboardRepository;
import com.ember.ember.diary.domain.Diary;
import com.ember.ember.diary.repository.DiaryRepository;
import com.ember.ember.messaging.outbox.entity.OutboxEvent;
import com.ember.ember.messaging.outbox.entity.OutboxEvent.OutboxStatus;
import com.ember.ember.messaging.outbox.repository.OutboxEventRepository;
import com.ember.ember.monitoring.client.PrometheusQueryClient;
import com.ember.ember.monitoring.client.RabbitMgmtClient;
import com.ember.ember.monitoring.dto.*;
import com.ember.ember.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * AI 모니터링 대시보드 조회 서비스 — Phase 3B §12.
 * <p>대부분의 수치는 DB 집계로 즉시 계산하고, 시계열이 필요한 Redis Hit Ratio / Outbox lag p95 만
 * Prometheus Query API 를 활용한다. Prometheus/RabbitMQ Management 호출 실패 시 기본값(0)으로 대체해
 * 대시보드가 항상 응답 200을 유지하도록 한다(D10).
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MonitoringQueryService {

    private static final int FAILED_SAMPLE_LIMIT = 20;
    private static final int LONG_PROCESSING_THRESHOLD_MINUTES = 15;
    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

    private final DiaryRepository diaryRepository;
    private final OutboxEventRepository outboxEventRepository;
    private final AiConsentLogDashboardRepository aiConsentLogDashboardRepository;
    private final UserRepository userRepository;
    private final RabbitMgmtClient rabbitMgmtClient;
    private final PrometheusQueryClient prometheusQueryClient;

    // ── 1. AI 개요 ───────────────────────────────────────────────────────────────

    public AiOverviewResponse getAiOverview() {
        long outboxPending = outboxEventRepository.countByStatus(OutboxStatus.PENDING);
        long outboxFailed = outboxEventRepository.countByStatus(OutboxStatus.FAILED);
        long analysisProcessing = diaryRepository.countByAnalysisStatus(Diary.AnalysisStatus.PROCESSING);
        long analysisFailed = diaryRepository.countByAnalysisStatus(Diary.AnalysisStatus.FAILED);

        long dlqSize = rabbitMgmtClient.listQueues().stream()
                .filter(q -> q.name().endsWith(".dlq"))
                .mapToLong(RabbitMgmtClient.QueueSnapshot::messages)
                .sum();

        double consentRate = computeAnalysisConsentRate();
        double redisHitRatio = prometheusQueryClient.queryScalar(
                "sum(rate(redis_keyspace_hits_total[5m])) / " +
                "(sum(rate(redis_keyspace_hits_total[5m])) + sum(rate(redis_keyspace_misses_total[5m])))"
        ).orElse(0.0);

        return new AiOverviewResponse(
                consentRate, dlqSize, outboxPending, outboxFailed,
                redisHitRatio, analysisProcessing, analysisFailed);
    }

    // ── 2. AI 동의 통계 ─────────────────────────────────────────────────────────

    public ConsentStatsResponse getConsentStats(String range) {
        LocalDateTime to = LocalDateTime.now();
        LocalDateTime from = switch (range == null ? "7d" : range) {
            case "24h" -> to.minusHours(24);
            case "30d" -> to.minusDays(30);
            default -> to.minusDays(7);
        };

        long totalUsers = userRepository.count();
        double analysisRate = computeAnalysisConsentRate();
        double matchingRate = computeConsentRateByType("AI_DATA_USAGE");
        long revokedCount = aiConsentLogDashboardRepository
                .countByActionAndActedAtBetween("REVOKED", from, to);

        List<Object[]> rows = aiConsentLogDashboardRepository.aggregateDailyTrend(from, to);
        Map<String, long[]> byDate = new TreeMap<>();
        for (Object[] row : rows) {
            String d = (String) row[0];
            String action = (String) row[1];
            long cnt = ((Number) row[2]).longValue();
            long[] pair = byDate.computeIfAbsent(d, k -> new long[2]);
            if ("GRANTED".equals(action)) pair[0] += cnt;
            else if ("REVOKED".equals(action)) pair[1] += cnt;
        }
        List<ConsentStatsResponse.DailyTrend> trend = new ArrayList<>();
        byDate.forEach((d, p) -> trend.add(new ConsentStatsResponse.DailyTrend(d, p[0], p[1])));

        return new ConsentStatsResponse(totalUsers, analysisRate, matchingRate, revokedCount, trend);
    }

    // ── 3. MQ 상태 ──────────────────────────────────────────────────────────────

    public MqStatusResponse getMqStatus() {
        List<RabbitMgmtClient.QueueSnapshot> snapshots = rabbitMgmtClient.listQueues();

        // DLQ 매핑: 같은 베이스 이름의 {base}.dlq 큐를 찾아 dlqSize 산출
        Map<String, Long> dlqByBase = new HashMap<>();
        for (RabbitMgmtClient.QueueSnapshot q : snapshots) {
            if (q.name().endsWith(".dlq")) {
                String base = q.name().substring(0, q.name().length() - ".dlq".length());
                dlqByBase.merge(base, q.messages(), Long::sum);
            }
        }

        List<MqStatusResponse.QueueState> queues = snapshots.stream()
                .filter(q -> !q.name().endsWith(".dlq"))
                .map(q -> new MqStatusResponse.QueueState(
                        q.name(), q.messagesReady(), q.consumers(), dlqByBase.getOrDefault(q.name(), 0L)))
                .toList();

        return new MqStatusResponse(queues);
    }

    // ── 4. Outbox 상태 ──────────────────────────────────────────────────────────

    public OutboxStatusResponse getOutboxStatus() {
        long pending = outboxEventRepository.countByStatus(OutboxStatus.PENDING);
        long failed = outboxEventRepository.countByStatus(OutboxStatus.FAILED);

        // Outbox lag p95 (ms) — Prometheus 시계열. 장애 시 게이지의 현재 값 fallback.
        double lagP95Ms = prometheusQueryClient.queryScalar(
                "histogram_quantile(0.95, sum(rate(outbox_relay_lag_seconds_bucket[5m])) by (le)) * 1000"
        ).orElseGet(() -> {
            Optional<LocalDateTime> oldest = outboxEventRepository.findOldestCreatedAtByStatus(OutboxStatus.PENDING);
            return oldest.map(t -> (double) Duration.between(t, LocalDateTime.now()).toMillis()).orElse(0.0);
        });

        List<OutboxEvent> sample = outboxEventRepository.findFailedSample(
                OutboxStatus.FAILED, PageRequest.of(0, FAILED_SAMPLE_LIMIT));
        List<OutboxStatusResponse.FailedItem> failedSample = sample.stream()
                .map(e -> new OutboxStatusResponse.FailedItem(
                        e.getId(), e.getAggregateType(), e.getEventType(),
                        "", // TODO: OutboxEvent 에 lastError 필드 추가 후 매핑
                        e.getCreatedAt() == null ? null : e.getCreatedAt().format(ISO)))
                .toList();

        return new OutboxStatusResponse(pending, failed, lagP95Ms, failedSample);
    }

    // ── 5. Redis 건강도 ────────────────────────────────────────────────────────

    public RedisHealthResponse getRedisHealth() {
        double used = prometheusQueryClient.queryScalar("redis_memory_used_bytes / 1024 / 1024").orElse(0.0);
        double peak = prometheusQueryClient.queryScalar("redis_memory_peak_bytes / 1024 / 1024").orElse(0.0);

        // 캐시 패턴별 Hit Ratio 는 현재 application 계층에서 직접 측정하지 않으므로
        // 주요 패턴명만 나열하고 비율은 전체 Redis keyspace hit ratio 로 공통 표시한다.
        double globalHit = prometheusQueryClient.queryScalar(
                "sum(rate(redis_keyspace_hits_total[5m])) / " +
                "(sum(rate(redis_keyspace_hits_total[5m])) + sum(rate(redis_keyspace_misses_total[5m])))"
        ).orElse(0.0);

        List<RedisHealthResponse.CachePattern> patterns = List.of(
                new RedisHealthResponse.CachePattern("AI:DIARY:*", globalHit, 0L),
                new RedisHealthResponse.CachePattern("AI:LIFESTYLE:*", globalHit, 0L),
                new RedisHealthResponse.CachePattern("MATCHING:RECO:*", globalHit, 0L),
                new RedisHealthResponse.CachePattern("BRIEFING:*", globalHit, 0L),
                new RedisHealthResponse.CachePattern("BANNED_WORDS:ALL", globalHit, 0L),
                new RedisHealthResponse.CachePattern("URL_WHITELIST:*", globalHit, 0L)
        );

        return new RedisHealthResponse(used, peak, patterns, 0L);
    }

    // ── 6. 분석 상태 분포 ──────────────────────────────────────────────────────

    public AnalysisOverviewResponse getAnalysisOverview() {
        var diary = new AnalysisOverviewResponse.DiaryAnalysisCounts(
                diaryRepository.countByAnalysisStatus(Diary.AnalysisStatus.PROCESSING),
                diaryRepository.countByAnalysisStatus(Diary.AnalysisStatus.COMPLETED),
                diaryRepository.countByAnalysisStatus(Diary.AnalysisStatus.FAILED),
                diaryRepository.countByAnalysisStatus(Diary.AnalysisStatus.SKIPPED)
        );

        // ExchangeReport 독립 엔티티 미존재 — D10 기본값 정책에 따라 0 반환.
        // TODO: M5 리포트 파이프라인 구현 시 ExchangeReport 엔티티 기반 집계로 교체.
        var report = new AnalysisOverviewResponse.ReportAnalysisCounts(0L, 0L, 0L, 0L);

        LocalDateTime threshold = LocalDateTime.now().minusMinutes(LONG_PROCESSING_THRESHOLD_MINUTES);
        Pageable page = PageRequest.of(0, 20);
        List<AnalysisOverviewResponse.LongProcessingItem> longProcessing =
                diaryRepository.findLongProcessing(threshold, page).stream()
                        .map(d -> new AnalysisOverviewResponse.LongProcessingItem(
                                d.getId(), "DIARY",
                                d.getModifiedAt() == null ? null : d.getModifiedAt().format(ISO),
                                Duration.between(
                                        d.getModifiedAt() == null ? LocalDateTime.now() : d.getModifiedAt(),
                                        LocalDateTime.now()).toMinutes()))
                        .toList();

        return new AnalysisOverviewResponse(diary, report, longProcessing);
    }

    // ── 7. 미동의 사용자 목록 (stub) ────────────────────────────────────────────

    public ConsentMissingUsersResponse getConsentMissingUsers(int page, int size, String filter) {
        // TODO: 최신 AiConsentLog 상태가 미동의/미존재인 사용자 목록을 페이징 조회.
        // 현재는 집계 비용이 높아 Phase 3B 스코프 밖으로 분리. 기본값 반환.
        log.info("[Monitoring] consent-missing-users stub 호출: filter={} page={} size={}", filter, page, size);
        return new ConsentMissingUsersResponse(List.of(), 0L);
    }

    // ── 내부 헬퍼 ───────────────────────────────────────────────────────────────

    private double computeAnalysisConsentRate() {
        return computeConsentRateByType("AI_ANALYSIS");
    }

    private double computeConsentRateByType(String consentType) {
        long total = userRepository.count();
        if (total == 0L) return 0.0;
        long granted = aiConsentLogDashboardRepository.countUsersWithLatestGranted(consentType);
        return (double) granted / (double) total;
    }
}
