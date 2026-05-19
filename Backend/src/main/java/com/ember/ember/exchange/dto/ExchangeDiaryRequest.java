package com.ember.ember.exchange.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 교환일기 작성 요청
 */
public record ExchangeDiaryRequest(
        @NotBlank(message = "내용을 입력해주세요.")
        @Size(min = 200, max = 1000, message = "글자 수 제한(200~1,000자)에 맞지 않습니다.")
        String content
) {}
