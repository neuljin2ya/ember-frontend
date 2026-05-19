package com.ember.ember.couple.repository;

import com.ember.ember.couple.domain.Couple;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

/**
 * 커플 Repository
 */
public interface CoupleRepository extends JpaRepository<Couple, Long> {

    /** 채팅방으로 커플 조회 */
    Optional<Couple> findByChatRoomId(Long chatRoomId);

    /** 커플 존재 여부 */
    boolean existsByChatRoomId(Long chatRoomId);
}
