package com.ember.ember.consent.repository;

import com.ember.ember.global.system.domain.AiConsentLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;

/**
 * AI 모니터링 대시보드 전용 집계 Repository.
 * 기존 {@link AiConsentLogRepository}와 분리하여 관리자 용도만 담는다.
 */
public interface AiConsentLogDashboardRepository extends JpaRepository<AiConsentLog, Long> {

    /** 범위 내 action(GRANTED/REVOKED) 건수 */
    @Query("""
            SELECT COUNT(a) FROM AiConsentLog a
            WHERE a.actedAt BETWEEN :from AND :to
              AND a.action = :action
            """)
    long countByActionAndActedAtBetween(@Param("action") String action,
                                        @Param("from") LocalDateTime from,
                                        @Param("to") LocalDateTime to);

    /**
     * 일자별(KST) action 건수 트렌드.
     * 네이티브 쿼리로 DATE_TRUNC 사용: PostgreSQL 기준.
     * 결과 행: [date (yyyy-MM-dd 문자열), action, count]
     */
    @Query(value = """
            SELECT TO_CHAR((acted_at AT TIME ZONE 'Asia/Seoul')::date, 'YYYY-MM-DD') AS d,
                   action,
                   COUNT(*) AS cnt
            FROM ai_consent_log
            WHERE acted_at BETWEEN :from AND :to
            GROUP BY d, action
            ORDER BY d ASC
            """, nativeQuery = true)
    List<Object[]> aggregateDailyTrend(@Param("from") LocalDateTime from,
                                       @Param("to") LocalDateTime to);

    /**
     * 최신 동의 상태가 GRANTED인 사용자 수 (consentType별).
     */
    @Query(value = """
            SELECT COUNT(*) FROM (
                SELECT DISTINCT ON (user_id) user_id, action
                FROM ai_consent_log
                WHERE consent_type = :consentType
                ORDER BY user_id, acted_at DESC
            ) latest WHERE latest.action = 'GRANTED'
            """, nativeQuery = true)
    long countUsersWithLatestGranted(@Param("consentType") String consentType);
}
