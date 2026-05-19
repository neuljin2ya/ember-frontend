"""
AI 모델 로더 (models.py)

KcELECTRA:
  - DiaryMultiHeadClassifier: fine-tuned Multi-Head 분류기 (model.pt)
  - 감정 16개(이진) + 생활성향 3축(삼진) + 관계성향 4축(삼진) + 톤 3개(이진) = 33차원

KoSimCSE:
  - BM-K/KoSimCSE-roberta-multitask (사전학습 그대로 사용)
  - mean pooling 기반 임베딩
"""
from __future__ import annotations

import os
from functools import lru_cache

import torch
import torch.nn as nn
from transformers import AutoModel, AutoTokenizer

DEVICE = "cpu"

# ── KcELECTRA 태그 정의 ──────────────────────────────────────────────────────

EMOTION_TAGS = [
    '즐거움', '뿌듯함', '신뢰', '편안함', '걱정', '긴장', '놀람', '당황',
    '슬픔', '외로움', '거부감', '불쾌감', '짜증', '억울함', '기대', '설렘'
]
LIFESTYLE_AXES = ['계획성', '도전성', '활동성']
RELATIONSHIP_AXES = ['갈등대응방식', '표현방향', '친밀속도', '갈등해결방식']
TONE_TAGS = ['진지한', '직설적인', '감성적인']


# ── DiaryMultiHeadClassifier ──────────────────────────────────────────────────

class DiaryMultiHeadClassifier(nn.Module):
    """KcELECTRA 기반 Multi-Head 일기 분류기 (학습 코드와 동일 구조)."""

    def __init__(self, model_name: str, dropout: float = 0.3):
        super().__init__()
        self.backbone = AutoModel.from_pretrained(model_name)
        hidden_size = self.backbone.config.hidden_size  # 768

        self.dropout = nn.Dropout(dropout)

        self.emotion_head = nn.Sequential(
            nn.Linear(hidden_size, 256), nn.ReLU(), nn.Dropout(dropout),
            nn.Linear(256, len(EMOTION_TAGS))
        )
        self.lifestyle_head = nn.Sequential(
            nn.Linear(hidden_size, 128), nn.ReLU(), nn.Dropout(dropout),
            nn.Linear(128, len(LIFESTYLE_AXES) * 3)
        )
        self.relationship_head = nn.Sequential(
            nn.Linear(hidden_size, 128), nn.ReLU(), nn.Dropout(dropout),
            nn.Linear(128, len(RELATIONSHIP_AXES) * 3)
        )
        self.tone_head = nn.Sequential(
            nn.Linear(hidden_size, 64), nn.ReLU(), nn.Dropout(dropout),
            nn.Linear(64, len(TONE_TAGS))
        )

    def forward(self, input_ids, attention_mask):
        outputs = self.backbone(input_ids=input_ids, attention_mask=attention_mask)
        cls_output = self.dropout(outputs.last_hidden_state[:, 0, :])

        emotion_logits = self.emotion_head(cls_output)
        lifestyle_logits = self.lifestyle_head(cls_output).view(-1, len(LIFESTYLE_AXES), 3)
        relationship_logits = self.relationship_head(cls_output).view(-1, len(RELATIONSHIP_AXES), 3)
        tone_logits = self.tone_head(cls_output)

        return emotion_logits, lifestyle_logits, relationship_logits, tone_logits


# ── 모델 로더 (lru_cache) ─────────────────────────────────────────────────────

KCELECTRA_BASE = os.getenv("KCELECTRA_BASE", "beomi/KcELECTRA-base-v2022")
KCELECTRA_MODEL_PATH = os.getenv("KCELECTRA_MODEL_PATH", "diary_model/model.pt")
KOSIMCSE_NAME = os.getenv("KOSIMCSE_NAME", "BM-K/KoSimCSE-roberta-multitask")


@lru_cache(maxsize=1)
def get_kcelectra():
    """
    KcELECTRA 토크나이저 + fine-tuned Multi-Head 모델 로드.
    반환: (tokenizer, model)
    """
    tok = AutoTokenizer.from_pretrained(KCELECTRA_BASE)
    mdl = DiaryMultiHeadClassifier(KCELECTRA_BASE).to(DEVICE)

    if os.path.exists(KCELECTRA_MODEL_PATH):
        state_dict = torch.load(KCELECTRA_MODEL_PATH, map_location=DEVICE)
        mdl.load_state_dict(state_dict)
    else:
        raise FileNotFoundError(
            f"KcELECTRA model.pt not found: {KCELECTRA_MODEL_PATH}"
        )

    mdl.eval()
    return tok, mdl


@lru_cache(maxsize=1)
def get_kosimcse():
    """
    KoSimCSE 토크나이저 + 사전학습 모델 로드.
    반환: (tokenizer, model)
    """
    tok = AutoTokenizer.from_pretrained(KOSIMCSE_NAME)
    mdl = AutoModel.from_pretrained(KOSIMCSE_NAME).to(DEVICE).eval()
    return tok, mdl
