package com.ember.ember.messaging.consumer;

import com.ember.ember.messaging.event.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.context.annotation.Profile;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;

/**
 * 로컬 테스트 전용 Mock AI Consumer.
 * FastAPI AI 서버 없이 파이프라인 전체 흐름을 테스트할 수 있다.
 *
 * 요청 큐(diary.analyze.q 등)에서 메시지를 받아
 * 2초 후 가짜 분석 결과를 ai.result.q로 발행한다.
 */
@Slf4j
@Component
@Profile("local")
@RequiredArgsConstructor
public class MockAiConsumer {

    private static final String EXCHANGE = "ai.exchange";
    private static final String RESULT_KEY = "ai.result.v1";
    private static final ZoneId KST = ZoneId.of("Asia/Seoul");
    private static final DateTimeFormatter ISO_KST = DateTimeFormatter.ISO_OFFSET_DATE_TIME;

    // 설계서 4.2~4.4 기준 태그 (KcELECTRA 분류 헤드)
    // emotion_head: 16개 감정 태그
    private static final List<String> EMOTION_TAGS = List.of(
            "기쁨", "슬픔", "감사", "불안", "설렘", "분노", "평온", "외로움",
            "그리움", "희망", "자부심", "후회", "위로", "만족", "기대", "놀라움");
    // lifestyle_head: 3축 x 3클래스 (활동성/사교성/규칙성)
    private static final List<String> LIFESTYLE_TAGS = List.of(
            "활동적", "비활동적", "외향적", "내향적", "계획적", "즉흥적");
    // relationship_head: 4축 x 3클래스 (의사소통/애정표현/갈등대응/독립성)
    private static final List<String> RELATIONSHIP_TAGS = List.of(
            "적극적 소통", "소극적 소통", "애정표현 적극적", "애정표현 절제",
            "대화형 갈등대응", "회피형 갈등대응", "독립적", "의존적");
    // tone_head: 3개 톤
    private static final List<String> TONE_TAGS = List.of(
            "감성적", "이성적", "유머러스");
    // 이상형 키워드 10개 (설계서 표4-4-2, DB keywords 테이블과 일치)
    private static final List<String> IDEAL_KEYWORDS = List.of(
            "안정적인 사람", "긍정적인 사람", "따뜻한 사람", "공감적인 사람", "다정한 사람",
            "솔직한 사람", "성실한 사람", "도전적인 사람", "자유로운 사람", "깊이있는 사람");

    private final RabbitTemplate rabbitTemplate;
    private final ObjectMapper objectMapper;
    private final Random random = new Random();

    /** 일기 분석 요청 Mock 처리 */
    @RabbitListener(queues = "diary.analyze.q", containerFactory = "rabbitListenerContainerFactory")
    public void handleDiaryAnalyze(DiaryAnalyzeRequestedEvent event) {
        log.info("[MockAI] 일기 분석 요청 수신 — diaryId={}, userId={}", event.diaryId(), event.userId());
        delayAndSend(() -> sendDiaryResult(event));
    }

    /** 교환일기 리포트 요청 Mock 처리 */
    @RabbitListener(queues = "exchange.report.q", containerFactory = "rabbitListenerContainerFactory")
    public void handleExchangeReport(ExchangeReportRequestedEvent event) {
        log.info("[MockAI] 교환리포트 요청 수신 — reportId={}, roomId={}", event.reportId(), event.roomId());
        delayAndSend(() -> sendExchangeReportResult(event));
    }

    /** 라이프스타일 분석 요청 Mock 처리 */
    @RabbitListener(queues = "lifestyle.analyze.q", containerFactory = "rabbitListenerContainerFactory")
    public void handleLifestyleAnalyze(LifestyleAnalyzeRequestedEvent event) {
        log.info("[MockAI] 라이프스타일 분석 요청 수신 — userId={}", event.userId());
        delayAndSend(() -> sendLifestyleResult(event));
    }

    /** 사용자 벡터 생성 요청 Mock 처리 */
    @RabbitListener(queues = "user.vector.generate.q", containerFactory = "rabbitListenerContainerFactory")
    public void handleUserVector(UserVectorGenerateRequestedEvent event) {
        log.info("[MockAI] 벡터 생성 요청 수신 — userId={}", event.userId());
        delayAndSend(() -> sendVectorResult(event));
    }

    // ── Mock 결과 생성 ──

    private void sendDiaryResult(DiaryAnalyzeRequestedEvent event) {
        List<AiAnalysisResultEvent.Tag> tags = new ArrayList<>();
        tags.add(randomTag("EMOTION", EMOTION_TAGS));
        tags.add(randomTag("LIFESTYLE", LIFESTYLE_TAGS));
        tags.add(randomTag("RELATIONSHIP_STYLE", RELATIONSHIP_TAGS));
        tags.add(randomTag("TONE", TONE_TAGS));

        var result = new AiAnalysisResultEvent.Result(
                "Mock 요약: 하루를 돌아보며 감사한 마음을 느낀 일기입니다.",
                randomCategory(),
                tags
        );

        var resultEvent = new AiAnalysisResultEvent(
                UUID.randomUUID().toString(), event.messageId(), "v1",
                AiAnalysisResultType.DIARY_ANALYSIS_COMPLETED,
                event.diaryId(), event.userId(),
                null, null,
                now(), null,
                result, null, null, null, null
        );

        publish(resultEvent);
        log.info("[MockAI] 일기 분석 결과 발행 — diaryId={}", event.diaryId());
    }

    private void sendExchangeReportResult(ExchangeReportRequestedEvent event) {
        var exchangeResult = new AiAnalysisResultEvent.ExchangeResult(
                pickRandom(IDEAL_KEYWORDS, 3),
                0.65 + random.nextDouble() * 0.3,
                pickRandom(LIFESTYLE_TAGS, 2),
                0.4 + random.nextDouble() * 0.5,
                0.4 + random.nextDouble() * 0.5,
                "Mock: 두 분은 따뜻하고 안정적인 성향이 닮았어요."
        );

        var resultEvent = new AiAnalysisResultEvent(
                UUID.randomUUID().toString(), event.messageId(), "v1",
                AiAnalysisResultType.EXCHANGE_REPORT_COMPLETED,
                null, null,
                event.reportId(), event.roomId(),
                now(), null,
                null, null, exchangeResult, null, null
        );

        publish(resultEvent);
        log.info("[MockAI] 교환리포트 결과 발행 — reportId={}", event.reportId());
    }

    private void sendLifestyleResult(LifestyleAnalyzeRequestedEvent event) {
        List<AiAnalysisResultEvent.Tag> keywords = new ArrayList<>();
        keywords.add(randomTag("LIFESTYLE", LIFESTYLE_TAGS));
        keywords.add(randomTag("RELATIONSHIP_STYLE", RELATIONSHIP_TAGS));
        keywords.add(randomTag("EMOTION", EMOTION_TAGS));

        var lifestyleResult = new AiAnalysisResultEvent.LifestyleResult(
                pickRandom(LIFESTYLE_TAGS, 3),
                new AiAnalysisResultEvent.EmotionProfile(
                        0.5 + random.nextDouble() * 0.3,
                        0.05 + random.nextDouble() * 0.15,
                        0.1 + random.nextDouble() * 0.2),
                keywords,
                "Mock: 활발하고 긍정적인 생활 패턴을 보여요."
        );

        var resultEvent = new AiAnalysisResultEvent(
                UUID.randomUUID().toString(), event.messageId(), "v1",
                AiAnalysisResultType.LIFESTYLE_ANALYSIS_COMPLETED,
                null, event.userId(),
                null, null,
                now(), null,
                null, null, null, lifestyleResult, null
        );

        publish(resultEvent);
        log.info("[MockAI] 라이프스타일 결과 발행 — userId={}", event.userId());
    }

    private void sendVectorResult(UserVectorGenerateRequestedEvent event) {
        // 768차원 fp16 벡터 생성 (랜덤)
        byte[] embedding = new byte[768 * 2];
        ByteBuffer buf = ByteBuffer.wrap(embedding).order(ByteOrder.LITTLE_ENDIAN);
        for (int i = 0; i < 768; i++) {
            buf.putShort((short) Float.floatToFloat16(random.nextFloat() * 2 - 1));
        }
        String base64 = Base64.getEncoder().encodeToString(embedding);

        var vectorResult = new AiAnalysisResultEvent.VectorResult(base64, 768, event.source());

        var resultEvent = new AiAnalysisResultEvent(
                UUID.randomUUID().toString(), event.messageId(), "v1",
                AiAnalysisResultType.USER_VECTOR_GENERATED,
                null, event.userId(),
                null, null,
                now(), null,
                null, null, null, null, vectorResult
        );

        publish(resultEvent);
        log.info("[MockAI] 벡터 결과 발행 — userId={}", event.userId());
    }

    // ── 유틸 ──

    private void publish(AiAnalysisResultEvent event) {
        rabbitTemplate.convertAndSend(EXCHANGE, RESULT_KEY, event);
    }

    private void delayAndSend(Runnable task) {
        // 2초 딜레이 (실제 AI 분석 시간 시뮬레이션)
        new Thread(() -> {
            try {
                Thread.sleep(2000);
                task.run();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            } catch (Exception e) {
                log.error("[MockAI] 결과 발행 실패 — {}", e.getMessage(), e);
            }
        }).start();
    }

    private AiAnalysisResultEvent.Tag randomTag(String type, List<String> pool) {
        return new AiAnalysisResultEvent.Tag(type, pool.get(random.nextInt(pool.size())), 0.6 + random.nextDouble() * 0.4);
    }

    private List<String> pickRandom(List<String> pool, int count) {
        List<String> shuffled = new ArrayList<>(pool);
        Collections.shuffle(shuffled, random);
        return shuffled.subList(0, Math.min(count, shuffled.size()));
    }

    private String randomCategory() {
        String[] categories = {"DAILY", "TRAVEL", "FOOD", "RELATIONSHIP", "WORK"};
        return categories[random.nextInt(categories.length)];
    }

    private String now() {
        return ZonedDateTime.now(KST).format(ISO_KST);
    }
}
