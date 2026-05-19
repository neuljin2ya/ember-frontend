package com.ember.ember.admin.controller.content;

import com.ember.ember.admin.annotation.AdminOnly;
import com.ember.ember.admin.annotation.SuperAdminOnly;
import com.ember.ember.admin.dto.content.BannedWordCreateRequest;
import com.ember.ember.admin.dto.content.BannedWordResponse;
import com.ember.ember.admin.dto.content.BannedWordUpdateRequest;
import com.ember.ember.admin.service.content.BannedWordAdminService;
import com.ember.ember.global.moderation.domain.BannedWord;
import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.global.security.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** 금칙어 관리자 CRUD — §9.6. */
@RestController
@RequiredArgsConstructor
@RequestMapping("/api/admin/content/banned-words")
@Tag(name = "Admin Banned Words", description = "금칙어 관리자 CRUD (v2.2 §9.6)")
@SecurityRequirement(name = "bearerAuth")
public class BannedWordAdminController {

    private final BannedWordAdminService service;

    @AdminOnly
    @GetMapping
    @Operation(summary = "금칙어 목록 조회 (페이징+필터)")
    public ResponseEntity<ApiResponse<Page<BannedWordResponse>>> list(
            @RequestParam(required = false) BannedWord.BannedWordCategory category,
            @RequestParam(required = false) BannedWord.MatchMode matchMode,
            @RequestParam(required = false) Boolean isActive,
            @RequestParam(required = false) String q,
            @PageableDefault(size = 20) Pageable pageable) {
        return ResponseEntity.ok(ApiResponse.success(
                service.list(category, matchMode, isActive, q, pageable)));
    }

    @AdminOnly
    @GetMapping("/{id}")
    @Operation(summary = "금칙어 단건 조회")
    public ResponseEntity<ApiResponse<BannedWordResponse>> getById(@PathVariable Long id) {
        return ResponseEntity.ok(ApiResponse.success(service.getById(id)));
    }

    @SuperAdminOnly
    @PostMapping
    @Operation(summary = "금칙어 생성")
    public ResponseEntity<ApiResponse<BannedWordResponse>> create(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @Valid @RequestBody BannedWordCreateRequest request) {
        return ResponseEntity.ok(ApiResponse.created(service.create(request, userDetails.getUserId())));
    }

    @SuperAdminOnly
    @PutMapping("/{id}")
    @Operation(summary = "금칙어 수정")
    public ResponseEntity<ApiResponse<BannedWordResponse>> update(
            @PathVariable Long id,
            @Valid @RequestBody BannedWordUpdateRequest request) {
        return ResponseEntity.ok(ApiResponse.success(service.update(id, request)));
    }

    @SuperAdminOnly
    @DeleteMapping("/{id}")
    @Operation(summary = "금칙어 비활성화 (soft-delete)")
    public ResponseEntity<ApiResponse<Void>> delete(@PathVariable Long id) {
        service.delete(id);
        return ResponseEntity.ok(ApiResponse.success());
    }
}
