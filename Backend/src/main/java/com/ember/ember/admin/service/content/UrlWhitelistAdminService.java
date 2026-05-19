package com.ember.ember.admin.service.content;

import com.ember.ember.admin.dto.content.UrlWhitelistCreateRequest;
import com.ember.ember.admin.dto.content.UrlWhitelistResponse;
import com.ember.ember.admin.dto.content.UrlWhitelistUpdateRequest;
import com.ember.ember.content.event.UrlWhitelistChangedEvent;
import com.ember.ember.global.exception.BusinessException;
import com.ember.ember.global.moderation.domain.UrlWhitelist;
import com.ember.ember.global.moderation.repository.UrlWhitelistRepository;
import com.ember.ember.global.response.ErrorCode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class UrlWhitelistAdminService {

    private final UrlWhitelistRepository urlWhitelistRepository;
    private final ApplicationEventPublisher eventPublisher;

    public Page<UrlWhitelistResponse> list(Boolean isActive, String q, Pageable pageable) {
        String keyword = (q == null || q.isBlank()) ? null : q.trim();
        return urlWhitelistRepository.search(isActive, keyword, pageable)
                .map(UrlWhitelistResponse::from);
    }

    public UrlWhitelistResponse getById(Long id) {
        return UrlWhitelistResponse.from(findOrThrow(id));
    }

    @Transactional
    public UrlWhitelistResponse create(UrlWhitelistCreateRequest request) {
        urlWhitelistRepository.findByDomain(request.domain()).ifPresent(dup -> {
            throw new BusinessException(ErrorCode.DUPLICATE_RESOURCE);
        });
        UrlWhitelist saved = urlWhitelistRepository.save(
                UrlWhitelist.create(request.domain(), request.isActive()));
        eventPublisher.publishEvent(
                new UrlWhitelistChangedEvent(UrlWhitelistChangedEvent.ChangeType.CREATED, saved.getId()));
        log.info("[Admin] URL 화이트리스트 생성: id={} domain={}", saved.getId(), saved.getDomain());
        return UrlWhitelistResponse.from(saved);
    }

    @Transactional
    public UrlWhitelistResponse update(Long id, UrlWhitelistUpdateRequest request) {
        UrlWhitelist entity = findOrThrow(id);
        entity.update(request.domain(), request.isActive());
        eventPublisher.publishEvent(
                new UrlWhitelistChangedEvent(UrlWhitelistChangedEvent.ChangeType.UPDATED, entity.getId()));
        return UrlWhitelistResponse.from(entity);
    }

    @Transactional
    public void delete(Long id) {
        UrlWhitelist entity = findOrThrow(id);
        entity.deactivate();
        eventPublisher.publishEvent(
                new UrlWhitelistChangedEvent(UrlWhitelistChangedEvent.ChangeType.DELETED, entity.getId()));
    }

    private UrlWhitelist findOrThrow(Long id) {
        return urlWhitelistRepository.findById(id)
                .orElseThrow(() -> new BusinessException(ErrorCode.ADM_URL_WHITELIST_NOT_FOUND));
    }
}
