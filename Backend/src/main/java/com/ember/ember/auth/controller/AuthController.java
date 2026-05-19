package com.ember.ember.auth.controller;

import com.ember.ember.auth.dto.*;
import com.ember.ember.auth.service.AuthService;
import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.global.security.CustomUserDetails;
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
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequiredArgsConstructor
@Tag(name = "Auth", description = "인증 API")
public class AuthController {

    private final AuthService authService;

    /** 소셜 로그인/회원가입 */
    @PostMapping("/api/auth/social")
    @Operation(summary = "소셜 로그인/회원가입", description = """
        카카오 소셜 로그인 또는 회원가입을 처리합니다.

        > 📱 **화면:** 2.2 소셜 회원가입 및 로그인 (카카오) — [카카오로 시작] 버튼 탭

        **요청 필드:**
        - `provider`: 소셜 로그인 제공자 (현재 `KAKAO`만 지원)
        - `accessToken`: 카카오 SDK에서 발급받은 Access Token

        **동작:**
        - 기존 회원이면 JWT 토큰 쌍(AT+RT) 발급
        - 신규 회원이면 자동 회원가입 후 `ROLE_GUEST`로 생성, `isNewUser=true` 반환
        - 탈퇴 유예 중인 계정이면 `restoreToken` 포함 (POST /api/auth/restore로 복구 가능)

        **에러:** A009(소셜 인증 실패), A010(지원하지 않는 provider)""",
        responses = {
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "성공",
                content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                    {"code":"201","message":"CREATED","data":{"accessToken":"eyJ...","refreshToken":"eyJ...","isNewUser":true,"userId":1,"onboardingCompleted":false,"onboardingStep":0,"accountStatus":"ACTIVE","restoreToken":null}}
                    """))),
            @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "소셜 인증 실패",
                content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                    {"code":"A009","message":"소셜 인증에 실패했습니다.","data":null}
                    """)))
        })
    public ResponseEntity<ApiResponse<SocialLoginResponse>> socialLogin(
            @Valid @RequestBody SocialLoginRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(authService.socialLogin(request)));
    }

    /** 토큰 갱신 */
    @PostMapping("/api/auth/refresh")
    @Operation(summary = "토큰 갱신 (Refresh Token Rotation)", description = """
        Access Token 만료 시 Refresh Token으로 새 토큰 쌍을 발급합니다.

        > 📱 **화면:** 1.1 앱 스플래시 (자동 로그인) / 13.2 JWT 토큰 생명주기

        **요청 필드:**
        - `refreshToken`: 이전에 발급받은 Refresh Token

        **동작:**
        - Refresh Token Rotation 적용 — 기존 RT는 즉시 무효화되고 새 RT 발급
        - 무효화된 RT로 재요청 시 A005 에러

        **에러:** A005(유효하지 않은 RT)""")
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"accessToken":"eyJ...","refreshToken":"eyJ..."}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "유효하지 않은 리프레시 토큰",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"A005","message":"유효하지 않은 리프레시 토큰입니다.","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<TokenResponse>> refreshToken(
            @Valid @RequestBody RefreshRequest request) {
        return ResponseEntity.status(HttpStatus.OK)
                .body(ApiResponse.success(authService.refreshToken(request)));
    }

    /** 로그아웃 */
    @PostMapping("/api/auth/logout")
    @Operation(summary = "로그아웃", description = """
        현재 세션을 로그아웃합니다.

        > 📱 **화면:** 2.5 로그아웃 — 마이페이지 > 설정 > [로그아웃] 버튼

        **동작:**
        - Access Token을 Redis 블랙리스트에 등록 (만료 시간까지 유지)
        - Refresh Token을 Redis에서 삭제
        - 블랙리스트에 등록된 AT로 API 호출 시 A006 에러

        **헤더:** `Authorization: Bearer {accessToken}` 필수""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "401", description = "만료된 토큰",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"A002","message":"만료된 토큰입니다.","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<Void>> logout(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            HttpServletRequest request) {
        String accessToken = resolveToken(request);
        authService.logout(userDetails.getUserId(), accessToken);
        return ResponseEntity.status(HttpStatus.OK).body(ApiResponse.success());
    }

    /** 계정 복구 (탈퇴 유예 기간 내) */
    @PostMapping("/api/auth/restore")
    @Operation(summary = "탈퇴 유예 계정 복구", description = """
        탈퇴 유예 기간(30일) 내 계정을 복구합니다.

        > 📱 **화면:** 2.6 계정 복구 — 소셜 로그인 시 PENDING_DELETION 감지 → [계정 복구] 버튼

        **요청 필드:**
        - `restoreToken`: 소셜 로그인 응답에서 받은 복구 토큰

        **동작:**
        - DEACTIVATED → ACTIVE 상태 전환
        - deactivatedAt, permanentDeleteAt 초기화
        - 30일 초과 시 A012 에러 (영구 삭제됨)

        **에러:** A011(유효하지 않은 복구 토큰), A012(복구 기간 만료)""")
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"accessToken":"eyJ...","refreshToken":"eyJ...","userId":1}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "복구 불가",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"A012","message":"복구할 수 없는 계정입니다.","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<RestoreResponse>> restoreAccount(
            @Valid @RequestBody RestoreRequest request) {
        return ResponseEntity.status(HttpStatus.OK)
                .body(ApiResponse.success(authService.restoreAccount(request)));
    }

    /** Authorization 헤더에서 Bearer 토큰 추출 */
    private String resolveToken(HttpServletRequest request) {
        String bearer = request.getHeader("Authorization");
        if (bearer != null && bearer.startsWith("Bearer ")) {
            return bearer.substring(7);
        }
        return null;
    }
}
