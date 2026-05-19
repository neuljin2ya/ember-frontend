package com.ember.ember.couple.repository;

import com.ember.ember.couple.domain.CoupleRequest;
import com.ember.ember.couple.domain.CoupleRequest.CoupleRequestStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

/**
 * 커플 요청 Repository
 */
public interface CoupleRequestRepository extends JpaRepository<CoupleRequest, Long> {

    /** 특정 채팅방의 PENDING 요청 조회 */
    Optional<CoupleRequest> findByChatRoomIdAndStatus(Long chatRoomId, CoupleRequestStatus status);

    /** PENDING 요청 존재 여부 */
    boolean existsByChatRoomIdAndStatus(Long chatRoomId, CoupleRequestStatus status);
}
