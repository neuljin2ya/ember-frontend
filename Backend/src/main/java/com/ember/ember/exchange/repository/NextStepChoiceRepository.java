package com.ember.ember.exchange.repository;

import com.ember.ember.exchange.domain.NextStepChoice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

/**
 * 관계 확장 선택 Repository
 */
public interface NextStepChoiceRepository extends JpaRepository<NextStepChoice, Long> {

    /** 특정 방의 특정 라운드에서 사용자의 선택 조회 */
    Optional<NextStepChoice> findByRoomIdAndUserIdAndRoundNumber(Long roomId, Long userId, Integer roundNumber);

    /** 특정 방의 특정 라운드 선택 목록 */
    @Query("SELECT nsc FROM NextStepChoice nsc WHERE nsc.room.id = :roomId AND nsc.roundNumber = :roundNumber")
    List<NextStepChoice> findByRoomIdAndRoundNumber(@Param("roomId") Long roomId, @Param("roundNumber") Integer roundNumber);
}
