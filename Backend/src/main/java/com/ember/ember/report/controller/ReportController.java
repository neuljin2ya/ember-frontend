package com.ember.ember.report.controller;

import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.global.security.CustomUserDetails;
import com.ember.ember.report.dto.*;
import com.ember.ember.report.service.BlockService;
import com.ember.ember.report.service.ReportService;
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

@RestController
@RequiredArgsConstructor
@Tag(name = "Report/Block", description = "신고/차단 API")
public class ReportController {

    private final ReportService reportService;
    private final BlockService blockService;

    /** 8.1 사용자 신고 접수 */
    @PostMapping("/api/users/{targetUserId}/report")
    @Operation(summary = "사용자 신고", description = """
        사용자를 신고합니다.

        > 📱 **화면:** 11.1 불량 사용자 신고 — [신고 제출] 버튼 탭

        **요청 필드:**
        - `reason` (필수): 신고 사유 (예: "SPAM", "HARASSMENT")
        - `detail` (선택): 상세 설명

        **규칙:**
        - 자기 자신 신고 불가 (R001)
        - 동일 유저 7일 이내 중복 신고 불가 (R002)
        - 5건 누적 시 관리자에게 자동 알림

        **에러:** R001(자기 신고), R002(중복)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "7일 이내 중복 신고",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"R001","message":"이미 신고한 사용자입니다 (7일 이내)","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "자기 자신 신고 불가",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"R002","message":"자기 자신을 신고할 수 없습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<ReportResponse>> reportUser(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long targetUserId,
            @Valid @RequestBody ReportRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(
                        reportService.createReport(userDetails.getUserId(), targetUserId, request)));
    }

    /** 8.2 사용자 차단 */
    @PostMapping("/api/users/{targetUserId}/block")
    @Operation(summary = "사용자 차단 (연쇄 종료 포함)", description = """
        사용자를 차단합니다.

        > 📱 **화면:** 11.2 사용자 차단 — 프로필/채팅방에서 [차단] 탭

        **동작 (단일 트랜잭션):**
        1. 차단 기록 생성
        2. 진행 중인 매칭 요청 취소
        3. 활성 교환일기 방 종료 (TERMINATED)
        4. 활성 채팅방 종료
        5. 차단 상대 탐색/추천에서 영구 제외

        **에러:** B001(자기 차단), B002(이미 차단)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "이미 차단된 사용자",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"B001","message":"이미 차단된 사용자입니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<BlockResponse>> blockUser(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long targetUserId) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(
                        blockService.blockUser(userDetails.getUserId(), targetUserId)));
    }

    /** 8.3 차단 해제 */
    @DeleteMapping("/api/users/{targetUserId}/block")
    @Operation(summary = "차단 해제", description = """
        차단을 해제합니다.

        > 📱 **화면:** 11.2 사용자 차단 — 차단 목록에서 [해제] 탭

        **동작:** 차단 해제 후에도 종료된 교환/채팅은 복구되지 않음
        - 재차단 시 unique 위반 방지 처리 (reblock)

        **에러:** B003(차단 기록 없음)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "차단 내역 없음",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"B003","message":"차단 내역을 찾을 수 없습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<BlockResponse>> unblockUser(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long targetUserId) {
        return ResponseEntity.status(HttpStatus.OK)
                .body(ApiResponse.success(
                        blockService.unblockUser(userDetails.getUserId(), targetUserId)));
    }

    /** 8.4 차단 목록 조회 */
    @GetMapping("/api/users/me/block-list")
    @Operation(summary = "차단 목록 조회 (커서 기반 페이징)", description = """
        차단한 사용자 목록을 커서 기반으로 조회합니다.

        > 📱 **화면:** 11.2 사용자 차단 — 마이페이지 > 설정 > 차단 목록 화면 진입

        **쿼리 파라미터:**
        - `cursor` (선택): 이전 nextCursor
        - `size` (기본 20)

        **응답:** blockId, userId, nickname, blockedAt""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"blocks":[{"blockId":1,"userId":5,"nickname":"차단된유저","blockedAt":"2026-04-30T10:00:00"}],"nextCursor":null,"hasMore":false}}
                """)))
    })
    public ResponseEntity<ApiResponse<BlockListResponse>> getBlockList(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @RequestParam(required = false) Long cursor,
            @RequestParam(required = false) Integer size) {
        return ResponseEntity.status(HttpStatus.OK)
                .body(ApiResponse.success(
                        blockService.getBlockList(userDetails.getUserId(), cursor, size)));
    }
}
