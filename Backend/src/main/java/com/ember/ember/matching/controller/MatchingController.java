package com.ember.ember.matching.controller;

import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.global.security.CustomUserDetails;
import com.ember.ember.matching.dto.*;
import com.ember.ember.matching.service.ExploreService;
import com.ember.ember.matching.service.MatchingService;
import com.ember.ember.matching.service.MatchingService.RecommendationResult;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequiredArgsConstructor
@Tag(name = "Matching", description = "매칭 탐색 API")
public class MatchingController {

    private static final String HEADER_DEGRADED = "X-Degraded";

    private final MatchingService matchingService;
    private final ExploreService exploreService;

    /** 5.1 일기 탐색 (Pull 방식) */
    @GetMapping("/api/diaries/explore")
    @Operation(summary = "일기 탐색 (커서 기반 페이징, 정렬/필터 지원)", description = """
        다른 사용자의 일기를 탐색합니다 (카드 스와이프 UI).

        > 📱 **화면:** 5.1 일기 탐색 (Pull 방식) — 화면 진입 / 정렬·필터 변경 시

        **쿼리 파라미터:**
        - `cursor` (선택): 이전 응답의 nextCursor 값
        - `size` (기본 10): 한 번에 가져올 개수
        - `sort` (기본 latest): `latest`(최신순) — AI 추천은 별도 API `GET /api/matching/recommendations` 사용
        - `sido` (선택): 시/도 필터 (예: "서울특별시")
        - `sigungu` (선택): 시/군/구 필터
        - `ageGroup` (선택): 연령대 필터 (예: "20대")
        - `keywordFilter` (기본 false): true이면 내 이상형 키워드와 일치하는 일기만

        **필터링 규칙:**
        - 이성 일기만 노출
        - 차단한/된 유저 제외
        - 이미 매칭 신청/넘긴 일기 제외
        - 교환일기 3건 만석 유저 제외

        **응답 카드:** nickname, ageGroup, sido, sigungu, content(앞 200자), personalityKeywords(상위3), moodTags""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"diaries":[{"diaryId":10,"nickname":"미소짓는풍선","ageGroup":"20대","sido":"서울특별시","sigungu":"강남구","content":"오늘은...","personalityKeywords":["안정 추구","공감 우선"]}],"nextCursor":9,"hasMore":true}}
                """)))
    })
    public ResponseEntity<ApiResponse<ExploreResponse>> explore(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @RequestParam(required = false) Long cursor,
            @RequestParam(defaultValue = "latest") String sort,
            @RequestParam(required = false) String sido,
            @RequestParam(required = false) String sigungu,
            @RequestParam(required = false) String ageGroup,
            @RequestParam(defaultValue = "true") boolean keywordFilter) {
        return ResponseEntity.ok(ApiResponse.success(
                exploreService.explore(userDetails.getUserId(), cursor, sort, sido, sigungu, ageGroup, keywordFilter)));
    }

    /** 5.1-2 탐색 일기 상세 */
    @GetMapping("/api/diaries/{diaryId}/detail")
    @Operation(summary = "탐색 일기 상세 조회 (유사도 배지 + 작성자 다른 일기)", description = """
        탐색에서 선택한 일기의 상세를 조회합니다.

        > 📱 **화면:** 5.1 일기 탐색 — 카드 [자세히 보기] 탭 → 상세 화면

        **응답 포함:**
        - 일기 전체 본문
        - 작성자 성격 키워드 (AI 분석 결과)
        - 작성자의 다른 공개 일기 미리보기 (최대 3건)
        - 유사도 점수/배지 (AI 연동 시)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"diaryId":10,"content":"오늘은...","personalityKeywords":["안정 추구"],"otherDiaries":[{"diaryId":11,"preview":"어제는..."}]}}
                """)))
    })
    public ResponseEntity<ApiResponse<DiaryDetailExploreResponse>> diaryDetail(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long diaryId) {
        return ResponseEntity.ok(ApiResponse.success(
                exploreService.detail(userDetails.getUserId(), diaryId)));
    }

    /** 5.2-1 AI 추천 목록 */
    @GetMapping("/api/matching/recommendations")
    @Operation(summary = "AI 기반 추천 일기 목록", description = """
        AI 기반 매칭 추천 목록을 조회합니다.

        > 📱 **화면:** 5.2 추천 일기 블라인드 노출 — 화면 진입 (추천 탭)

        **동작:**
        - KoSimCSE 유사도 기반 상위 추천
        - Redis 캐시(24h) → 만료 시 stale 캐시 폴백 (빈 응답 방지)
        - AI FastAPI 미연동 시 AI003 에러

        **에러:** AI003(AI 매칭 서버 오류)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":[{"diaryId":10,"nickname":"미소짓는풍선","preview":"오늘은...","similarityScore":0.85}]}
                """)))
    })
    public ResponseEntity<ApiResponse<RecommendationResponse>> getRecommendations(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        RecommendationResult result = matchingService.getRecommendations(userDetails.getUserId());

        ResponseEntity.BodyBuilder builder = ResponseEntity.ok();
        if (result.degraded()) {
            builder.header(HEADER_DEGRADED, "true");
            log.info("[MatchingController] stale 폴백 응답 — userId={}", userDetails.getUserId());
        }

        return builder.body(ApiResponse.success(result.response()));
    }

    /** 5.2-2 블라인드 미리보기 */
    @GetMapping("/api/matching/recommendations/{diaryId}/preview")
    @Operation(summary = "추천 일기 블라인드 미리보기", description = """
        추천 일기의 블라인드 미리보기를 조회합니다.

        > 📱 **화면:** 5.2 추천 일기 블라인드 노출 — 블러 카드 [자세히 보기] 탭

        **응답:**
        - 본문 앞 100자만 노출
        - 유사도 배지: 0.7이상 '잘 맞을 것 같아요', 0.5~0.7 '공통점이 있어요'""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"diaryId":10,"preview":"오늘은 정말 좋은...","similarityBadge":"잘 맞을 것 같아요"}}
                """)))
    })
    public ResponseEntity<ApiResponse<DiaryPreviewResponse>> preview(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long diaryId) {
        return ResponseEntity.ok(ApiResponse.success(
                exploreService.preview(userDetails.getUserId(), diaryId)));
    }

    /** 5.3 라이프스타일 리포트 */
    @GetMapping("/api/matching/lifestyle-report")
    @Operation(summary = "라이프스타일 분석 리포트", description = """
        내 라이프스타일 리포트를 조회합니다.

        > 📱 **화면:** 5.3 라이프스타일 리포트 — 탐색 상세(5.2) 하단 "우리의 공통점" 스크롤 섹션

        **활성화 조건:** 일기 5편 이상 작성
        - 5편 미만이면 analysisAvailable=false, requiredDiaryCount=5 반환

        **응답 (활성화 시):**
        - 활동 히트맵, 요일별 패턴, 감정 그래프, 평균 일기 길이 등""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"analysisAvailable":true,"requiredDiaryCount":5,"currentDiaryCount":7}}
                """)))
    })
    public ResponseEntity<ApiResponse<LifestyleReportResponse>> lifestyleReport(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                exploreService.getLifestyleReport(userDetails.getUserId())));
    }

    /** 받은 매칭 요청 목록 */
    @GetMapping("/api/matching/requests")
    @Operation(summary = "받은 매칭 요청 목록 조회", description = """
        받은 매칭 요청 목록을 조회합니다.

        > 📱 **화면:** 5.5 받은 매칭 요청 확인 — 탐색 화면 AppBar ✉️ 아이콘 탭

        **응답:** 요청자 닉네임, 연령대, 일기 미리보기 포함
        - matchingId를 POST /api/matching/requests/{matchingId}/accept에 전달""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":[{"matchingId":1,"nickname":"미소짓는풍선","ageGroup":"20대","preview":"오늘은..."}]}
                """)))
    })
    public ResponseEntity<ApiResponse<java.util.List<MatchingRequestItem>>> getReceivedRequests(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                exploreService.getReceivedRequests(userDetails.getUserId())));
    }

    /** 매칭 요청 수락 */
    @PostMapping("/api/matching/requests/{matchingId}/accept")
    @Operation(summary = "매칭 요청 수락 (매칭 성사)", description = """
        매칭 요청을 수락합니다.

        > 📱 **화면:** 5.5 받은 매칭 요청 확인 — [✅ 수락] 버튼 탭

        **동작:**
        - 매칭 상태 PENDING → MATCHED
        - 교환일기 방 자동 생성 (roomUuid 반환)
        - 양측에게 MATCHING_MATCHED 알림 발송

        **에러:** M006(존재하지 않는 매칭)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "수락 성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"roomUuid":"bf48bc80-4773-4d50-a293-3ba5f7cea823"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "매칭 없음 (M006)",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"M006","message":"매칭 요청을 찾을 수 없습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<MatchingSelectResponse>> acceptRequest(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long matchingId) {
        return ResponseEntity.ok(ApiResponse.success(
                exploreService.acceptRequest(userDetails.getUserId(), matchingId)));
    }

    /** 5.4-1 교환 신청 */
    @PostMapping("/api/matching/{diaryId}/select")
    @Operation(summary = "교환일기 신청 (상대 일기 선택)", description = """
        해당 일기 작성자에게 교환일기를 신청합니다.

        > 📱 **화면:** 5.4 상대방 일기 선택 — 상세 화면 [💌 교환 신청] 버튼 탭

        **동작:**
        - PENDING 상태로 매칭 요청 생성
        - 상대방에게 MATCHING_REQUEST 알림 발송
        - **양방향 매칭 감지:** 상대도 나에게 신청했으면 자동으로 매칭 성사 → 교환일기 방 생성
        - 비관적 락(PESSIMISTIC_WRITE)으로 Race Condition 방지

        **에러:** M001(이미 신청), M003(차단), M004(일기 없음), M005(교환 3건 만석)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "신청 성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"matchingId":1,"status":"PENDING"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "이미 신청한 일기 (M001)",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"M001","message":"이미 매칭 요청을 보낸 상대입니다","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "자기 일기에 신청 (M005)",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"M005","message":"본인의 일기에는 매칭 요청할 수 없습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<MatchingSelectResponse>> select(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long diaryId) {
        return ResponseEntity.ok(ApiResponse.success(
                exploreService.select(userDetails.getUserId(), diaryId)));
    }

    /** 5.4-2 넘기기 (skip) */
    @PostMapping("/api/matching/{diaryId}/skip")
    @Operation(summary = "추천 일기 넘기기 (7일 재추천 제외)", description = """
        해당 일기를 넘깁니다.

        > 📱 **화면:** 5.4 상대방 일기 선택 — [다음 일기 보기] 탭 (skip)

        **동작:** matching_pass 테이블에 기록, 7일간 탐색에서 재노출 방지""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<Void>> skip(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long diaryId) {
        exploreService.skip(userDetails.getUserId(), diaryId);
        return ResponseEntity.ok(ApiResponse.success());
    }
}
