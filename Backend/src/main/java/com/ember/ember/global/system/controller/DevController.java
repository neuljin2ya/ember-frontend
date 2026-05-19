package com.ember.ember.global.system.controller;

import com.ember.ember.diary.domain.Diary;
import com.ember.ember.diary.repository.DiaryRepository;
import com.ember.ember.exchange.domain.ExchangeRoom;
import com.ember.ember.exchange.repository.ExchangeRoomRepository;
import com.ember.ember.global.security.jwt.JwtTokenProvider;
import com.ember.ember.messaging.event.AiAnalysisResultEvent;
import com.ember.ember.messaging.event.AiAnalysisResultType;
import com.ember.ember.messaging.event.DiaryAnalyzeRequestedEvent;
import com.ember.ember.messaging.outbox.entity.OutboxEvent;
import com.ember.ember.messaging.outbox.repository.OutboxEventRepository;
import com.ember.ember.user.domain.User;
import com.ember.ember.user.repository.UserRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.*;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.concurrent.TimeUnit;

/**
 * 개발/테스트 전용 엔드포인트.
 * AI 시뮬레이션은 배포 서버에서도 사용 (FastAPI 미구현 동안).
 */
@RestController
@RequiredArgsConstructor
@Tag(name = "Dev", description = "개발/테스트 API — 카카오 로그인 없이 토큰 발급, AI 시뮬레이션, Redis 캐시 관리")
public class DevController {

    private final JwtTokenProvider jwtTokenProvider;
    private final ExchangeRoomRepository exchangeRoomRepository;
    private final DiaryRepository diaryRepository;
    private final RabbitTemplate rabbitTemplate;
    private final StringRedisTemplate stringRedisTemplate;
    private final UserRepository userRepository;
    private final OutboxEventRepository outboxEventRepository;
    private final ObjectMapper objectMapper;
    private final jakarta.persistence.EntityManager entityManager;
    private final javax.sql.DataSource dataSource;

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");

    @Operation(summary = "테스트 토큰 발급", description = "카카오 로그인 없이 userId로 JWT accessToken 발급. 프론트 개발/테스트용.")
    @GetMapping("/api/dev/token")
    public Map<String, String> issueTestToken(@Parameter(description = "토큰을 발급할 사용자 ID") @RequestParam Long userId) {
        String accessToken = jwtTokenProvider.createAccessToken(userId, "ROLE_USER");
        return Map.of("accessToken", accessToken);
    }

    @Operation(summary = "신규 유저 생성", description = "ROLE_GUEST 상태로 테스트 유저 생성 후 토큰 반환. 약관 동의 → 프로필 등록 → 이상형 설정 온보딩 플로우 테스트용.")
    @PostMapping("/api/dev/register")
    @Transactional
    public Map<String, Object> registerTestUser() {
        User user = User.builder()
                .email("test_" + System.currentTimeMillis() + "@dev.local")
                .status(User.UserStatus.ACTIVE)
                .role(User.UserRole.ROLE_GUEST)
                .build();
        userRepository.save(user);

        String accessToken = jwtTokenProvider.createAccessToken(user.getId(), "ROLE_GUEST");
        return Map.of(
                "userId", user.getId(),
                "accessToken", accessToken,
                "role", "ROLE_GUEST",
                "message", "신규 유저가 생성되었습니다. 약관 동의부터 시작하세요."
        );
    }

    @Operation(summary = "시드 일기 작성 (날짜 지정)", description = "하루 1회 제한 없이 날짜를 지정하여 일기 작성. AI 파이프라인 정상 트리거. 시드 데이터 생성용.")
    @PostMapping("/api/dev/diaries")
    @Transactional
    public Map<String, Object> createDevDiary(@RequestBody Map<String, Object> body) {
        Long userId = Long.valueOf(body.get("userId").toString());
        String content = (String) body.get("content");
        String dateStr = (String) body.getOrDefault("date", null);

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new RuntimeException("유저 없음: " + userId));

        LocalDate date = dateStr != null ? LocalDate.parse(dateStr) : LocalDate.now(KST);

        // 같은 유저+날짜 중복 방지
        if (diaryRepository.existsByUserIdAndDate(userId, date)) {
            return Map.of("error", "DUPLICATE", "message", "이미 해당 날짜에 일기가 존재합니다.", "date", date.toString());
        }

        // Diary 저장
        Diary diary = Diary.builder()
                .user(user)
                .content(content)
                .date(date)
                .build();
        diaryRepository.save(diary);

        // OutboxEvent 발행 → AI 파이프라인 트리거
        String messageId = UUID.randomUUID().toString();
        String publishedAt = ZonedDateTime.now(KST).format(DateTimeFormatter.ISO_OFFSET_DATE_TIME);

        DiaryAnalyzeRequestedEvent analyzeEvent = new DiaryAnalyzeRequestedEvent(
                messageId, DiaryAnalyzeRequestedEvent.VERSION,
                diary.getId(), userId, content, publishedAt, null
        );

        try {
            String payload = objectMapper.writeValueAsString(analyzeEvent);
            OutboxEvent outboxEvent = OutboxEvent.of("DIARY", diary.getId(), "DIARY_ANALYZE_REQUESTED", payload);
            outboxEventRepository.save(outboxEvent);
        } catch (JsonProcessingException e) {
            throw new RuntimeException("OutboxEvent 직렬화 실패", e);
        }

        return Map.of(
                "diaryId", diary.getId(),
                "userId", userId,
                "date", date.toString(),
                "analysisStatus", "PENDING",
                "message", "일기 생성 + AI 분석 요청 완료"
        );
    }

    @Operation(summary = "유저 완전 삭제", description = "유저와 연관된 모든 데이터를 FK 순서대로 삭제. 테스트 데이터 정리용.")
    @DeleteMapping("/api/dev/users/{userId}")
    public Map<String, Object> deleteUserCompletely(@PathVariable Long userId) {
        // JdbcTemplate으로 직접 실행 — @Transactional rollback-only 문제 회피
        var jdbc = new org.springframework.jdbc.core.JdbcTemplate(dataSource);

        // 유저 존재 확인
        var rows = jdbc.queryForList("SELECT id, nickname FROM users WHERE id = ?", userId);
        if (rows.isEmpty()) {
            return Map.of("error", "NOT_FOUND", "message", "유저 없음: " + userId);
        }
        String nickname = rows.get(0).get("nickname") != null ? rows.get(0).get("nickname").toString() : "유저" + userId;

        // FK 의존 순서대로 삭제 (자식 → 부모) — 모든 FK 참조 테이블 포함
        String[] sqls = {
            // 1. diary 자식
            "DELETE FROM diary_keywords WHERE diary_id IN (SELECT id FROM diaries WHERE user_id = ?)",
            "DELETE FROM diary_edit_logs WHERE diary_id IN (SELECT id FROM diaries WHERE user_id = ?)",
            "DELETE FROM outbox_events WHERE aggregate_type = 'DIARY' AND aggregate_id IN (SELECT id FROM diaries WHERE user_id = ?)",
            // 2. 알림/설정
            "DELETE FROM notifications WHERE user_id = ?",
            "DELETE FROM user_notification_settings WHERE user_id = ?",
            "DELETE FROM user_notice_reads WHERE user_id = ?",
            // 3. messages → chat_rooms
            "DELETE FROM messages WHERE sender_id = ?",
            "DELETE FROM messages WHERE chat_room_id IN (SELECT id FROM chat_rooms WHERE user_a_id = ? OR user_b_id = ?)",
            // 4. couple → chat_rooms
            "DELETE FROM couple_requests WHERE requester_id = ? OR receiver_id = ?",
            "DELETE FROM couple_requests WHERE chat_room_id IN (SELECT id FROM chat_rooms WHERE user_a_id = ? OR user_b_id = ?)",
            "DELETE FROM couples WHERE user_a_id = ? OR user_b_id = ?",
            "DELETE FROM couples WHERE chat_room_id IN (SELECT id FROM chat_rooms WHERE user_a_id = ? OR user_b_id = ?)",
            // 5. exchange 자식 → exchange_rooms
            "DELETE FROM exchange_diaries WHERE author_id = ?",
            "DELETE FROM exchange_diaries WHERE room_id IN (SELECT id FROM exchange_rooms WHERE user_a_id = ? OR user_b_id = ?)",
            "DELETE FROM exchange_reports WHERE room_id IN (SELECT id FROM exchange_rooms WHERE user_a_id = ? OR user_b_id = ?)",
            "DELETE FROM exchange_next_step_choices WHERE room_id IN (SELECT id FROM exchange_rooms WHERE user_a_id = ? OR user_b_id = ?)",
            "DELETE FROM next_step_choices WHERE room_id IN (SELECT id FROM exchange_rooms WHERE user_a_id = ? OR user_b_id = ?)",
            "DELETE FROM exchange_next_step_choices WHERE user_id = ?",
            "DELETE FROM next_step_choices WHERE user_id = ?",
            // 6. 순환 참조 해제: exchange_rooms ↔ chat_rooms
            "UPDATE exchange_rooms SET chat_room_id = NULL WHERE user_a_id = ? OR user_b_id = ?",
            "UPDATE chat_rooms SET exchange_room_id = NULL WHERE user_a_id = ? OR user_b_id = ?",
            // 7. exchange_rooms, chat_rooms 삭제
            "DELETE FROM exchange_rooms WHERE user_a_id = ? OR user_b_id = ?",
            "DELETE FROM chat_rooms WHERE user_a_id = ? OR user_b_id = ?",
            // 8. matching
            "DELETE FROM matching_passes WHERE user_id = ? OR target_user_id = ?",
            "DELETE FROM matching_exclusions WHERE user_id = ? OR excluded_user_id = ?",
            "DELETE FROM matchings WHERE from_user_id = ? OR to_user_id = ?",
            // 9. diaries
            "DELETE FROM diary_drafts WHERE user_id = ?",
            "DELETE FROM diaries WHERE user_id = ?",
            // 10. 유저 부속 (전체)
            "DELETE FROM user_ideal_keywords WHERE user_id = ?",
            "DELETE FROM user_personality_keywords WHERE user_id = ?",
            "DELETE FROM keyword_change_history WHERE user_id = ?",
            "DELETE FROM user_consents WHERE user_id = ?",
            "DELETE FROM user_activity_events WHERE user_id = ?",
            "DELETE FROM fcm_tokens WHERE user_id = ?",
            "DELETE FROM social_accounts WHERE user_id = ?",
            "DELETE FROM user_vectors WHERE user_id = ?",
            "DELETE FROM user_settings WHERE user_id = ?",
            "DELETE FROM blocks WHERE blocker_id = ? OR blocked_id = ?",
            "DELETE FROM reports WHERE reporter_id = ? OR reported_user_id = ?",
            "DELETE FROM appeals WHERE user_id = ?",
            "DELETE FROM inquiries WHERE user_id = ?",
            "DELETE FROM contact_detections WHERE user_id = ?",
            "DELETE FROM content_flags WHERE user_id = ?",
            "DELETE FROM suspicious_accounts WHERE user_id = ?",
            "DELETE FROM sanction_histories WHERE user_id = ?",
            "DELETE FROM sanction_history WHERE user_id = ?",
            "DELETE FROM lifestyle_analysis_log WHERE user_id = ?",
            "DELETE FROM user_withdrawal_log WHERE user_id = ?",
            "DELETE FROM admin_pii_access_log WHERE user_id = ?",
            "DELETE FROM ai_consent_log WHERE user_id = ?",
            // 11. 유저 본체
            "DELETE FROM users WHERE id = ?",
        };

        int totalDeleted = 0;
        for (String sql : sqls) {
            try {
                // ?의 개수만큼 파라미터 채우기
                int paramCount = (int) sql.chars().filter(c -> c == '?').count();
                Object[] params = new Object[paramCount];
                java.util.Arrays.fill(params, userId);
                totalDeleted += jdbc.update(sql, params);
            } catch (Exception ignored) {
            }
        }

        return Map.of(
                "userId", userId,
                "nickname", nickname,
                "deletedRows", totalDeleted,
                "message", "유저 및 연관 데이터 완전 삭제 완료"
        );
    }

    @Operation(summary = "유저 일기 전체 삭제", description = "유저의 일기 + AI 태그 + OutboxEvent 삭제. 시드 데이터 재생성용.")
    @DeleteMapping("/api/dev/users/{userId}/diaries")
    public Map<String, Object> deleteUserDiariesApi(@PathVariable Long userId) {
        var jdbc = new org.springframework.jdbc.core.JdbcTemplate(dataSource);
        int deleted = 0;
        deleted += jdbc.update("DELETE FROM diary_keywords WHERE diary_id IN (SELECT id FROM diaries WHERE user_id = ?)", userId);
        deleted += jdbc.update("DELETE FROM outbox_events WHERE aggregate_type = 'DIARY' AND aggregate_id IN (SELECT id FROM diaries WHERE user_id = ?)", userId);
        deleted += jdbc.update("DELETE FROM diaries WHERE user_id = ?", userId);
        return Map.of("userId", userId, "deletedRows", deleted, "message", "일기 및 관련 데이터 삭제 완료");
    }

    @Operation(summary = "교환일기 마감 시간 변경", description = "교환일기 방의 deadlineAt을 현재 시각 + N분으로 변경. 만료 테스트용.")
    @PostMapping("/api/dev/exchange-rooms/{roomId}/set-deadline")
    public Map<String, Object> setDeadline(@PathVariable Long roomId,
                                            @RequestParam(defaultValue = "60") int minutes) {
        var jdbc = new org.springframework.jdbc.core.JdbcTemplate(dataSource);
        LocalDateTime newDeadline = LocalDateTime.now().plusMinutes(minutes);
        int updated = jdbc.update("UPDATE exchange_rooms SET deadline_at = ? WHERE id = ?", newDeadline, roomId);
        if (updated == 0) {
            return Map.of("error", "NOT_FOUND", "message", "교환방 없음: " + roomId);
        }
        return Map.of(
                "roomId", roomId,
                "newDeadlineAt", newDeadline.toString(),
                "message", "deadline을 " + minutes + "분 후로 설정했습니다."
        );
    }

    @Operation(summary = "AI 분석 결과 시뮬레이션", description = "FastAPI 없이 AI 파이프라인 테스트. RabbitMQ에 Mock 분석 결과 발행 → 2~3초 후 diary_keywords에 감정/성격/라이프스타일/톤 태그 저장.")
    @PostMapping("/api/dev/ai/simulate/{diaryId}")
    public Map<String, Object> simulateAiResult(@PathVariable Long diaryId) {
        Diary diary = diaryRepository.findById(diaryId)
                .orElseThrow(() -> new RuntimeException("일기 없음: " + diaryId));

        Random random = new Random();
        // 설계서 4.2~4.4 기준 태그
        List<String> emotions = List.of("기쁨", "슬픔", "감사", "불안", "설렘", "분노", "평온", "외로움",
                "그리움", "희망", "자부심", "후회", "위로", "만족", "기대", "놀라움");
        List<String> lifestyles = List.of("활동적", "비활동적", "외향적", "내향적", "계획적", "즉흥적");
        List<String> tones = List.of("감성적", "이성적", "유머러스");
        List<String> relationships = List.of("적극적 소통", "소극적 소통", "애정표현 적극적",
                "대화형 갈등대응", "독립적", "의존적");

        List<AiAnalysisResultEvent.Tag> tags = List.of(
                new AiAnalysisResultEvent.Tag("EMOTION", emotions.get(random.nextInt(emotions.size())), 0.7 + random.nextDouble() * 0.3),
                new AiAnalysisResultEvent.Tag("LIFESTYLE", lifestyles.get(random.nextInt(lifestyles.size())), 0.6 + random.nextDouble() * 0.3),
                new AiAnalysisResultEvent.Tag("RELATIONSHIP_STYLE", relationships.get(random.nextInt(relationships.size())), 0.6 + random.nextDouble() * 0.3),
                new AiAnalysisResultEvent.Tag("TONE", tones.get(random.nextInt(tones.size())), 0.6 + random.nextDouble() * 0.3)
        );

        var result = new AiAnalysisResultEvent.Result(
                "AI 요약: 일상의 소소한 행복을 담은 따뜻한 일기입니다.",
                "DAILY",
                tags
        );

        var event = new AiAnalysisResultEvent(
                UUID.randomUUID().toString(), null, "v1",
                AiAnalysisResultType.DIARY_ANALYSIS_COMPLETED,
                diaryId, diary.getUser().getId(),
                null, null,
                ZonedDateTime.now(ZoneId.of("Asia/Seoul")).format(DateTimeFormatter.ISO_OFFSET_DATE_TIME),
                null, result, null, null, null, null
        );

        rabbitTemplate.convertAndSend("ai.exchange", "ai.result.v1", event);

        return Map.of(
                "diaryId", diaryId,
                "status", "SIMULATED",
                "message", "AI 분석 결과가 ai.result.q에 발행되었습니다. 2~3초 후 반영됩니다.",
                "tags", tags.stream().map(t -> t.type() + ":" + t.label()).toList()
        );
    }

    // ── Redis Dev API ─────────────────────────────────────────────────────

    @Operation(summary = "Redis 캐시 전체 요약", description = "캐시 카테고리별 키 수 + 총 키 수 조회. AI:DIARY, MATCHING:RECO, MSG:SEQ 등 카테고리로 분류.")
    @GetMapping("/api/dev/redis/summary")
    public Map<String, Object> redisSummary() {
        Set<String> allKeys = stringRedisTemplate.keys("*");
        if (allKeys == null) allKeys = Set.of();

        // 카테고리별 분류
        Map<String, List<String>> grouped = new LinkedHashMap<>();
        for (String key : allKeys) {
            String category = key.contains(":") ? key.substring(0, key.indexOf(":")) : "OTHER";
            // 세부 카테고리 (AI:DIARY → AI:DIARY)
            if (key.startsWith("AI:")) {
                String[] parts = key.split(":");
                category = parts.length >= 2 ? parts[0] + ":" + parts[1] : parts[0];
            } else if (key.startsWith("MATCHING:RECO")) {
                category = "MATCHING:RECO";
            } else if (key.startsWith("MSG:SEQ")) {
                category = "MSG:SEQ";
            }
            grouped.computeIfAbsent(category, k -> new ArrayList<>()).add(key);
        }

        Map<String, Object> summary = new LinkedHashMap<>();
        summary.put("totalKeys", allKeys.size());
        Map<String, Object> categories = new LinkedHashMap<>();
        grouped.forEach((cat, keys) -> {
            Map<String, Object> info = new LinkedHashMap<>();
            info.put("count", keys.size());
            info.put("keys", keys.size() <= 20 ? keys : keys.subList(0, 20));
            categories.put(cat, info);
        });
        summary.put("categories", categories);
        return summary;
    }

    @Operation(summary = "Redis 키 조회", description = "특정 키의 값 + TTL(초) 조회.")
    @GetMapping("/api/dev/redis/get")
    public Map<String, Object> redisGet(@RequestParam String key) {
        String value = stringRedisTemplate.opsForValue().get(key);
        Long ttl = stringRedisTemplate.getExpire(key, TimeUnit.SECONDS);
        boolean exists = Boolean.TRUE.equals(stringRedisTemplate.hasKey(key));

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("key", key);
        result.put("exists", exists);
        result.put("value", value);
        result.put("ttlSeconds", ttl);
        return result;
    }

    @Operation(summary = "Redis 키 패턴 검색", description = "패턴으로 Redis 키 검색. 예: AI:DIARY:*, MATCHING:RECO:*, MSG:SEQ:*")
    @GetMapping("/api/dev/redis/keys")
    public Map<String, Object> redisKeys(@RequestParam String pattern) {
        Set<String> keys = stringRedisTemplate.keys(pattern);
        if (keys == null) keys = Set.of();

        List<Map<String, Object>> items = new ArrayList<>();
        for (String key : keys) {
            Long ttl = stringRedisTemplate.getExpire(key, TimeUnit.SECONDS);
            String type = String.valueOf(stringRedisTemplate.type(key));
            items.add(Map.of("key", key, "ttlSeconds", ttl != null ? ttl : -1, "type", type));
        }

        return Map.of(
                "pattern", pattern,
                "count", keys.size(),
                "keys", items
        );
    }

    @Operation(summary = "Redis 키 삭제", description = "특정 Redis 키 삭제. 캐시 무효화 테스트용.")
    @DeleteMapping("/api/dev/redis/delete")
    public Map<String, Object> redisDelete(@RequestParam String key) {
        boolean deleted = Boolean.TRUE.equals(stringRedisTemplate.delete(key));
        return Map.of("key", key, "deleted", deleted);
    }

    @Operation(summary = "유저별 Redis 캐시 현황", description = "userId 기준으로 AI 분석, 매칭 추천, RT, 채팅 시퀀스 등 관련 캐시 키 현황 조회.")
    @GetMapping("/api/dev/redis/user/{userId}")
    public Map<String, Object> redisUserKeys(@PathVariable Long userId) {
        List<String> patterns = List.of(
                "AI:DIARY:*",           // 일기 AI 분석 캐시
                "AI:LIFESTYLE:" + userId,   // 라이프스타일 분석
                "AI:SIMILARITY:" + userId + ":*", // 유사도 캐시
                "MATCHING:RECO:" + userId,  // 매칭 추천 (fresh)
                "MATCHING:RECO:stale:" + userId, // 매칭 추천 (stale)
                "RT:" + userId,             // Refresh Token
                "MSG:SEQ:*"                // 채팅 시퀀스
        );

        Map<String, Object> userCache = new LinkedHashMap<>();
        for (String pattern : patterns) {
            if (pattern.contains("*")) {
                Set<String> keys = stringRedisTemplate.keys(pattern);
                if (keys != null && !keys.isEmpty()) {
                    for (String key : keys) {
                        Long ttl = stringRedisTemplate.getExpire(key, TimeUnit.SECONDS);
                        userCache.put(key, Map.of("exists", true, "ttlSeconds", ttl != null ? ttl : -1));
                    }
                }
            } else {
                boolean exists = Boolean.TRUE.equals(stringRedisTemplate.hasKey(pattern));
                if (exists) {
                    Long ttl = stringRedisTemplate.getExpire(pattern, TimeUnit.SECONDS);
                    userCache.put(pattern, Map.of("exists", true, "ttlSeconds", ttl != null ? ttl : -1));
                } else {
                    userCache.put(pattern, Map.of("exists", false));
                }
            }
        }

        // 공통 캐시도 포함
        for (String commonKey : List.of("NOTICE:ALL", "BANNER:ALL", "FAQ:ALL", "BANNED_WORDS:ALL", "URL_WHITELIST")) {
            boolean exists = Boolean.TRUE.equals(stringRedisTemplate.hasKey(commonKey));
            Long ttl = exists ? stringRedisTemplate.getExpire(commonKey, TimeUnit.SECONDS) : null;
            userCache.put(commonKey, Map.of("exists", exists, "ttlSeconds", ttl != null ? ttl : -1));
        }

        return Map.of("userId", userId, "cache", userCache);
    }

    @Operation(summary = "교환일기 강제 완주", description = "교환일기 방을 4턴 완료 상태로 강제 변경. 관계 확장 테스트용.")
    @PostMapping("/api/dev/exchange-rooms/{roomId}/force-complete")
    @Transactional
    public Map<String, Object> forceComplete(@PathVariable Long roomId) {
        ExchangeRoom room = exchangeRoomRepository.findById(roomId)
                .orElseThrow(() -> new RuntimeException("교환방 없음: " + roomId));

        // 강제로 4턴 완료 처리
        while (room.getTurnCount() < 4) {
            room.advanceTurn();
        }

        return Map.of(
                "roomId", roomId,
                "status", room.getStatus().name(),
                "turnCount", room.getTurnCount(),
                "message", "교환일기 방을 강제 완료 처리했습니다."
        );
    }
}
