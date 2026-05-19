package com.ember.ember.admin.dto.analytics;

import java.time.LocalDate;
import java.util.List;

/**
 * 교환일기 턴 → 채팅 전환 퍼널 — 설계서 §3.13 (B-2.6).
 *
 * 방 생성 → 턴1 → 턴2 → 턴3 → 턴4 (COMPLETED) → CHAT_CONNECTED 5단 퍼널.
 * worstStage: 단계별 전환율이 가장 낮은 병목 구간.
 */
public record ExchangeTurnFunnelResponse(
        Period period,
        List<FunnelStage> stages,
        Double overallChatRate, // roomsCreated → CHAT_CONNECTED 총 전환율
        String worstStage,
        Meta meta
) {
    public record Period(LocalDate startDate, LocalDate endDate, String timezone) {}

    /**
     * @param name        단계명(ROOM_CREATED / TURN_1 / TURN_2 / TURN_3 / TURN_4_COMPLETE / CHAT_CONNECTED)
     * @param count       해당 단계 도달 방 수
     * @param stepRate    이전 단계 대비 전환율 (첫 단계는 null 또는 1.0)
     * @param cumulative  ROOM_CREATED 대비 누적 전환율
     */
    public record FunnelStage(
            String name,
            long count,
            Double stepRate,
            Double cumulative
    ) {}

    public record Meta(int kAnonymityMin, String dataSourceVersion) {}
}
