package com.ember.ember.global.config;

import io.swagger.v3.oas.annotations.enums.SecuritySchemeType;
import io.swagger.v3.oas.annotations.security.SecurityScheme;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import org.springdoc.core.models.GroupedOpenApi;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

@Configuration
@SecurityScheme(
        name = "bearerAuth",
        type = SecuritySchemeType.HTTP,
        scheme = "bearer",
        bearerFormat = "JWT"
)
public class SpringDocConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        String description = """
                Ember 사용자 + Dev API (총 88개)

                서버: https://ember-app.duckdns.org
                인증: Bearer 토큰 (`GET /api/dev/token?userId=1` 로 발급)

                # 전체 API 플로우

                ## 1단계: 로그인 + 온보딩

                ### 방법 A: Dev 로그인 (카카오 없이 테스트)
                ```
                POST /api/dev/register → 테스트 유저 생성 + accessToken 발급 (ROLE_GUEST)
                  ↓ 이후 온보딩 플로우 동일
                ```

                ### 방법 B: 카카오 로그인 (실제 사용자)
                ```
                [Flutter] 카카오 SDK로 카카오 로그인 → kakaoAccessToken 획득
                  ↓
                POST /api/auth/social (provider=KAKAO, accessToken=카카오토큰)
                  → 신규: 회원가입 + JWT 발급 (ROLE_GUEST)
                  → 기존: 로그인 + JWT 발급 (ROLE_USER)
                ```

                ### 온보딩 (신규 가입 시)
                ```
                POST /api/consent (type=USER_TERMS) → 이용약관 동의
                POST /api/consent (type=AI_TERMS) → AI 분석 동의
                  ↓
                POST /api/users/nickname/generate → 랜덤 닉네임 생성
                POST /api/users/profile → 프로필 등록 (닉네임, 성별, 생년월일, 지역)
                  ↓
                GET /api/users/ideal-type/keyword-list → 이상형 키워드 목록 (10개)
                POST /api/users/ideal-type/keywords → 이상형 설정 (최대 3개) → ROLE_USER 승격
                  ↓
                GET /api/tutorials/pages → 튜토리얼 페이지 조회
                POST /api/users/tutorial/complete → 튜토리얼 완료
                ```

                ## 2단계: 일기 작성 + AI 분석
                ```
                POST /api/diaries → 일기 작성 (일 1회, 200~1000자)
                  ↓ (자동) AI 분석 파이프라인 → 감정/성격/라이프스타일/톤 태그 생성
                GET /api/diaries/{diaryId} → 일기 상세 (AI 키워드 포함)
                GET /api/users/me/ai-profile → AI 성격 분석 결과 (일기 3편 이상)
                ```

                ## 3단계: 탐색 + 매칭 신청
                ```
                GET /api/diaries/explore → 상대방 일기 탐색 (이성 필터링, 커서 페이징)
                GET /api/diaries/{diaryId}/detail → 탐색 일기 상세 (성격 키워드, 다른 일기)
                  ↓
                POST /api/matching/{diaryId}/select → 교환 신청 (PENDING)
                POST /api/matching/{diaryId}/skip → 넘기기 (7일간 재추천 제외)
                  ↓
                GET /api/matching/requests → 받은 매칭 요청 목록
                POST /api/matching/requests/{matchingId}/accept → 수락 → 교환일기 방 자동 생성
                ```

                ## 4단계: 교환일기 (4턴 릴레이)
                ```
                GET /api/exchange-rooms → 교환일기 방 목록
                GET /api/exchange-rooms/{roomId} → 방 상세 (턴 상태, 데드라인)
                  ↓
                POST /api/exchange-rooms/{roomId}/diaries → 교환일기 작성 (내 턴일 때만)
                GET /api/exchange-rooms/{roomId}/diaries/{diaryId} → 상대 일기 열람
                POST /api/exchange-rooms/{roomId}/diaries/{diaryId}/reaction → 리액션 (HEART/SAD/HAPPY/FIRE)
                  ↓ (4턴 완료 후)
                POST /api/exchange-rooms/{roomId}/next-step → 관계 확장 선택 (CHAT 또는 CONTINUE)
                  - 양측 CHAT → 채팅방 자동 생성
                  - 불일치 → 추가 라운드 (2턴)
                ```

                ## 5단계: 채팅 + 커플
                ```
                GET /api/chat-rooms → 채팅방 목록
                POST /api/chat-rooms/{roomId}/messages → 메시지 전송 (REST)
                GET /api/chat-rooms/{roomId}/messages → 메시지 이력 (커서 기반)
                GET /api/chat-rooms/{roomId}/profile → 상대방 프로필 (성격 태그)
                  ↓ (WebSocket STOMP 실시간 채팅은 하단 WebSocket 섹션 참조)
                  ↓
                POST /api/chat-rooms/{roomId}/couple-request → 커플 요청 (72시간 만료)
                POST /api/chat-rooms/{roomId}/couple-accept → 커플 수락 → 커플 성사!
                POST /api/chat-rooms/{roomId}/couple-reject → 커플 거절
                ```

                ## 토큰 관리
                ```
                POST /api/auth/refresh → accessToken 만료 시 갱신 (refreshToken 필요)
                POST /api/auth/logout → 로그아웃 (AT 블랙리스트 + RT 삭제)
                POST /api/users/me/fcm-token → FCM 푸시 토큰 등록 (앱 실행 시마다)
                ```

                ## 부가 기능
                ```
                GET /api/notifications → 알림 목록 (매칭/교환/채팅/커플 등)
                PATCH /api/notifications/{id}/read → 알림 읽음 처리
                GET /api/notices → 공지사항 / GET /api/faq → FAQ
                POST /api/support/inquiry → 1:1 문의
                POST /api/users/{targetUserId}/report → 신고
                POST /api/users/{targetUserId}/block → 차단
                ```

                ## 마이페이지
                ```
                GET /api/users/me → 내 프로필 조회
                PATCH /api/users/me/profile → 프로필 수정 (닉네임 30일 쿨다운)
                GET /api/users/me/ideal-type → 이상형 키워드 조회
                PUT /api/users/me/ideal-type → 이상형 키워드 수정
                GET /api/users/me/ai-profile → AI 성격 분석 결과
                GET /api/users/me/history/exchange-rooms → 교환일기 히스토리
                GET /api/users/me/history/chat-rooms → 채팅 히스토리
                PATCH /api/users/me/settings → 앱 설정 (다크모드/언어/연령필터)
                PATCH /api/users/me/notification-settings → 알림 설정 수정
                POST /api/users/me/deactivate → 회원 탈퇴 (30일 유예)
                ```

                ---

                # Dev API 사용법
                - `GET /api/dev/token?userId={id}` — 카카오 로그인 없이 테스트 토큰 발급
                - `POST /api/dev/register` — 신규 테스트 유저 생성 (ROLE_GUEST)
                - `POST /api/dev/ai/simulate/{diaryId}` — AI 분석 결과 시뮬레이션 (2~3초 후 diary_keywords 생성)
                - `GET /api/dev/redis/summary` — Redis 캐시 카테고리별 요약
                - `GET /api/dev/redis/user/{userId}` — 유저별 캐시 현황
                - `GET /api/dev/redis/get?key=` — Redis 키 값 + TTL 조회
                - `DELETE /api/dev/redis/delete?key=` — Redis 키 삭제
                - `GET /api/dev/redis/keys?pattern=` — 패턴으로 키 검색
                - `POST /api/dev/exchange-rooms/{roomId}/force-complete` — 교환일기 강제 완주

                # Rate Limiting
                - 인증 전 API: 20회/분 (IP 기준)
                - 인증 후 GET: 60회/분 (userId 기준)
                - 인증 후 POST/PUT/PATCH/DELETE: 30회/분 (userId 기준)
                - `POST /api/auth/social`: 5회/분, `POST /api/diaries`: 5회/분, `POST /api/matching/*`: 10회/분
                - 초과 시 429 + X-RateLimit-Limit/Remaining/Reset 헤더 + Retry-After

                # 에러 응답 형식
                ```json
                { "code": "D001", "message": "오늘 이미 일기를 작성했습니다.", "status": 409 }
                ```

                # 에러코드 목록

                ## 공통 (C)
                | 코드 | HTTP | 메시지 |
                |------|------|--------|
                | C001 | 400 | 잘못된 요청입니다. |
                | C002 | 409 | 이미 존재하는 리소스입니다. |
                | C003 | 500 | 서버 내부 오류입니다. |
                | C004 | 429 | 요청 횟수가 초과되었습니다. |

                ## 인증 (A)
                | 코드 | HTTP | 메시지 |
                |------|------|--------|
                | A001 | 401 | 인증 토큰이 없습니다. |
                | A002 | 401 | 만료된 토큰입니다. |
                | A003 | 401 | 존재하지 않는 계정입니다. |
                | A005 | 401 | 유효하지 않은 Refresh Token입니다. |
                | A006 | 401 | 로그아웃된 토큰입니다. |
                | A007 | 403 | 접근 권한이 없습니다. |
                | A009 | 401 | 소셜 인증에 실패했습니다. |
                | A011 | 401 | 유효하지 않은 복구 토큰입니다. |
                | A012 | 400 | 계정 복구 가능 기간이 만료되었습니다. |

                ## 사용자 (U)
                | 코드 | HTTP | 메시지 |
                |------|------|--------|
                | U001 | 409 | 이미 사용 중인 닉네임입니다. |
                | U002 | 400 | 만 18세 이상만 가입 가능합니다. |
                | U004 | 400 | 이상형 키워드는 3~5개 선택해야 합니다. |
                | U005 | 404 | 존재하지 않는 키워드입니다. |
                | U006 | 400 | 닉네임 변경은 30일에 1회만 가능합니다. |

                ## 일기 (D)
                | 코드 | HTTP | 메시지 |
                |------|------|--------|
                | D001 | 409 | 오늘 이미 일기를 작성했습니다. |
                | D002 | 400 | 글자 수 제한(200~1,000자)에 맞지 않습니다. |
                | D003 | 404 | 존재하지 않는 주제입니다. |
                | D004 | 404 | 존재하지 않는 일기입니다. |
                | D005 | 403 | 본인의 일기가 아닙니다. |
                | D006 | 400 | 당일 작성한 일기만 수정 가능합니다. |
                | D007 | 404 | 존재하지 않는 임시저장 일기입니다. |
                | D008 | 400 | 임시저장은 최대 3건까지 가능합니다. |

                ## 매칭 (M)
                | 코드 | HTTP | 메시지 |
                |------|------|--------|
                | M001 | 409 | 이미 교환 신청한 사용자입니다. |
                | M002 | 400 | 자기 자신에게 신청할 수 없습니다. |
                | M003 | 403 | 차단된 사용자입니다. |
                | M004 | 400 | 일기를 먼저 작성해야 매칭이 가능합니다. |
                | M005 | 409 | 동시에 진행할 수 있는 교환일기는 최대 3건입니다. |
                | M006 | 404 | 존재하지 않는 매칭 요청입니다. |

                ## 교환일기 (ER)
                | 코드 | HTTP | 메시지 |
                |------|------|--------|
                | ER001 | 404 | 존재하지 않는 교환일기 방입니다. |
                | ER002 | 403 | 교환일기 참여자가 아닙니다. |
                | ER003 | 400 | 현재 내 차례가 아닙니다. |
                | ER004 | 400 | 작성 제한 시간이 만료되었습니다. |
                | ER005 | 400 | 본인 일기에는 리액션할 수 없습니다. |

                ## 다음 단계 (NS)
                | 코드 | HTTP | 메시지 |
                |------|------|--------|
                | NS001 | 400 | 교환일기가 완료되지 않아 선택할 수 없습니다. |
                | NS002 | 409 | 이미 선택을 완료했습니다. |

                ## 채팅/커플 (CR)
                | 코드 | HTTP | 메시지 |
                |------|------|--------|
                | CR001 | 404 | 존재하지 않는 채팅방입니다. |
                | CR002 | 403 | 채팅방 참여자가 아닙니다. |
                | CR003 | 409 | 이미 커플 요청을 보냈습니다. |
                | CR004 | 409 | 이미 커플 확정된 채팅방입니다. |
                | CR007 | 400 | 이미 종료된 채팅방입니다. |

                ## 신고/차단 (R/B)
                | 코드 | HTTP | 메시지 |
                |------|------|--------|
                | R001 | 400 | 자기 자신을 신고할 수 없습니다. |
                | R002 | 409 | 이미 신고한 사용자입니다. |
                | B001 | 400 | 자기 자신을 차단할 수 없습니다. |
                | B002 | 409 | 이미 차단한 사용자입니다. |
                | B003 | 404 | 차단 기록이 없습니다. |

                ## 기타
                | 코드 | HTTP | 메시지 |
                |------|------|--------|
                | SC001 | 400 | 부적절한 내용이 포함되어 있습니다. |
                | AC001 | 400 | 동의 이력이 없습니다. |
                | N001 | 404 | 존재하지 않는 알림입니다. |
                | SP001 | 429 | 진행 중인 문의가 너무 많습니다. |
                | AP001 | 400 | 정지 상태의 계정만 이의신청 가능합니다. |
                | AP002 | 409 | 이미 진행 중인 이의신청이 있습니다. |

                ---

                # WebSocket 채팅 (Swagger 외 별도 연결)

                실시간 채팅은 REST가 아닌 **WebSocket STOMP** 프로토콜을 사용합니다.

                ## 연결 정보
                - **엔드포인트**: `wss://ember-app.duckdns.org/ws/chat` (SockJS)
                - **인증**: 연결 시 STOMP 헤더에 `Authorization: Bearer {accessToken}` 포함

                ## 메시지 전송
                - **Destination**: `/app/chat/{roomId}`
                - **Body**: `{ "content": "메시지 내용", "type": "TEXT" }`

                ## 메시지 수신 (구독)
                - **Subscribe**: `/topic/chat/{roomId}`
                - **응답**: `{ "messageId", "senderId", "content", "type", "sequenceId", "createdAt" }`

                ## 읽음 처리
                - **Destination**: `/app/chat/{roomId}/read`
                - **Body**: `{ "lastReadSequenceId": 10 }`

                ## Flutter 예시 (stomp_dart_client)
                ```dart
                final client = StompClient(
                  config: StompConfig.sockJS(
                    url: 'https://ember-app.duckdns.org/ws/chat',
                    stompConnectHeaders: {'Authorization': 'Bearer $token'},
                  ),
                );
                client.activate();
                // 구독
                client.subscribe(destination: '/topic/chat/$roomId', callback: (frame) { ... });
                // 전송
                client.send(destination: '/app/chat/$roomId', body: jsonEncode({...}));
                ```

                > **참고**: 메시지 전송은 `POST /api/chat-rooms/{roomId}/messages` REST API로도 가능합니다 (테스트용).
                """;

        return new OpenAPI()
                .info(new Info()
                        .title("Ember API 서버")
                        .version("v2.2")
                        .description(description));
    }

    /**
     * 사용자 API 전체 (관리자/dev 제외) — 모든 환경에서 노출
     */
    @Bean
    public GroupedOpenApi userAllApi() {
        return GroupedOpenApi.builder()
                .group("user-api")
                .pathsToMatch("/api/**")
                .pathsToExclude("/api/admin/**")
                .addOpenApiCustomizer(openApi ->
                        openApi.addSecurityItem(new SecurityRequirement().addList("bearerAuth")))
                .build();
    }

    /**
     * 전체 API — local/dev에서만 노출
     */
    @Bean
    @Profile("!prod")
    public GroupedOpenApi allApi() {
        return GroupedOpenApi.builder()
                .group("all")
                .pathsToMatch("/api/**")
                .addOpenApiCustomizer(openApi ->
                        openApi.addSecurityItem(new SecurityRequirement().addList("bearerAuth")))
                .build();
    }

    @Bean
    @Profile("!prod")
    public GroupedOpenApi authApi() {
        return GroupedOpenApi.builder()
                .group("auth")
                .pathsToMatch("/api/auth/**")
                .build();
    }

    @Bean
    @Profile("!prod")
    public GroupedOpenApi userApi() {
        return GroupedOpenApi.builder()
                .group("user")
                .pathsToMatch("/api/users/**")
                .build();
    }

    @Bean
    @Profile("!prod")
    public GroupedOpenApi adminApi() {
        return GroupedOpenApi.builder()
                .group("admin")
                .pathsToMatch("/api/admin/**")
                .build();
    }
}
