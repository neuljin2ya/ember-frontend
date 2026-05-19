package com.ember.ember.admin.dto.content;

import com.ember.ember.global.moderation.domain.BannedWord;
import io.swagger.v3.oas.annotations.media.Schema;

import java.time.format.DateTimeFormatter;

@Schema(description = "금칙어 응답")
public record BannedWordResponse(
        Long id,
        String word,
        BannedWord.BannedWordCategory category,
        BannedWord.MatchMode matchMode,
        Boolean isActive,
        Long createdByAdminId,
        String createdByAdminName,
        String createdAt,
        String modifiedAt
) {
    public static BannedWordResponse from(BannedWord entity) {
        var creator = entity.getCreatedBy();
        return new BannedWordResponse(
                entity.getId(),
                entity.getWord(),
                entity.getCategory(),
                entity.getMatchMode(),
                entity.getIsActive(),
                creator == null ? null : creator.getId(),
                creator == null ? null : creator.getName(),
                entity.getCreatedAt() == null ? null : entity.getCreatedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME),
                entity.getModifiedAt() == null ? null : entity.getModifiedAt().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME)
        );
    }
}
