package com.ember.ember.exchange.controller;

import com.ember.ember.exchange.dto.*;
import com.ember.ember.exchange.service.ExchangeService;
import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.global.security.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * 교환일기 컨트롤러 (도메인 6)
 */
@RestController
@RequiredArgsConstructor
@Tag(name = "Exchange", description = "교환일기 API")
public class ExchangeController {

    private final ExchangeService exchangeService;

    /** 5.1 교환일기 방 목록 조회 */
    @GetMapping("/api/exchange-rooms")
    @Operation(summary = "교환일기 방 목록 조회", description = """
        현재 진행 중인 교환일기 방 목록을 조회합니다.

        > 📱 **화면:** 6.1 교환 일기 매칭 성사 및 방 생성 — 화면 진입 (교환 방 목록 탭)

        **응답:** ACTIVE 상태 방만 반환
        - roomId, roomUuid, partnerNickname, status, currentTurn, isMyTurn, lastDiaryAt, deadline
        - isMyTurn=true이면 내가 작성할 차례
        - ⚠️ 하위 API 호출 시 roomId(숫자)를 사용하세요 (roomUuid 아님)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"rooms":[{"roomId":1,"roomUuid":"bf48bc80-...","partnerNickname":"미소짓는풍선","status":"ACTIVE","currentTurn":2,"isMyTurn":true,"lastDiaryAt":"2026-05-01T08:00:00","deadline":"2026-05-03T08:00:00"}]}}
                """)))
    })
    public ResponseEntity<ApiResponse<ExchangeRoomListResponse>> getRooms(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                exchangeService.getRooms(userDetails.getUserId())));
    }

    /** 5.2 교환일기 방 상세 조회 */
    @GetMapping("/api/exchange-rooms/{roomId}")
    @Operation(summary = "교환일기 방 상세 조회", description = """
        > 📱 **화면:** 6.1 교환방 상세 / 6.2 릴레이 작성 / 6.4 제한시간 리마인드 — 방 카드 탭 / 폴링""", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"roomId":1,"partner":{"userId":5,"nickname":"미소짓는풍선"},"status":"ACTIVE","currentTurn":2,"isMyTurn":true,"diaries":[{"diaryId":1,"authorId":5,"content":"오늘은...","reaction":null,"readAt":null,"createdAt":"2026-05-01T08:00:00","turnNumber":1}],"deadline":"2026-05-03T08:00:00","roundNumber":1,"nextStepRequired":false,"nextStepDeadline":null}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "교환방 없음",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"ER001","message":"교환일기 방을 찾을 수 없습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<ExchangeRoomDetailResponse>> getRoomDetail(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long roomId) {
        return ResponseEntity.ok(ApiResponse.success(
                exchangeService.getRoomDetail(userDetails.getUserId(), roomId)));
    }

    /** 5.3 교환일기 개별 열람 */
    @GetMapping("/api/exchange-rooms/{roomId}/diaries/{diaryId}")
    @Operation(summary = "교환일기 개별 열람 (읽음 처리)", description = """
        > 📱 **화면:** 6.2 릴레이 작성 (이전 일기 조회) / 6.3 상대방 일기 수신 (푸시 → 방 진입)""", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"diaryId":1,"content":"오늘은...","turnNumber":1,"readAt":"2026-04-30T10:00:00"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "교환일기 없음",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"ER002","message":"교환일기를 찾을 수 없습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<ExchangeDiaryDetailResponse>> readDiary(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long roomId,
            @PathVariable Long diaryId) {
        return ResponseEntity.ok(ApiResponse.success(
                exchangeService.readDiary(userDetails.getUserId(), roomId, diaryId)));
    }

    /** 5.4 교환일기 작성 */
    @PostMapping("/api/exchange-rooms/{roomId}/diaries")
    @Operation(summary = "교환일기 릴레이 작성 (턴 기반)", description = """
        > 📱 **화면:** 6.2 릴레이 교환 일기 작성 — [제출] 버튼 탭 (내 턴 일기 작성 완료)""", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "작성 성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"201","message":"CREATED","data":{"diaryId":5,"turnNumber":3}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "턴 순서 오류",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"ER003","message":"현재 내 차례가 아닙니다","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "이미 완료된 교환",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"ER004","message":"이미 완료된 교환일기입니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<ExchangeDiaryWriteResponse>> writeDiary(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long roomId,
            @Valid @RequestBody ExchangeDiaryRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(
                exchangeService.writeDiary(userDetails.getUserId(), roomId, request)));
    }

    /** 5.5 리액션 등록 */
    @PostMapping("/api/exchange-rooms/{roomId}/diaries/{diaryId}/reaction")
    @Operation(summary = "교환일기 감정 리액션 등록", description = """
        > 📱 **화면:** 6.3 상대방 일기 수신 / 읽기 전용 + 리액션 — 리액션 버튼 탭""", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "리액션 오류",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"ER005","message":"유효하지 않은 리액션입니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<Void>> addReaction(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long roomId,
            @PathVariable Long diaryId,
            @Valid @RequestBody ReactionRequest request) {
        exchangeService.addReaction(userDetails.getUserId(), roomId, diaryId, request);
        return ResponseEntity.ok(ApiResponse.success());
    }

    /** 5.6 공통점 리포트 조회 */
    @GetMapping("/api/exchange-rooms/{roomId}/report")
    @Operation(summary = "교환일기 공통점 리포트 조회", description = """
        > 📱 **화면:** 6.5 교환 완료 후 '우리의 공통점' AI 리포트 — 교환 2회 왕복 완료 후 진입""", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"reportId":1,"commonTopics":["여행","음식"],"compatibilityScore":0.78,"generatedAt":"2026-04-30T10:00:00"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "202", description = "분석 중",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"ER007","message":"리포트 분석 중입니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<ExchangeReportResponse>> getReport(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long roomId) {
        return ResponseEntity.ok(ApiResponse.success(
                exchangeService.getReport(userDetails.getUserId(), roomId)));
    }

    /** 5.7 관계 확장 선택 */
    @PostMapping("/api/exchange-rooms/{roomId}/next-step")
    @Operation(summary = "관계 확장 방향 선택 (CHAT/CONTINUE)", description = """
        > 📱 **화면:** 7.1 관계 확장 선택 — 채팅/교환 계속/종료 선택 제출""", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"myChoice":"CHAT","bothChosen":true,"result":"CHAT_CREATED"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "이미 선택 완료",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"NS002","message":"이미 관계 확장을 선택했습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<NextStepResponse>> chooseNextStep(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long roomId,
            @Valid @RequestBody NextStepRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                exchangeService.chooseNextStep(userDetails.getUserId(), roomId, request)));
    }

    /** 5.8 관계 확장 선택 상태 조회 */
    @GetMapping("/api/exchange-rooms/{roomId}/next-step/status")
    @Operation(summary = "관계 확장 선택 상태 조회", description = """
        > 📱 **화면:** 7.1 관계 확장 선택 — 결과 대기 폴링 (양측 선택 조회)""", security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"myChoice":"CHAT","partnerChosen":false}}
                """)))
    })
    public ResponseEntity<ApiResponse<NextStepStatusResponse>> getNextStepStatus(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long roomId) {
        return ResponseEntity.ok(ApiResponse.success(
                exchangeService.getNextStepStatus(userDetails.getUserId(), roomId)));
    }
}
