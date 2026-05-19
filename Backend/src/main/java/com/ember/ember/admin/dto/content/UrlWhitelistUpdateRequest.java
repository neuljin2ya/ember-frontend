package com.ember.ember.admin.dto.content;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.Size;

@Schema(description = "URL 화이트리스트 수정 요청")
public record UrlWhitelistUpdateRequest(
        @Size(max = 200) String domain,
        Boolean isActive
) {}
