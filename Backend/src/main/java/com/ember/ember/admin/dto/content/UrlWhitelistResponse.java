package com.ember.ember.admin.dto.content;

import com.ember.ember.global.moderation.domain.UrlWhitelist;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.format.DateTimeFormatter;

@Schema(description = "URL 화이트리스트 응답")
public record UrlWhitelistResponse(
        Long id,
        String domain,
        Boolean isActive,
        String createdAt,
        String modifiedAt
) {
    public static UrlWhitelistResponse from(UrlWhitelist entity) {
        return new UrlWhitelistResponse(
                entity.getId(),
                entity.getDomain(),
                entity.getIsActive(),
                entity.getCreatedAt() == null ? null : entity.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                entity.getModifiedAt() == null ? null : entity.getModifiedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        );
    }
}
