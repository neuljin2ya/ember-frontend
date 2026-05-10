package com.ember.ember.couple.controller;

import com.ember.ember.couple.dto.CoupleAcceptResponse;
import com.ember.ember.couple.dto.CoupleRequestResponse;
import com.ember.ember.couple.service.CoupleService;
import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.global.security.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * 커플 컨트롤러 (도메인 8)
 */
@RestController
@RequiredArgsConstructor
@Tag(name = "Couple", description = "커플 API")
public class CoupleController {

    private final CoupleService coupleService;

    /** 7.1 커플 요청 전송 */
    @PostMapping("/api/chat-rooms/{roomId}/couple-request")
    @Operation(summary = "커플 요청 전송", description = """
        채팅 상대에게 커플 요청을 보냅니다.

        > 📱 **화면:** 8.4 커플 확정 요청 / 수락 — [커플 요청 보내기] 버튼 탭

        **동작:**
        - 72시간 만료 타이머 시작
        - 24시간/48시간 후 리마인드 알림 발송 예약
        - 이미 요청 보냈으면 CR003

        **에러:** CR003(이미 요청), CR004(이미 커플)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"coupleRequestId":1,"expiresAt":"2026-05-03T10:00:00"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "중복 요청",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"CR003","message":"이미 커플 요청이 존재합니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<CoupleRequestResponse>> sendCoupleRequest(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long roomId) {
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(
                coupleService.sendCoupleRequest(userDetails.getUserId(), roomId)));
    }

    /** 7.2 커플 요청 수락 */
    @PostMapping("/api/chat-rooms/{roomId}/couple-accept")
    @Operation(summary = "커플 요청 수락", description = """
        커플 요청을 수락합니다.

        > 📱 **화면:** 8.4 커플 확정 요청 / 수락 — 요청 수신 후 [수락] 버튼 탭

        **동작:**
        - Couple 엔티티 생성 (confirmedAt 기록)
        - ChatRoom 상태 COUPLE_CONFIRMED로 변경
        - 양측에게 COUPLE_CONFIRMED 알림

        **에러:** CR005(요청 없음), CR006(만료)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"coupleId":1,"confirmedAt":"2026-04-30T10:00:00"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "요청 없음",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"CR005","message":"커플 요청을 찾을 수 없습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<CoupleAcceptResponse>> acceptCoupleRequest(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long roomId) {
        return ResponseEntity.ok(ApiResponse.success(
                coupleService.acceptCoupleRequest(userDetails.getUserId(), roomId)));
    }

    /** 7.3 커플 요청 거절 */
    @PostMapping("/api/chat-rooms/{roomId}/couple-reject")
    @Operation(summary = "커플 요청 거절", description = """
        커플 요청을 거절합니다.

        > 📱 **화면:** 8.4 커플 확정 요청 / 수락 — 요청 수신 후 [거절] 버튼 탭

        **에러:** CR005(요청 없음)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "요청 없음",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"CR005","message":"커플 요청을 찾을 수 없습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<Void>> rejectCoupleRequest(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long roomId) {
        coupleService.rejectCoupleRequest(userDetails.getUserId(), roomId);
        return ResponseEntity.ok(ApiResponse.success());
    }
}
