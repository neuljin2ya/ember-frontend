package com.ember.ember.user.controller;

import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.global.security.CustomUserDetails;
import com.ember.ember.user.dto.*;
import com.ember.ember.user.service.UserService;
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
@Tag(name = "User", description = "사용자 프로필 API")
public class UserController {

    private final UserService userService;

    /** 랜덤 닉네임 생성 */
    @PostMapping("/api/users/nickname/generate")
    @Operation(summary = "랜덤 닉네임 생성 (형용사+명사 조합)", description = """
        랜덤 닉네임을 생성합니다. 인증 불필요.

        > 📱 **화면:** 3.1 기본 프로필 설정 — [다시 생성] 버튼 탭

        **동작:**
        - 형용사(20개) + 명사(20개) 조합으로 생성 (예: "따뜻한별빛", "용감한하늘")
        - 중복 검사 포함 — 기존 닉네임과 겹치지 않음
        - 프로필 등록 전 닉네임 미리보기 용도""")
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"201","message":"CREATED","data":{"nickname":"따뜻한별빛"}}
                """)))
    })
    public ResponseEntity<ApiResponse<NicknameGenerateResponse>> generateNickname() {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(userService.generateNickname()));
    }

    /** 프로필 등록 (온보딩 1단계) */
    @PostMapping("/api/users/profile")
    @Operation(summary = "프로필 등록 (온보딩 1단계)", description = """
        온보딩 1단계 — 기본 프로필을 등록합니다.

        > 📱 **화면:** 3.1 기본 프로필 설정 — [다음] 버튼 탭 (최종 제출)

        **요청 필드:**
        - `nickname` (필수): 2~10자, 한글/영문/숫자
        - `birthDate` (필수): yyyy-MM-dd, 만 18세 이상
        - `gender` (필수): MALE 또는 FEMALE
        - `realName` (선택): 실명 2~5자 한글
        - `sido` (선택): 시/도 (예: "서울특별시")
        - `sigungu` (선택): 시/군/구 (예: "강남구")
        - `school` (선택): 학교명

        **동작:**
        - onboardingStep 0 → 1 변경
        - 닉네임 중복 시 U001, 미성년자 U002

        **에러:** U001(닉네임 중복), U002(미성년자)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"201","message":"CREATED","data":{"userId":1,"nickname":"따뜻한별빛","onboardingStep":1}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "닉네임 중복",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"U001","message":"이미 사용 중인 닉네임입니다.","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "미성년자",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"U002","message":"만 18세 이상만 가입할 수 있습니다.","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<ProfileResponse>> createProfile(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @Valid @RequestBody ProfileRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(userService.createProfile(userDetails.getUserId(), request)));
    }

    /** 내 프로필 조회 */
    @GetMapping("/api/users/me")
    @Operation(summary = "내 프로필 조회", description = """
        현재 로그인한 사용자의 전체 프로필을 조회합니다.

        > 📱 **화면:** 9.1 내 프로필 조회 / 11.4 제재 알림 (로그인 시 제재 상태 감지)

        **응답 포함 정보:**
        - 기본 정보: userId, nickname, birthDate, gender, sido, sigungu, school
        - 온보딩 상태: onboardingCompleted, onboardingStep (0=미시작, 1=프로필완료, 2=키워드완료)
        - 이상형 키워드: idealKeywords 배열
        - 계정 상태: accountStatus (ACTIVE/DEACTIVATED/SUSPEND_7D/SUSPEND_30D/BANNED)
        - 제재 정보: suspensionReason, suspendedUntil, canAppeal""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"userId":1,"nickname":"따뜻한별빛","birthDate":"2000-01-01","gender":"MALE","sido":"서울특별시","sigungu":"강남구","onboardingCompleted":true,"onboardingStep":2,"accountStatus":"ACTIVE"}}
                """)))
    })
    public ResponseEntity<ApiResponse<UserMeResponse>> getMyProfile(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.status(HttpStatus.OK)
                .body(ApiResponse.success(userService.getMyProfile(userDetails.getUserId())));
    }

    /** 프로필 부분 수정 */
    @PatchMapping("/api/users/me/profile")
    @Operation(summary = "프로필 부분 수정 (닉네임/지역/학교)", description = """
        프로필 정보를 수정합니다.

        > 📱 **화면:** 9.1 내 프로필 조회 및 수정 — [프로필 수정] 저장 탭

        **수정 가능 필드:** nickname, realName, sido, sigungu, school
        - 닉네임 변경은 30일 쿨다운 적용 (lastNicknameChangedAt 기준)
        - 변경할 필드만 보내면 됨 (PATCH 방식)

        **에러:** U001(닉네임 중복), U006(30일 쿨다운)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"userId":1,"nickname":"새닉네임"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "429", description = "닉네임 변경 쿨다운",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"U006","message":"닉네임은 30일에 한 번만 변경할 수 있습니다.","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<Void>> updateProfile(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @Valid @RequestBody ProfileUpdateRequest request) {
        userService.updateProfile(userDetails.getUserId(), request);
        return ResponseEntity.status(HttpStatus.OK).body(ApiResponse.success());
    }

    /** FCM 디바이스 토큰 등록/갱신 */
    @PostMapping("/api/users/me/fcm-token")
    @Operation(summary = "FCM 토큰 등록/갱신", description = """
        FCM 푸시 알림용 디바이스 토큰을 등록하거나 갱신합니다.

        > 📱 **화면:** 1.2 앱 권한 요청 / 2.2 소셜 로그인 완료 후 — FCM 토큰 자동 등록

        **요청 필드:**
        - `fcmToken` (필수): Firebase에서 발급받은 디바이스 토큰
        - `deviceType` (필수): `AOS` 또는 `IOS` (ANDROID, iOS 아님 주의!)

        **동작:**
        - 동일 userId+deviceType 조합이면 토큰 갱신
        - 다른 유저가 같은 토큰을 가지고 있으면 기존 것 삭제 (디바이스 변경 대응)

        **에러:** C001(잘못된 deviceType)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "잘못된 요청",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"C001","message":"잘못된 요청입니다.","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<Void>> registerFcmToken(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @Valid @RequestBody FcmTokenRequest request) {
        userService.registerFcmToken(userDetails.getUserId(), request);
        return ResponseEntity.status(HttpStatus.OK).body(ApiResponse.success());
    }
}
