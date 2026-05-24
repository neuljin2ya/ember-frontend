package com.ember.ember.matching.service;

import com.ember.ember.diary.domain.Diary;
import com.ember.ember.diary.domain.DiaryKeyword;
import com.ember.ember.diary.repository.DiaryKeywordRepository;
import com.ember.ember.diary.repository.DiaryRepository;
import com.ember.ember.exchange.domain.ExchangeRoom;
import com.ember.ember.exchange.repository.ExchangeRoomRepository;
import com.ember.ember.cache.service.CacheService;
import com.ember.ember.global.exception.BusinessException;
import com.ember.ember.global.notification.FcmService;
import com.ember.ember.global.response.ErrorCode;
import com.ember.ember.matching.domain.Matching;
import com.ember.ember.matching.domain.MatchingPass;
import com.ember.ember.matching.dto.*;
import com.ember.ember.matching.repository.MatchingPassRepository;
import com.ember.ember.matching.repository.MatchingRepository;
import com.ember.ember.notification.domain.Notification;
import com.ember.ember.notification.repository.NotificationRepository;
import com.ember.ember.user.domain.User;
import com.ember.ember.user.repository.UserRepository;
import com.ember.ember.matching.service.SimilarityService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ExploreService {

    private static final ZoneId KST = ZoneId.of("Asia/Seoul");
    private static final int EXPLORE_PAGE_SIZE = 10;
    private static final int MIN_DIARY_COUNT = 3;
    private static final int MAX_CONCURRENT_EXCHANGE = 3;
    private static final int SKIP_EXCLUDE_DAYS = 7;

    private final DiaryRepository diaryRepository;
    private final DiaryKeywordRepository diaryKeywordRepository;
    private final UserRepository userRepository;
    private final MatchingRepository matchingRepository;
    private final MatchingPassRepository matchingPassRepository;
    private final ExchangeRoomRepository exchangeRoomRepository;
    private final NotificationRepository notificationRepository;
    private final FcmService fcmService;
    private final SimilarityService similarityService;
    private final CacheService cacheService;
    private final MatchingService matchingService;

    /**
     * 5.1 일기 탐색 (Pull 방식) — 커서 기반 페이징, 정렬/필터 지원
     */
    public ExploreResponse explore(Long userId, Long cursor, String sort, String sido, String sigungu, String ageGroup, boolean keywordFilter) {
        // 매칭 조건 체크: 누적 일기 3개 이상
        long diaryCount = diaryRepository.countByUserId(userId);
        if (diaryCount < MIN_DIARY_COUNT) {
            throw new BusinessException(ErrorCode.MATCHING_NO_DIARY);
        }

        // sort=recommended 분기: AI 추천순
        if ("recommended".equalsIgnoreCase(sort)) {
            return exploreRecommended(userId, sido, sigungu, ageGroup);
        }

        // 제외 대상: 7일 이내 skip한 사용자
        List<Long> skippedUserIds = matchingPassRepository.findSkippedUserIdsSince(
                userId, LocalDateTime.now().minusDays(SKIP_EXCLUDE_DAYS));

        // 빈 리스트 방지 (JPA IN 절에 빈 리스트 방어)
        List<Long> excludeUserIds = skippedUserIds.isEmpty() ? List.of(0L) : skippedUserIds;

        List<Diary> diaries;
        if (cursor == null || cursor == 0) {
            diaries = diaryRepository.findExploreFirstPage(userId, excludeUserIds, PageRequest.of(0, EXPLORE_PAGE_SIZE + 1));
        } else {
            diaries = diaryRepository.findExploreWithCursor(userId, excludeUserIds, cursor, PageRequest.of(0, EXPLORE_PAGE_SIZE + 1));
        }

        // 지역 필터 (시/도 + 시/군/구)
        if (sido != null && !sido.isBlank()) {
            diaries = diaries.stream()
                    .filter(d -> sido.equals(d.getUser().getSido()))
                    .collect(Collectors.toList());
        }
        if (sigungu != null && !sigungu.isBlank()) {
            diaries = diaries.stream()
                    .filter(d -> sigungu.equals(d.getUser().getSigungu()))
                    .collect(Collectors.toList());
        }

        // 나이대 필터
        if (ageGroup != null && !ageGroup.isBlank()) {
            diaries = diaries.stream()
                    .filter(d -> ageGroup.equals(getAgeGroupLabel(d.getUser().getBirthDate())))
                    .collect(Collectors.toList());
        }

        boolean hasNext = diaries.size() > EXPLORE_PAGE_SIZE;
        if (hasNext) {
            diaries = diaries.subList(0, EXPLORE_PAGE_SIZE);
        }

        // 카드에 키워드 표시를 위해 일기 ID 배치 조회
        List<Long> diaryIds = diaries.stream().map(Diary::getId).collect(Collectors.toList());
        Map<Long, List<DiaryKeyword>> keywordMap = diaryIds.isEmpty()
                ? Map.of()
                : diaryKeywordRepository.findByDiaryIdIn(diaryIds).stream()
                    .collect(Collectors.groupingBy(k -> k.getDiary().getId()));

        List<ExploreResponse.ExploreDiaryItem> items = diaries.stream()
                .map(d -> toExploreItem(userId, d, keywordMap.getOrDefault(d.getId(), List.of())))
                .collect(Collectors.toList());

        Long nextCursor = hasNext && !items.isEmpty()
                ? diaries.get(diaries.size() - 1).getId()
                : null;

        String actualSort = "latest";

        String guidanceMessage = items.isEmpty() ? "새로운 일기가 올라오면 알려드릴게요!" : null;

        return new ExploreResponse(items, nextCursor, hasNext, guidanceMessage, actualSort);
    }

    /**
     * AI 추천순 탐색.
     * MatchingService에서 추천 userId 목록을 가져온 뒤,
     * 각 유저의 최신 일기를 조회하여 explore 카드 형태로 반환한다.
     */
    private static final String RECO_CACHE_FRESH = "MATCHING:RECO:%d";
    private static final String RECO_CACHE_STALE = "MATCHING:RECO:stale:%d";

    private ExploreResponse exploreRecommended(Long userId, String sido, String sigungu, String ageGroup) {
        try {
            // 캐시에서 직접 읽기 (MatchingService 트랜잭션 충돌 회피)
            String freshKey = String.format(RECO_CACHE_FRESH, userId);
            String staleKey = String.format(RECO_CACHE_STALE, userId);
            Optional<RecommendationResponse> cached = cacheService.get(freshKey, RecommendationResponse.class);
            if (cached.isEmpty()) {
                cached = cacheService.get(staleKey, RecommendationResponse.class);
            }
            if (cached.isEmpty()) {
                // 캐시 없으면 별도 스레드에서 추천 계산 (트랜잭션 분리)
                try {
                    RecommendationResponse fresh = CompletableFuture.supplyAsync(() ->
                            matchingService.getRecommendations(userId).response()
                    ).get(15, TimeUnit.SECONDS);
                    cached = Optional.of(fresh);
                } catch (Exception ex) {
                    log.warn("[ExploreService] 추천 계산 실패 — userId={}, error={}", userId, ex.getMessage());
                    return new ExploreResponse(List.of(), null, false,
                            "아직 추천할 상대가 없어요. 일기를 더 작성해보세요!", "recommended");
                }
            }
            List<RecommendationItem> recoItems = cached.get().getItems();

            if (recoItems.isEmpty()) {
                return new ExploreResponse(List.of(), null, false, "아직 추천할 상대가 없어요. 일기를 더 작성해보세요!", "recommended");
            }

            // 추천 유저들의 최신 일기 배치 조회
            List<Long> recoUserIds = recoItems.stream()
                    .map(RecommendationItem::getUserId)
                    .collect(Collectors.toList());

            List<Diary> allDiaries = diaryRepository.findLatestDiaryPerUserIn(recoUserIds);

            // userId → 최신 Diary 매핑 (이미 id DESC 정렬이므로 첫 번째가 최신)
            Map<Long, Diary> userDiaryMap = new LinkedHashMap<>();
            for (Diary d : allDiaries) {
                userDiaryMap.putIfAbsent(d.getUser().getId(), d);
            }
            List<Diary> latestDiaries = new ArrayList<>(userDiaryMap.values());

            // 키워드 배치 조회
            List<Long> diaryIds = latestDiaries.stream().map(Diary::getId).collect(Collectors.toList());
            Map<Long, List<DiaryKeyword>> keywordMap = diaryIds.isEmpty()
                    ? Map.of()
                    : diaryKeywordRepository.findByDiaryIdIn(diaryIds).stream()
                        .collect(Collectors.groupingBy(k -> k.getDiary().getId()));

            // 추천 순서 유지하며 카드 생성 (추천 전용 필드 포함)
            List<ExploreResponse.ExploreDiaryItem> items = recoItems.stream()
                    .filter(r -> userDiaryMap.containsKey(r.getUserId()))
                    .map(r -> {
                        Diary diary = userDiaryMap.get(r.getUserId());
                        ExploreResponse.ExploreDiaryItem item = toExploreItem(userId, diary, keywordMap.getOrDefault(diary.getId(), List.of()));
                        // recommended 전용: 매칭 점수 + breakdown 주입
                        return ExploreResponse.ExploreDiaryItem.builder()
                                .diaryId(item.getDiaryId())
                                .authorId(item.getAuthorId())
                                .ageGroupLabel(item.getAgeGroupLabel())
                                .sido(item.getSido())
                                .sigungu(item.getSigungu())
                                .previewContent(item.getPreviewContent())
                                .category(item.getCategory())
                                .createdAt(item.getCreatedAt())
                                .similarityBadge(item.getSimilarityBadge())
                                .personalityKeywords(item.getPersonalityKeywords())
                                .moodTags(item.getMoodTags())
                                .matchingScore(r.getMatchingScore())
                                .keywordOverlap(r.getBreakdown() != null ? r.getBreakdown().getKeywordOverlap() : null)
                                .cosineSimilarity(r.getBreakdown() != null ? r.getBreakdown().getCosineSimilarity() : null)
                                .build();
                    })
                    .collect(Collectors.toList());

            // 지역/연령대 필터 적용
            if (sido != null && !sido.isBlank()) {
                items = items.stream().filter(i -> sido.equals(i.getSido())).collect(Collectors.toList());
            }
            if (sigungu != null && !sigungu.isBlank()) {
                items = items.stream().filter(i -> sigungu.equals(i.getSigungu())).collect(Collectors.toList());
            }
            if (ageGroup != null && !ageGroup.isBlank()) {
                items = items.stream().filter(i -> i.getAgeGroupLabel() != null && i.getAgeGroupLabel().contains(ageGroup)).collect(Collectors.toList());
            }

            return new ExploreResponse(items, null, false, null, "recommended");

        } catch (Exception e) {
            log.error("[ExploreService] 추천순 조회 실패 — userId={}, error={}", userId, e.getMessage(), e);
            return new ExploreResponse(List.of(), null, false, "추천을 불러오는 중 문제가 발생했어요.", "recommended");
        }
    }

    /**
     * 5.1-2 탐색 일기 상세 조회
     */
    public DiaryDetailExploreResponse detail(Long userId, Long diaryId) {
        Diary diary = diaryRepository.findById(diaryId)
                .orElseThrow(() -> new BusinessException(ErrorCode.DIARY_NOT_FOUND));

        if (diary.getUser().getId().equals(userId)) {
            throw new BusinessException(ErrorCode.MATCHING_SELF_REQUEST);
        }

        User author = diary.getUser();

        // AI 키워드
        List<DiaryKeyword> keywords = diaryKeywordRepository.findByDiaryId(diaryId);
        List<String> personalityKeywords = keywords.stream()
                .filter(k -> k.getTagType() == DiaryKeyword.TagType.LIFESTYLE || k.getTagType() == DiaryKeyword.TagType.EMOTION)
                .map(DiaryKeyword::getLabel).limit(3).collect(Collectors.toList());
        List<String> moodTags = keywords.stream()
                .filter(k -> k.getTagType() == DiaryKeyword.TagType.TONE)
                .map(DiaryKeyword::getLabel).limit(2).collect(Collectors.toList());

        // 작성자의 다른 일기 프리뷰 (최대 5건)
        List<Diary> otherDiaries = diaryRepository.findRecentByUserId(author.getId(), PageRequest.of(0, 6));
        List<DiaryDetailExploreResponse.OtherDiaryPreview> otherPreviews = otherDiaries.stream()
                .filter(d -> !d.getId().equals(diaryId))
                .limit(5)
                .map(d -> DiaryDetailExploreResponse.OtherDiaryPreview.builder()
                        .diaryId(d.getId())
                        .summary(d.getSummary())
                        .createdAt(d.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
                        .build())
                .collect(Collectors.toList());

        return DiaryDetailExploreResponse.builder()
                .diaryId(diaryId)
                .authorId(author.getId())
                .ageGroupLabel(getAgeGroupLabel(author.getBirthDate()))
                .content(diary.getContent())
                .summary(diary.getSummary())
                .keywords(personalityKeywords)
                .moodTags(moodTags)
                .category(diary.getCategory())
                .createdAt(diary.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
                .similarityBadge(similarityService.getSimilarityBadge(userId, author.getId()))
                .otherDiariesPreview(otherPreviews)
                .build();
    }

    /**
     * 5.2 블라인드 미리보기
     */
    public DiaryPreviewResponse preview(Long userId, Long diaryId) {
        Diary diary = diaryRepository.findById(diaryId)
                .orElseThrow(() -> new BusinessException(ErrorCode.DIARY_NOT_FOUND));

        // 본인 일기 조회 방지
        if (diary.getUser().getId().equals(userId)) {
            throw new BusinessException(ErrorCode.MATCHING_SELF_REQUEST);
        }

        User author = diary.getUser();

        // AI 키워드 조회
        List<DiaryKeyword> keywords = diaryKeywordRepository.findByDiaryId(diaryId);
        List<String> personalityKeywords = keywords.stream()
                .filter(k -> k.getTagType() == DiaryKeyword.TagType.LIFESTYLE || k.getTagType() == DiaryKeyword.TagType.EMOTION)
                .map(DiaryKeyword::getLabel)
                .limit(3)
                .collect(Collectors.toList());
        List<String> moodTags = keywords.stream()
                .filter(k -> k.getTagType() == DiaryKeyword.TagType.TONE)
                .map(DiaryKeyword::getLabel)
                .limit(2)
                .collect(Collectors.toList());

        // 4줄 미리보기
        String preview = truncateToLines(diary.getContent(), 4);

        return DiaryPreviewResponse.builder()
                .diaryId(diaryId)
                .ageGroup(getAgeGroupLabel(author.getBirthDate()))
                .preview(preview)
                .keywords(personalityKeywords)
                .tags(moodTags)
                .aiIntro(diary.getSummary())
                .category(diary.getCategory())
                .matchScore(null)
                .similarityBadge(similarityService.getSimilarityBadge(userId, author.getId()))
                .build();
    }

    /**
     * 5.3 라이프스타일 리포트
     */
    public LifestyleReportResponse getLifestyleReport(Long userId) {
        long totalCount = diaryRepository.countByUserId(userId);
        int requiredCount = 5;

        if (totalCount < requiredCount) {
            return LifestyleReportResponse.builder()
                    .analysisAvailable(false)
                    .requiredDiaryCount(requiredCount)
                    .currentDiaryCount((int) totalCount)
                    .guidanceMessage("일기 " + (requiredCount - totalCount) + "편을 더 작성하면 리포트를 확인할 수 있어요!")
                    .build();
        }

        // 최근 일기 20편 기반 분석
        List<Diary> recentDiaries = diaryRepository.findRecentByUserId(userId, PageRequest.of(0, 20));

        // 활동 히트맵 (작성 시간대 분포)
        List<LifestyleReportResponse.ActivityHeatmapItem> heatmap = buildHeatmap(recentDiaries);

        // 평일/주말 패턴
        long weekdayCount = recentDiaries.stream()
                .filter(d -> d.getDate().getDayOfWeek().getValue() <= 5).count();
        long weekendCount = recentDiaries.size() - weekdayCount;

        // 평균 일기 길이
        int avgLength = (int) recentDiaries.stream()
                .mapToInt(d -> d.getContent().length())
                .average().orElse(0);

        // 공통 키워드 (AI 분석된 키워드 기준)
        List<Long> diaryIds = recentDiaries.stream().map(Diary::getId).collect(Collectors.toList());
        List<String> commonKeywords = findCommonKeywords(diaryIds);

        // 라이프스타일 태그
        List<String> lifestyleTags = findLifestyleTags(diaryIds);

        // 감정 표현 점수 (EMOTION 태그 평균 score)
        Double emotionScore = diaryKeywordRepository.findByDiaryIdIn(diaryIds).stream()
                .filter(dk -> dk.getTagType() == DiaryKeyword.TagType.EMOTION)
                .mapToDouble(dk -> dk.getScore().doubleValue())
                .average()
                .orElse(0.0);
        emotionScore = Math.round(emotionScore * 100.0) / 100.0;

        // AI 라이프스타일 설명 문구 생성
        String aiDescription = buildAiDescription(commonKeywords, lifestyleTags, emotionScore);

        return LifestyleReportResponse.builder()
                .analysisAvailable(true)
                .requiredDiaryCount(requiredCount)
                .currentDiaryCount((int) totalCount)
                .activityHeatmap(heatmap)
                .weekdayPattern(LifestyleReportResponse.WeekdayPattern.builder()
                        .weekday((int) weekdayCount)
                        .weekend((int) weekendCount)
                        .build())
                .emotionGraph(emotionScore)
                .avgDiaryLength(avgLength)
                .commonKeywords(commonKeywords)
                .aiDescription(aiDescription)
                .lifestyleTags(lifestyleTags)
                .guidanceMessage(null)
                .build();
    }

    /**
     * 받은 매칭 요청 목록 조회
     */
    public List<MatchingRequestItem> getReceivedRequests(Long userId) {
        List<Matching> requests = matchingRepository.findReceivedRequests(
                userId, Matching.MatchingStatus.PENDING);

        return requests.stream().map(m -> {
            User fromUser = m.getFromUser();
            Diary diary = m.getDiary();
            String preview = diary.getContent().length() > 80
                    ? diary.getContent().substring(0, 80) + "..."
                    : diary.getContent();

            return MatchingRequestItem.builder()
                    .matchingId(m.getId())
                    .fromUserId(fromUser.getId())
                    .fromUserNickname(fromUser.getNickname())
                    .fromUserAgeGroup(getAgeGroupLabel(fromUser.getBirthDate()))
                    .diaryId(diary.getId())
                    .diaryPreview(preview)
                    .requestedAt(m.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
                    .build();
        }).collect(Collectors.toList());
    }

    /**
     * 받은 매칭 요청 수락 (상대방 일기 역선택 → 매칭 성사)
     */
    @Transactional
    public MatchingSelectResponse acceptRequest(Long userId, Long matchingId) {
        Matching request = matchingRepository.findById(matchingId)
                .orElseThrow(() -> new BusinessException(ErrorCode.MATCHING_NOT_FOUND));

        // 본인에게 온 요청인지 확인
        if (!request.getToUser().getId().equals(userId)) {
            throw new BusinessException(ErrorCode.ACCESS_DENIED);
        }

        if (request.getStatus() != Matching.MatchingStatus.PENDING) {
            throw new BusinessException(ErrorCode.MATCHING_ALREADY_REQUESTED);
        }

        // 동시 교환 3건 제한
        long activeCount = matchingRepository.countActiveExchangesByUserId(userId);
        if (activeCount >= MAX_CONCURRENT_EXCHANGE) {
            throw new BusinessException(ErrorCode.MATCHING_CONCURRENT_LIMIT);
        }

        // 양방향 매칭 성사
        request.markMatched();

        User fromUser = request.getFromUser();
        User toUser = request.getToUser();

        ExchangeRoom room = createExchangeRoom(request, fromUser, toUser);

        sendMatchedNotification(fromUser, toUser, room);
        sendMatchedNotification(toUser, fromUser, room);

        log.info("[ExploreService] 매칭 수락 → 성사 — matchingId={}, roomUuid={}",
                matchingId, room.getRoomUuid());

        return MatchingSelectResponse.builder()
                .matchingId(matchingId)
                .isMatched(true)
                .roomUuid(room.getRoomUuid().toString())
                .build();
    }

    /**
     * 5.4-1 교환 신청 (select)
     */
    @Transactional
    public MatchingSelectResponse select(Long userId, Long diaryId) {
        User fromUser = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.ACCOUNT_NOT_FOUND));

        Diary diary = diaryRepository.findById(diaryId)
                .orElseThrow(() -> new BusinessException(ErrorCode.DIARY_NOT_FOUND));

        User toUser = diary.getUser();

        // 검증: 자기 자신
        if (toUser.getId().equals(userId)) {
            throw new BusinessException(ErrorCode.MATCHING_SELF_REQUEST);
        }

        // 검증: 중복 PENDING 신청
        if (matchingRepository.existsByFromUserIdAndToUserIdAndStatus(
                userId, toUser.getId(), Matching.MatchingStatus.PENDING)) {
            throw new BusinessException(ErrorCode.MATCHING_ALREADY_REQUESTED);
        }

        // 검증: 동시 교환 3건 제한
        long activeCount = matchingRepository.countActiveExchangesByUserId(userId);
        if (activeCount >= MAX_CONCURRENT_EXCHANGE) {
            throw new BusinessException(ErrorCode.MATCHING_CONCURRENT_LIMIT);
        }

        // 매칭 요청 생성
        Matching matching = Matching.create(fromUser, toUser, diary);
        matchingRepository.save(matching);

        // 역방향 PENDING 조회 (양방향 매칭 감지, 비관적 락으로 동시성 보호)
        Optional<Matching> reverseMatching = matchingRepository.findByFromUserIdAndToUserIdAndStatusForUpdate(
                toUser.getId(), userId, Matching.MatchingStatus.PENDING);

        if (reverseMatching.isPresent()) {
            // 양방향 매칭 성사!
            matching.markMatched();
            reverseMatching.get().markMatched();

            // ExchangeRoom 생성
            ExchangeRoom room = createExchangeRoom(matching, fromUser, toUser);

            // 양쪽 알림
            sendMatchedNotification(fromUser, toUser, room);
            sendMatchedNotification(toUser, fromUser, room);

            log.info("[ExploreService] 매칭 성사 — fromUserId={}, toUserId={}, roomUuid={}",
                    userId, toUser.getId(), room.getRoomUuid());

            return MatchingSelectResponse.builder()
                    .matchingId(matching.getId())
                    .isMatched(true)
                    .roomUuid(room.getRoomUuid().toString())
                    .build();
        }

        // 단방향 신청 → 상대방에게 알림
        sendRequestNotification(fromUser, toUser);

        log.info("[ExploreService] 매칭 신청 — fromUserId={}, toUserId={}, matchingId={}",
                userId, toUser.getId(), matching.getId());

        return MatchingSelectResponse.builder()
                .matchingId(matching.getId())
                .isMatched(false)
                .roomUuid(null)
                .build();
    }

    /**
     * 5.4-2 넘기기 (skip)
     */
    @Transactional
    public void skip(Long userId, Long diaryId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new BusinessException(ErrorCode.ACCOUNT_NOT_FOUND));

        Diary diary = diaryRepository.findById(diaryId)
                .orElseThrow(() -> new BusinessException(ErrorCode.DIARY_NOT_FOUND));

        MatchingPass pass = MatchingPass.create(user, diary, diary.getUser());
        matchingPassRepository.save(pass);

        log.debug("[ExploreService] skip — userId={}, diaryId={}, targetUserId={}",
                userId, diaryId, diary.getUser().getId());
    }

    // ──────────────────────────────────────────────────────────────────
    // Private 헬퍼
    // ──────────────────────────────────────────────────────────────────

    private ExploreResponse.ExploreDiaryItem toExploreItem(Long userId, Diary diary, List<DiaryKeyword> keywords) {
        User author = diary.getUser();
        String previewContent = diary.getContent().length() > 80
                ? diary.getContent().substring(0, 80) + "..."
                : diary.getContent();

        // 성격 키워드 상위 3개 (감정 + 라이프스타일)
        List<String> personalityKeywords = keywords.stream()
                .filter(k -> k.getTagType() == DiaryKeyword.TagType.EMOTION || k.getTagType() == DiaryKeyword.TagType.LIFESTYLE)
                .map(DiaryKeyword::getLabel)
                .limit(3)
                .collect(Collectors.toList());

        // 분위기 태그 (톤)
        List<String> moodTags = keywords.stream()
                .filter(k -> k.getTagType() == DiaryKeyword.TagType.TONE)
                .map(DiaryKeyword::getLabel)
                .limit(2)
                .collect(Collectors.toList());

        return ExploreResponse.ExploreDiaryItem.builder()
                .diaryId(diary.getId())
                .authorId(author.getId())
                .ageGroupLabel(getAgeGroupLabel(author.getBirthDate()))
                .sido(author.getSido())
                .sigungu(author.getSigungu())
                .previewContent(previewContent)
                .category(diary.getCategory())
                .createdAt(diary.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME))
                .similarityBadge(similarityService.getSimilarityBadge(userId, author.getId()))
                .personalityKeywords(personalityKeywords)
                .moodTags(moodTags)
                .build();
    }

    private String getAgeGroupLabel(LocalDate birthDate) {
        if (birthDate == null) return "비공개";
        int age = (int) ChronoUnit.YEARS.between(birthDate, LocalDate.now(KST));
        if (age < 20) return "10대";
        if (age < 30) return "20대";
        if (age < 40) return "30대";
        return "40대";
    }

    private String truncateToLines(String content, int maxLines) {
        String[] lines = content.split("\n");
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < Math.min(lines.length, maxLines); i++) {
            if (i > 0) sb.append("\n");
            sb.append(lines[i]);
        }
        if (sb.length() > 200) return sb.substring(0, 200) + "...";
        return sb.toString();
    }

    private ExchangeRoom createExchangeRoom(Matching matching, User userA, User userB) {
        // ExchangeRoom 팩토리 — 직접 리플렉션 없이 Repository save
        ExchangeRoom room = ExchangeRoom.create(userA, userB, matching);
        return exchangeRoomRepository.save(room);
    }

    private void sendRequestNotification(User fromUser, User toUser) {
        String title = "새로운 교환일기 신청";
        String body = fromUser.getNickname() + "님이 일기를 선택했어요. 관심을 표현해보세요!";
        Notification notification = Notification.create(
                toUser, "MATCHING_REQUEST", title, body, "/matching/requests");
        notificationRepository.save(notification);
        fcmService.sendPushToUser(toUser.getId(), title, body);

        log.info("[알림] MATCHING_REQUEST — toUserId={}, title={}", toUser.getId(), title);
    }

    private void sendMatchedNotification(User target, User partner, ExchangeRoom room) {
        String title = "교환일기가 시작되었어요!";
        String body = partner.getNickname() + "님과 교환일기가 시작되었습니다. 첫 번째 일기를 작성해보세요!";
        String deeplink = "/exchange-rooms/" + room.getId();
        Notification notification = Notification.create(
                target, "MATCHING_MATCHED", title, body, deeplink);
        notificationRepository.save(notification);
        fcmService.sendPushToUser(target.getId(), title, body);

        log.info("[알림] MATCHING_MATCHED — targetUserId={}, roomUuid={}", target.getId(), room.getRoomUuid());
    }

    private List<LifestyleReportResponse.ActivityHeatmapItem> buildHeatmap(List<Diary> diaries) {
        Map<String, Integer> map = new HashMap<>();
        for (Diary d : diaries) {
            if (d.getCreatedAt() != null) {
                int hour = d.getCreatedAt().getHour();
                int day = d.getDate().getDayOfWeek().getValue();
                String key = hour + "_" + day;
                map.merge(key, 1, Integer::sum);
            }
        }
        return map.entrySet().stream()
                .map(e -> {
                    String[] parts = e.getKey().split("_");
                    return LifestyleReportResponse.ActivityHeatmapItem.builder()
                            .hour(Integer.parseInt(parts[0]))
                            .day(Integer.parseInt(parts[1]))
                            .count(e.getValue())
                            .build();
                })
                .collect(Collectors.toList());
    }

    private List<String> findCommonKeywords(List<Long> diaryIds) {
        if (diaryIds.isEmpty()) return List.of();
        // 배치 조회로 N+1 방지
        List<DiaryKeyword> allKeywords = diaryKeywordRepository.findByDiaryIdIn(diaryIds);
        Map<String, Long> freq = new HashMap<>();
        for (DiaryKeyword kw : allKeywords) {
            freq.merge(kw.getLabel(), 1L, Long::sum);
        }
        return freq.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .limit(5)
                .map(Map.Entry::getKey)
                .collect(Collectors.toList());
    }

    private String buildAiDescription(List<String> commonKeywords, List<String> lifestyleTags, Double emotionScore) {
        StringBuilder sb = new StringBuilder();

        if (!lifestyleTags.isEmpty()) {
            sb.append(String.join(", ", lifestyleTags.subList(0, Math.min(3, lifestyleTags.size()))));
            sb.append(" 성향이 돋보이는 사람이에요. ");
        }

        if (emotionScore >= 0.8) {
            sb.append("감정 표현이 풍부하고 ");
        } else if (emotionScore >= 0.5) {
            sb.append("감정을 적절히 표현하며 ");
        } else {
            sb.append("차분하게 감정을 다루며 ");
        }

        if (!commonKeywords.isEmpty()) {
            sb.append("'").append(commonKeywords.get(0)).append("'");
            if (commonKeywords.size() > 1) {
                sb.append(", '").append(commonKeywords.get(1)).append("'");
            }
            sb.append(" 키워드가 자주 등장해요.");
        } else {
            sb.append("일상을 꾸준히 기록하는 습관을 가지고 있어요.");
        }

        return sb.toString();
    }

    private List<String> findLifestyleTags(List<Long> diaryIds) {
        if (diaryIds.isEmpty()) return List.of();
        // 배치 조회로 N+1 방지
        List<DiaryKeyword> allKeywords = diaryKeywordRepository.findByDiaryIdIn(diaryIds);
        Map<String, Long> freq = new HashMap<>();
        allKeywords.stream()
                .filter(k -> k.getTagType() == DiaryKeyword.TagType.LIFESTYLE)
                .forEach(k -> freq.merge(k.getLabel(), 1L, Long::sum));
        return freq.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .limit(5)
                .map(Map.Entry::getKey)
                .collect(Collectors.toList());
    }
}
