package com.ember.ember.global.system.controller;

import com.ember.ember.consent.service.AiConsentService;
import com.ember.ember.global.exception.BusinessException;
import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.global.response.ErrorCode;
import com.ember.ember.global.security.CustomUserDetails;
import com.ember.ember.global.system.domain.AiConsentLog;
import com.ember.ember.global.system.dto.ConsentRequest;
import com.ember.ember.consent.repository.AiConsentLogRepository;
import com.ember.ember.user.domain.User;
import com.ember.ember.user.repository.UserRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequiredArgsConstructor
@Tag(name = "Consent", description = "약관 동의 API")
public class ConsentController {

    private final AiConsentLogRepository aiConsentLogRepository;
    private final UserRepository userRepository;
    private final AiConsentService aiConsentService;

    /** 약관/AI 분석 동의 등록 */
    @PostMapping("/api/consent")
    @Operation(summary = "약관 동의 등록", description = """
        AI 분석 동의를 등록합니다.

        > 📱 **화면:** 2.2 소셜 회원가입 — [전체 동의] 탭 (신규 가입 시) / 13.3 민감 데이터 처리

        **요청 필드:**
        - `consentType` (필수): `AI_ANALYSIS` 또는 `AI_DATA_USAGE` (다른 값은 C001 에러)

        **동작:**
        - ai_consent_log 테이블에 GRANTED 이력 INSERT (Append-Only)
        - AI_ANALYSIS: 일기 성격/감정 분석 동의
        - AI_DATA_USAGE: 매칭 유사도 계산 등 데이터 활용 동의
        - 온보딩 시 두 타입 모두 등록 필요

        **주의:** USER_TERMS, AI_TERMS는 더 이상 사용하지 않습니다.""",
        security = @SecurityRequirement(name = "bearerAuth"))
    public ResponseEntity<ApiResponse<Void>> registerConsent(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @Valid @RequestBody ConsentRequest request,
            HttpServletRequest httpRequest) {

        // consentType 유효성 검증 (AI_ANALYSIS / AI_DATA_USAGE만 허용)
        if (!request.isValidType()) {
            throw new BusinessException(ErrorCode.BAD_REQUEST);
        }

        User user = userRepository.findById(userDetails.getUserId())
                .orElseThrow(() -> new BusinessException(ErrorCode.ACCOUNT_NOT_FOUND));

        String ipAddress = httpRequest.getRemoteAddr();

        aiConsentLogRepository.save(AiConsentLog.builder()
                .user(user)
                .action("GRANTED")
                .consentType(request.consentType())
                .ipAddress(ipAddress)
                .build());

        // 동의 캐시 무효화
        aiConsentService.invalidateConsent(userDetails.getUserId(), request.consentType());

        log.info("동의 등록: userId={}, type={}", userDetails.getUserId(), request.consentType());
        return ResponseEntity.status(HttpStatus.OK).body(ApiResponse.success());
    }
}
