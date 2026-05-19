package com.ember.ember.user.controller;

import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.global.security.CustomUserDetails;
import com.ember.ember.report.dto.AppealRequest;
import com.ember.ember.report.dto.AppealResponse;
import com.ember.ember.user.dto.*;
import com.ember.ember.user.service.AccountService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequiredArgsConstructor
@Tag(name = "Account", description = "계정 관리 API")
public class AccountController {

    private final AccountService accountService;

    /** 10.1 회원 탈퇴 (30일 유예) */
    @PostMapping("/api/users/me/deactivate")
    @Operation(summary = "회원 탈퇴 (소프트 딜리트, 30일 유예)", description = """
        회원 탈퇴를 요청합니다 (30일 유예 후 영구 삭제).

        > 📱 **화면:** 11.3 회원 탈퇴 — 마이페이지 > 설정 > [탈퇴 확정] 버튼

        **요청 필드:**
        - `reason` (선택): 탈퇴 사유
        - `detail` (선택): 상세 설명, 최대 500자

        **동작:**
        1. 계정 상태 DEACTIVATED, permanentDeleteAt = 30일 후
        2. 활성 교환일기/채팅 전부 TERMINATED
        3. Redis 키 정리 (RT, 매칭 캐시, AI 캐시)
        4. 30일 내 POST /api/users/me/restore로 복구 가능
        5. 30일 후 배치에서 영구 삭제 (일기 익명화, 개인정보 삭제)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"deactivatedAt":"2026-04-30T10:00:00","permanentDeleteAt":"2026-05-30T10:00:00"}}
                """)))
    })
    public ResponseEntity<ApiResponse<DeactivateResponse>> deactivate(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @Valid @RequestBody(required = false) DeactivateRequest request) {
        DeactivateRequest req = (request != null) ? request : new DeactivateRequest(null, null);
        return ResponseEntity.status(HttpStatus.OK)
                .body(ApiResponse.success(
                        accountService.deactivate(userDetails.getUserId(), req)));
    }

    /** 10.2 계정 복구 (마이페이지 경로) */
    @PostMapping("/api/users/me/restore")
    @Operation(summary = "탈퇴 유예 계정 복구", description = """
        탈퇴 유예 계정을 복구합니다 (마이페이지 경로).

        > 📱 **화면:** 11.3 회원 탈퇴 — 유예 기간 내 재로그인 → [계정 복구] 버튼

        **동작:** DEACTIVATED → ACTIVE, 탈퇴 관련 필드 초기화
        - 30일 초과 시 복구 불가 (영구 삭제됨)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"userId":1,"restoredAt":"2026-04-30T10:00:00","status":"ACTIVE"}}
                """)))
    })
    public ResponseEntity<ApiResponse<RestoreResponse>> restore(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(HttpStatus.OK)
                .body(ApiResponse.success(
                        accountService.restore(userDetails.getUserId())));
    }

    /** 10.3 AI 성격 분석 결과 조회 */
    @GetMapping("/api/users/me/ai-profile")
    @Operation(summary = "AI 성격 분석 결과 조회", description = """
        AI 성격 분석 결과를 조회합니다.

        > 📱 **화면:** 9.3 나의 누적 AI 성격 분석 결과 / 4.2 AI 성격 분석 비동기 처리 (마이페이지 > AI 분석 진입)

        **활성화 조건:** 일기 3편 이상 작성
        - 3편 미만이면 analysisAvailable=false

        **응답 (활성화 시):**
        - dominantPersonalityTags: 관계성향 상위 3개 (예: "안정 추구", "공감 우선")
        - dominantEmotionTags: 감정 상위 3개
        - dominantLifestyleTags: 라이프스타일 상위 3개
        - dominantToneTags: 글쓰기 톤 상위 3개

        각 태그는 diary_keywords 테이블의 빈도 집계 기반""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"analysisAvailable":true,"diaryCount":5,"dominantPersonalityTags":["안정 추구","공감 우선"],"dominantEmotionTags":["편안함","그리움"],"dominantLifestyleTags":["미식","혼자 시간"],"dominantToneTags":["솔직한"]}}
                """)))
    })
    public ResponseEntity<ApiResponse<AiProfileResponse>> getAiProfile(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(HttpStatus.OK)
                .body(ApiResponse.success(
                        accountService.getAiProfile(userDetails.getUserId())));
    }

    /** 10.4 제재 이의신청 */
    @PostMapping("/api/users/me/appeals")
    @Operation(summary = "제재 이의신청", description = """
        제재에 대한 이의신청을 접수합니다.

        > 📱 **화면:** 11.5 제재 이의신청 — [이의신청 제출] 버튼

        **요청 필드:**
        - `sanctionId` (필수): 제재 이력 ID
        - `reason` (필수): 이의신청 사유, 20~500자

        **조건:** SUSPEND_7D 또는 SUSPEND_30D 상태만 가능
        - BANNED(영구 정지)는 이의신청 불가
        - 동일 제재에 중복 이의신청 불가

        **에러:** AP001(정지 상태 아님), AP002(이미 접수됨), AP003(영구 정지)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"appealId":1,"status":"PENDING","submittedAt":"2026-04-30T10:00:00"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "이미 이의신청 존재",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"AP001","message":"이미 처리 중인 이의신청이 있습니다","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "제재 상태 아님",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"AP002","message":"제재 상태가 아닙니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<AppealResponse>> createAppeal(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @Valid @RequestBody AppealRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(
                        accountService.createAppeal(userDetails.getUserId(), request)));
    }

    /** 10.5 AI 동의 철회 */
    @DeleteMapping("/api/consent")
    @Operation(summary = "AI 분석 동의 철회", description = """
        AI 분석 동의를 철회합니다.

        > 📱 **화면:** 13.3 민감 데이터 처리 — 마이페이지 > 개인정보 > [동의 철회]

        **동작:**
        - AI_ANALYSIS, AI_DATA_USAGE 모두 REVOKED 이력 INSERT
        - Redis AI 캐시 삭제
        - 철회 후 AI 분석/매칭 추천이 중단됨
        - 동의 이력이 없으면 AC001 에러

        **에러:** AC001(동의 이력 없음)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "동의 내역 없음",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"AC001","message":"AI 분석 동의 내역이 없습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<Void>> revokeConsent(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            HttpServletRequest httpRequest) {
        accountService.revokeConsent(userDetails.getUserId(), httpRequest.getRemoteAddr());
        return ResponseEntity.status(HttpStatus.OK)
                .body(ApiResponse.success());
    }
}
