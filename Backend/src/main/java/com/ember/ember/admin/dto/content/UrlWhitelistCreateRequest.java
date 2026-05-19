package com.ember.ember.admin.dto.content;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

@Schema(description = "URL 화이트리스트 생성 요청")
public record UrlWhitelistCreateRequest(
        @NotBlank @Size(max = 200) String domain,
        Boolean isActive
) {}
