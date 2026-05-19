package com.ember.ember.admin.dto.content;

import com.ember.ember.global.moderation.domain.BannedWord;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

@Schema(description = "금칙어 생성 요청")
public record BannedWordCreateRequest(
        @NotBlank @Size(max = 100) String word,
        @NotNull BannedWord.BannedWordCategory category,
        BannedWord.MatchMode matchMode,
        Boolean isActive
) {}
