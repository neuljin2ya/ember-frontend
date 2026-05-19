package com.ember.ember.admin.service;

import com.ember.ember.admin.annotation.AdminAction;
import com.ember.ember.admin.domain.AdminAccount;
import com.ember.ember.admin.dto.suspicious.AdminSuspiciousAccountDetailResponse;
import com.ember.ember.admin.dto.suspicious.AdminSuspiciousAccountDetailResponse.RelatedAccount;
import com.ember.ember.admin.dto.suspicious.AdminSuspiciousAccountListItemResponse;
import com.ember.ember.admin.dto.suspicious.AdminSuspiciousAccountReviewRequest;
import com.ember.ember.admin.dto.suspicious.AdminSuspiciousAccountStatusChangeRequest;
import com.ember.ember.admin.repository.AdminAccountRepository;
import com.ember.ember.global.exception.BusinessException;
import com.ember.ember.global.response.ErrorCode;
import com.ember.ember.global.security.CustomUserDetails;
import com.ember.ember.report.domain.SuspiciousAccount;
import com.ember.ember.report.repository.ReportRepository;
import com.ember.ember.report.repository.SanctionHistoryRepository;
import com.ember.ember.report.repository.SuspiciousAccountRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 의심 계정 관리 서비스 — 관리자 API 통합명세서 v2.1 §4.
 *
 * v0.5 범위: 검토 큐 조회/상세/오탐 처리/상태 변경 (관리자 관점).
 * 의심 계정 자동 탐지(스코어링 배치)는 별도 컴포넌트로 Phase B에서 확장.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AdminSuspiciousAccountService {

    private final SuspiciousAccountRepository suspiciousAccountRepository;
    private final AdminAccountRepository adminAccountRepository;
    private final ReportRepository reportRepository;
    private final SanctionHistoryRepository sanctionHistoryRepository;

    private static final int RELATED_LIMIT = 10;

    // ---------- §4.1 검토 큐 ----------
    public Page<AdminSuspiciousAccountListItemResponse> list(SuspiciousAccount.ReviewStatus status,
                                                              SuspiciousAccount.SuspicionType suspicionType,
                                                              String keyword,
                                                              Pageable pageable) {
        String normalized = (keyword == null || keyword.isBlank()) ? null : keyword.trim();
        return suspiciousAccountRepository
                .searchSuspicious(status, suspicionType, normalized, pageable)
                .map(sa -> AdminSuspiciousAccountListItemResponse.from(
                        sa,
                        maskEmail(sa.getUser().getEmail()),
                        buildIndicators(sa)
                ));
    }

    // ---------- §4.2 탐지 상세 ----------
    public AdminSuspiciousAccountDetailResponse getDetail(Long accountId) {
        SuspiciousAccount sa = loadWithUser(accountId);

        List<RelatedAccount> related = suspiciousAccountRepository
                .findRelatedBySuspicionType(sa.getSuspicionType(), sa.getId(), PageRequest.of(0, RELATED_LIMIT))
                .stream()
                .map(r -> new RelatedAccount(
                        r.getId(),
                        r.getUser().getId(),
                        r.getUser().getNickname(),
                        r.getSuspicionType(),
                        r.getRiskScore(),
                        r.getDetectedAt()))
                .toList();

        String reviewerName = sa.getReviewedBy() == null ? null : sa.getReviewedBy().getName();

        return new AdminSuspiciousAccountDetailResponse(
                sa.getId(),
                sa.getUser().getId(),
                sa.getUser().getNickname(),
                maskEmail(sa.getUser().getEmail()),
                sa.getSuspicionType(),
                sa.getRiskScore(),
                sa.getStatus(),
                sa.getDetectedAt(),
                reviewerName,
                sa.getReviewedAt(),
                sa.getReviewNote(),
                buildIndicators(sa),
                related
        );
    }

    // ---------- §4.3 오탐 처리 (status → CLEARED 강제) ----------
    @Transactional
    @AdminAction(action = "SUSPICIOUS_ACCOUNT_FALSE_POSITIVE", targetType = "SUSPICIOUS_ACCOUNT", targetIdParam = "accountId")
    public void markFalsePositive(Long accountId, AdminSuspiciousAccountReviewRequest request, CustomUserDetails admin) {
        SuspiciousAccount sa = loadWithUser(accountId);
        AdminAccount reviewer = adminAccountRepository.getReferenceById(admin.getUserId());
        sa.markFalsePositive(reviewer, request.reviewNote(), LocalDateTime.now());
    }

    // ---------- §4.4 상태 변경 ----------
    @Transactional
    @AdminAction(action = "SUSPICIOUS_ACCOUNT_STATUS_CHANGE", targetType = "SUSPICIOUS_ACCOUNT", targetIdParam = "accountId")
    public void changeStatus(Long accountId, AdminSuspiciousAccountStatusChangeRequest request, CustomUserDetails admin) {
        SuspiciousAccount sa = loadWithUser(accountId);

        if (!sa.canTransitionTo(request.status())) {
            throw new BusinessException(ErrorCode.ADM_INVALID_STATUS_TRANSITION);
        }

        AdminAccount reviewer = adminAccountRepository.getReferenceById(admin.getUserId());
        sa.changeStatus(request.status(), reviewer, request.reviewNote(), LocalDateTime.now());

        // TODO(Phase B): status=CONFIRMED 전환 시 자동 제재 규칙 트리거 — ops/automation 모듈과 연결.
        if (request.status() == SuspiciousAccount.ReviewStatus.CONFIRMED) {
            log.info("의심 계정 CONFIRMED 전환 감지 — auto sanction hook 대상. saId={}, userId={}",
                    sa.getId(), sa.getUser().getId());
        }
    }

    // ---------- 내부 ----------
    private SuspiciousAccount loadWithUser(Long accountId) {
        return suspiciousAccountRepository.findByIdWithUser(accountId)
                .orElseThrow(() -> new BusinessException(ErrorCode.ADM_SUSPICIOUS_ACCOUNT_NOT_FOUND));
    }

    /**
     * 의심 지표 목록 구성.
     * v0.5 단계에서는 유형 기반 기본 설명 + 계정 관련 카운터 신호를 결합해 표시용 라벨을 만든다.
     * 향후 탐지 배치에서 detection_indicators 테이블이 추가되면 이 메서드를 교체.
     */
    private List<String> buildIndicators(SuspiciousAccount sa) {
        List<String> out = new ArrayList<>();
        out.add("의심 유형: " + sa.getSuspicionType().name());
        out.add("위험 점수: " + sa.getRiskScore().toPlainString());

        long reportReceived = reportRepository.countByTargetUserId(sa.getUser().getId());
        if (reportReceived > 0) {
            out.add("누적 피신고 " + reportReceived + "건");
        }

        sanctionHistoryRepository.findTopByUserIdOrderByStartedAtDesc(sa.getUser().getId())
                .ifPresent(s -> out.add("최근 제재: " + s.getSanctionType().name()
                        + " (" + s.getStartedAt().toLocalDate() + ")"));

        return out;
    }

    /** 이메일 마스킹 — AdminMemberService 와 동일 규칙 (ab****@gmail.com) */
    private String maskEmail(String email) {
        if (email == null || email.isBlank()) return email;
        int at = email.indexOf('@');
        if (at <= 0) return "*" + email;
        String local = email.substring(0, at);
        String domain = email.substring(at);
        if (local.length() <= 2) {
            return "*".repeat(local.length()) + domain;
        }
        return local.substring(0, 2) + "*".repeat(local.length() - 2) + domain;
    }
}
