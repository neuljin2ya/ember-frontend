package com.ember.ember.admin.controller.content;

import com.ember.ember.admin.annotation.AdminOnly;
import com.ember.ember.admin.annotation.SuperAdminOnly;
import com.ember.ember.admin.dto.content.UrlWhitelistCreateRequest;
import com.ember.ember.admin.dto.content.UrlWhitelistResponse;
import com.ember.ember.admin.dto.content.UrlWhitelistUpdateRequest;
import com.ember.ember.admin.service.content.UrlWhitelistAdminService;
import com.ember.ember.global.response.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/** URL 화이트리스트 관리자 CRUD — §9.6. */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/admin/content/url-whitelist")
@Tag(name = "Admin URL Whitelist", description = "URL 화이트리스트 관리자 CRUD (v2.2 §9.6)")
@SecurityRequirement(name = "bearerAuth")
public class UrlWhitelistAdminController {

    private final UrlWhitelistAdminService service;

    @AdminOnly
    @GetMapping
    @Operation(summary = "화이트리스트 목록 조회")
    public ResponseEntity<ApiResponse<Page<UrlWhitelistResponse>>> list(
            @RequestParam(required = false) Boolean isActive,
            @RequestParam(required = false) String q,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(service.list(isActive, q, pageable)));
    }

    @AdminOnly
    @GetMapping("/{id}")
    @Operation(summary = "화이트리스트 단건 조회")
    public ResponseEntity<ApiResponse<UrlWhitelistResponse>> getById(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(service.getById(id)));
    }

    @SuperAdminOnly
    @PostMapping
    @Operation(summary = "화이트리스트 추가")
    public ResponseEntity<ApiResponse<UrlWhitelistResponse>> create(
            @Valid @RequestBody UrlWhitelistCreateRequest request) {
        return ResponseEntity.ok(ApiResponse.created(service.create(request)));
    }

    @SuperAdminOnly
    @PutMapping("/{id}")
    @Operation(summary = "화이트리스트 수정")
    public ResponseEntity<ApiResponse<UrlWhitelistResponse>> update(
            @PathVariable Long id,
            @Valid @RequestBody UrlWhitelistUpdateRequest request) {
        return ResponseEntity.ok(ApiResponse.success(service.update(id, request)));
    }

    @SuperAdminOnly
    @DeleteMapping("/{id}")
    @Operation(summary = "화이트리스트 비활성화 (soft-delete)")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.success());
    }
}
