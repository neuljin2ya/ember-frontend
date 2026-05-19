package com.ember.ember.admin.dto.content;

import com.ember.ember.global.moderation.domain.BannedWord;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Size;

@Schema(description = "금칙어 수정 요청 — null 전달 시 해당 필드 유지")
public record BannedWordUpdateRequest(
        @Size(max = 100) String word,
        BannedWord.BannedWordCategory category,
        BannedWord.MatchMode matchMode,
        Boolean isActive
) {}
