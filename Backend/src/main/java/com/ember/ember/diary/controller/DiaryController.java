package com.ember.ember.diary.controller;

import com.ember.ember.diary.dto.*;
import com.ember.ember.diary.service.DiaryService;
import com.ember.ember.global.response.ApiResponse;
import com.ember.ember.global.security.CustomUserDetails;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.ExampleObject;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * 일기 API 컨트롤러.
 * 결정 6: main 버전 베이스 채택 (7개 엔드포인트, Swagger 포함).
 * createDiary 메서드는 3필드 포함된 DiaryCreateRequest 사용.
 */
@RestController
@RequiredArgsConstructor
@Tag(name = "Diary", description = "일기 API")
public class DiaryController {

    private final DiaryService diaryService;

    /** 당일 일기 작성 여부 확인 */
    @GetMapping("/api/diaries/today")
    @Operation(summary = "당일 일기 작성 여부 확인", description = """
        오늘 일기를 이미 작성했는지 확인합니다.

        > 📱 **화면:** 4.1 일기 작성 기본 플로우 — 에디터 진입 시 (오늘 일기 여부 확인)

        **응답:**
        - `exists`: true이면 오늘 이미 작성함
        - `diaryId`: 작성한 일기 ID (exists=false이면 null)
        - 일기 작성 버튼 활성화/비활성화 판단에 사용""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"exists":false,"diaryId":null}}
                """)))
    })
    public ResponseEntity<ApiResponse<DiaryTodayResponse>> checkTodayDiary(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                diaryService.checkTodayDiary(userDetails.getUserId())));
    }

    /** 일기 작성 */
    @PostMapping("/api/diaries")
    @Operation(summary = "일기 작성 (일 1회, 200~1000자)", description = """
        새 일기를 작성합니다. 하루 1회만 가능.

        > 📱 **화면:** 4.1 일기 작성 — [제출] 버튼 / 4.2 AI 분석 트리거 / 4.3 수요일 주제 일기

        **요청 필드:**
        - `content` (필수): 일기 본문, 200~1000자
        - `visibility` (필수): `PRIVATE`(나만 보기) 또는 `EXCHANGE_ONLY`(교환 대상 노출)
        - `topicId` (선택): 수요일 주제 ID (GET /api/diaries/weekly-topic에서 조회)

        **동작:**
        1. 하루 1회 제한 검증 (D001)
        2. 금칙어/URL 검열 — 차단 시 SC001
        3. XSS 이스케이프 후 저장
        4. AI 분석 비동기 발행 (RabbitMQ → FastAPI)
        5. analysisStatus=PENDING으로 반환

        **에러:** D001(일 1회), D002(글자 수), SC001(부적절한 내용)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "201", description = "작성 성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"201","message":"CREATED","data":{"diaryId":1,"status":"PRIVATE","analysisStatus":"PENDING"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "409", description = "오늘 이미 작성함 (D001)",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"D001","message":"오늘 이미 일기를 작성했습니다","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "글자 수 미달/초과 (D002)",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"D002","message":"일기는 200~1000자 사이여야 합니다","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "금칙어 포함 (SC001)",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"SC001","message":"부적절한 표현이 포함되어 있습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<DiaryCreateResponse>> createDiary(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @Valid @RequestBody DiaryCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(
                        diaryService.createDiary(userDetails.getUserId(), request)));
    }

    /** 일기 목록 조회 (페이징) */
    @GetMapping("/api/diaries")
    @Operation(summary = "내 일기 목록 조회 (최신순, 페이징)", description = """
        내 일기 목록을 페이징 조회합니다.

        > 📱 **화면:** 4.4 나의 일기 히스토리 — 화면 진입 / 월 탭 변경 시

        **쿼리 파라미터:**
        - `page` (기본 0): 페이지 번호
        - `size` (기본 10): 페이지 크기

        **응답:** 최신순 정렬, 각 일기의 contentPreview(미리보기), summary, category 포함""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"diaries":[{"diaryId":1,"contentPreview":"오늘은...","createdAt":"2026-04-30","summary":"일상 기록","category":"DAILY"}],"totalCount":1,"hasNext":false}}
                """)))
    })
    public ResponseEntity<ApiResponse<DiaryListResponse>> getDiaries(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.success(
                diaryService.getDiaries(userDetails.getUserId(), page, size)));
    }

    /** 일기 상세 조회 */
    @GetMapping("/api/diaries/{diaryId}")
    @Operation(summary = "일기 상세 조회 (AI 분석 결과 포함)", description = """
        일기 상세를 조회합니다. 본인 일기만 조회 가능.

        > 📱 **화면:** 4.4 나의 일기 히스토리 — 일기 카드 탭 (상세 진입)

        **응답 포함:**
        - 일기 본문(content), 작성일(createdAt), 요약(summary), 카테고리(category)
        - AI 분석 태그 (analysisStatus=COMPLETED인 경우)
          - emotionTags: 감정 태그 (예: "편안함")
          - lifestyleTags: 라이프스타일 태그 (예: "미식")
          - toneTags: 글쓰기 톤 태그 (예: "솔직한")
          - 각 태그는 label(이름) + score(확신도) 구조
        - isEditable: 당일 일기인지 (수정 가능 여부)

        **에러:** D004(존재하지 않음), D005(본인 일기 아님)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"diaryId":1,"content":"오늘은...","createdAt":"2026-04-30","summary":"일상 기록","category":"DAILY","emotionTags":[{"label":"편안함","score":0.85}],"lifestyleTags":[{"label":"미식","score":0.72}],"toneTags":[{"label":"솔직한","score":0.90}],"isEditable":true}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "일기 없음 (D004)",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"D004","message":"일기를 찾을 수 없습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<DiaryDetailResponse>> getDiary(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long diaryId) {
        return ResponseEntity.ok(ApiResponse.success(
                diaryService.getDiary(userDetails.getUserId(), diaryId)));
    }

    /** 일기 수정 (당일만) */
    @PatchMapping("/api/diaries/{diaryId}")
    @Operation(summary = "당일 일기 수정 (AI 재분석 트리거)", description = """
        당일 작성한 일기만 수정할 수 있습니다.

        > 📱 **화면:** 4.4 나의 일기 히스토리 — 당일 카드 [수정] 버튼 탭

        **요청 필드:**
        - `content` (필수): 수정할 본문, 200~1000자

        **동작:**
        - 수정 전/후 본문을 diary_edit_logs에 기록
        - 기존 AI 키워드 삭제 + AI 캐시 무효화
        - AI 재분석 자동 발행 (analysisStatus → PENDING)

        **에러:** D004, D005(본인 아님), D006(당일 아님)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "수정 성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"diaryId":1,"content":"수정된 일기 본문...","updatedAt":"2026-04-30T10:00:00","summary":"수정된 요약"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "403", description = "당일 일기만 수정 가능 (D005)",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"D005","message":"당일 작성한 일기만 수정할 수 있습니다","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "수정 횟수 초과 (D006)",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"D006","message":"일기 수정 횟수를 초과했습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<DiaryUpdateResponse>> updateDiary(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long diaryId,
            @Valid @RequestBody DiaryUpdateRequest request) {
        return ResponseEntity.ok(ApiResponse.success(
                diaryService.updateDiary(userDetails.getUserId(), diaryId, request)));
    }

    /** 수요일 주제 조회 */
    @GetMapping("/api/diaries/weekly-topic")
    @Operation(summary = "이번 주 수요일 주제 조회", description = """
        이번 주 수요일 주제를 조회합니다. 인증 불필요.

        > 📱 **화면:** 4.3 주간 랜덤 주제 일기 작성 — 홈 배너 [오늘의 주제] 탭

        **응답:**
        - 수요일이면 `isActive=true`, 다른 요일이면 `false`
        - 주제가 등록되지 않은 주에는 topicId/title이 null
        - topicId를 POST /api/diaries의 topicId 파라미터로 전달하면 주제 일기로 작성""")
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"topicId":1,"title":"가장 기억에 남는 여행지는?","description":null,"isActive":true}}
                """)))
    })
    public ResponseEntity<ApiResponse<WeeklyTopicResponse>> getWeeklyTopic() {
        return ResponseEntity.ok(ApiResponse.success(diaryService.getWeeklyTopic()));
    }

    /** 임시저장 목록 조회 */
    @GetMapping("/api/diaries/drafts")
    @Operation(summary = "임시저장 목록 조회", description = """
        임시저장된 일기 목록을 조회합니다.

        > 📱 **화면:** 14.1 일기 서버 임시 저장 — 임시저장 목록 화면 진입 시

        **응답:** 최대 3건, 최신순 정렬
        - draftId, content(전체 본문), savedAt
        - Redis 캐시(24h) + DB 폴백""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"drafts":[{"draftId":1,"content":"임시저장 내용","savedAt":"2026-04-30T10:00:00"}],"totalCount":1}}
                """)))
    })
    public ResponseEntity<ApiResponse<DraftListResponse>> getDrafts(
            @AuthenticationPrincipal CustomUserDetails userDetails) {
        return ResponseEntity.ok(ApiResponse.success(
                diaryService.getDrafts(userDetails.getUserId())));
    }

    /** 임시저장 생성 */
    @PostMapping("/api/diaries/draft")
    @Operation(summary = "임시저장 생성 (최대 3건)", description = """
        일기를 임시저장합니다.

        > 📱 **화면:** 4.1 일기 작성 / 14.1 일기 서버 임시 저장 — [임시저장] 버튼 탭

        **요청 필드:**
        - `content` (필수): 임시저장할 본문 (글자 수 제한 없음)

        **동작:** 최대 3건 제한, 초과 시 D008 에러

        **에러:** D008(3건 초과)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "저장 성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":{"draftId":1,"savedAt":"2026-04-30T10:00:00"}}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "400", description = "임시저장 3건 초과 (D008)",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"D008","message":"임시저장은 최대 3건까지 가능합니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<DraftResponse>> createDraft(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @Valid @RequestBody DraftCreateRequest request) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.created(
                        diaryService.createDraft(userDetails.getUserId(), request)));
    }

    /** 임시저장 삭제 */
    @DeleteMapping("/api/diaries/draft/{draftId}")
    @Operation(summary = "임시저장 삭제", description = """
        임시저장을 삭제합니다.

        > 📱 **화면:** 14.1 일기 서버 임시 저장 — 임시저장 항목 [삭제] 탭

        **에러:** D007(존재하지 않음)""",
        security = @SecurityRequirement(name = "bearerAuth"))
    @ApiResponses(value = {
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "200", description = "삭제 성공",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"200","message":"OK","data":null}
                """))),
        @io.swagger.v3.oas.annotations.responses.ApiResponse(responseCode = "404", description = "임시저장 없음 (D007)",
            content = @Content(mediaType = "application/json", examples = @ExampleObject(value = """
                {"code":"D007","message":"임시저장을 찾을 수 없습니다","data":null}
                """)))
    })
    public ResponseEntity<ApiResponse<Void>> deleteDraft(
            @AuthenticationPrincipal CustomUserDetails userDetails,
            @PathVariable Long draftId) {
        diaryService.deleteDraft(userDetails.getUserId(), draftId);
        return ResponseEntity.ok(ApiResponse.success());
    }
}
