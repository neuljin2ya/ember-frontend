package com.ember.ember.admin.service.content;

import com.ember.ember.admin.domain.AdminAccount;
import com.ember.ember.admin.dto.content.BannedWordCreateRequest;
import com.ember.ember.admin.dto.content.BannedWordResponse;
import com.ember.ember.admin.dto.content.BannedWordUpdateRequest;
import com.ember.ember.admin.repository.AdminAccountRepository;
import com.ember.ember.content.event.BannedWordChangedEvent;
import com.ember.ember.global.exception.BusinessException;
import com.ember.ember.global.moderation.domain.BannedWord;
import com.ember.ember.global.moderation.repository.BannedWordRepository;
import com.ember.ember.global.response.ErrorCode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 금칙어 관리자 CRUD 서비스 — Phase 3B §9.6.
 * <p>save/update/delete 트랜잭션 경계 내에서 {@link BannedWordChangedEvent} 를 발행해
 * {@code ModerationCacheEvictionListener} 가 Redis 캐시(BANNED_WORDS:ALL) 를 무효화하도록 한다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class BannedWordAdminService {

    private final BannedWordRepository bannedWordRepository;
    private final AdminAccountRepository adminAccountRepository;
    private final ApplicationEventPublisher eventPublisher;

    public Page<BannedWordResponse> list(BannedWord.BannedWordCategory category,
                                         BannedWord.MatchMode matchMode,
                                         Boolean isActive,
                                         String q,
                                         Pageable pageable) {
        String keyword = (q == null || q.isBlank()) ? null : q.trim();
        return bannedWordRepository.search(category, matchMode, isActive, keyword, pageable)
                .map(BannedWordResponse::from);
    }

    public BannedWordResponse getById(Long id) {
        return BannedWordResponse.from(findOrThrow(id));
    }

    @Transactional
    public BannedWordResponse create(BannedWordCreateRequest request, Long createdByAdminId) {
        BannedWord.MatchMode matchMode = request.matchMode() == null
                ? BannedWord.MatchMode.PARTIAL : request.matchMode();

        // (word, matchMode) 유니크 중복 방어
        bannedWordRepository.findByWordAndMatchMode(request.word(), matchMode).ifPresent(dup -> {
            throw new BusinessException(ErrorCode.DUPLICATE_RESOURCE);
        });

        AdminAccount creator = adminAccountRepository.findById(createdByAdminId)
                .orElseThrow(() -> new BusinessException(ErrorCode.ACCOUNT_NOT_FOUND));

        BannedWord saved = bannedWordRepository.save(
                BannedWord.create(request.word(), request.category(), matchMode, request.isActive(), creator));
        eventPublisher.publishEvent(
                new BannedWordChangedEvent(BannedWordChangedEvent.ChangeType.CREATED, saved.getId()));

        log.info("[Admin] 금칙어 생성: id={} word={} by adminId={}", saved.getId(), saved.getWord(), createdByAdminId);
        return BannedWordResponse.from(saved);
    }

    @Transactional
    public BannedWordResponse update(Long id, BannedWordUpdateRequest request) {
        BannedWord entity = findOrThrow(id);
        entity.update(request.word(), request.category(), request.matchMode(), request.isActive());
        eventPublisher.publishEvent(
                new BannedWordChangedEvent(BannedWordChangedEvent.ChangeType.UPDATED, entity.getId()));
        return BannedWordResponse.from(entity);
    }

    /** soft-delete: is_active=false 로 비활성화 + 이벤트 발행. */
    @Transactional
    public void delete(Long id) {
        BannedWord entity = findOrThrow(id);
        entity.deactivate();
        eventPublisher.publishEvent(
                new BannedWordChangedEvent(BannedWordChangedEvent.ChangeType.DELETED, entity.getId()));
    }

    private BannedWord findOrThrow(Long id) {
        return bannedWordRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.ADM_BANNED_WORD_NOT_FOUND));
    }
}
