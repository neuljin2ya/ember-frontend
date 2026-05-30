import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/spacing.dart';

/// Ember 일기 리스트 아이템 카드
class EmberDiaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final List<String> keywords;
  final double? matchingScore;

  const EmberDiaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.keywords = const [],
    this.matchingScore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: EmberSpacing.borderRadiusLg,
          border: Border.all(color: EmberColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (matchingScore != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: matchingScore! >= 0.7 ? EmberColors.backgroundPink : EmberColors.backgroundPeach,
                        borderRadius: EmberSpacing.borderRadiusPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '♡ ${(matchingScore! * 100).toInt()}%',
                            style: EmberTypography.captionSmall.copyWith(
                              color: EmberColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            matchingScore! >= 0.7 ? '잘 맞을 것 같아요' : '공통점이 있어요',
                            style: EmberTypography.captionSmall.copyWith(
                              color: EmberColors.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: EmberTypography.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: EmberTypography.captionSmall,
                  ),
                  if (keywords.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: keywords.take(3).map((k) => EmberKeywordChip(label: k)).toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: EmberColors.textTertiary, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Ember 매칭 요청 카드
class EmberMatchingCard extends StatelessWidget {
  final String nickname;
  final String ageGroup;
  final String preview;
  final List<String> keywords;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const EmberMatchingCard({
    super.key,
    required this.nickname,
    required this.ageGroup,
    required this.preview,
    required this.keywords,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: EmberSpacing.borderRadiusLg,
        border: Border.all(color: EmberColors.borderPink),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: EmberColors.backgroundPink,
                  borderRadius: EmberSpacing.borderRadiusMd,
                ),
                child: const Icon(Icons.person_outline, color: EmberColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nickname,
                      style: EmberTypography.titleMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (ageGroup.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(ageGroup, style: EmberTypography.captionSmall),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Preview
          Text(
            preview,
            style: EmberTypography.bodySmall.copyWith(
              color: EmberColors.textSecondary,
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),

          // Keywords
          if (keywords.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: keywords.map((k) => EmberKeywordChip(label: k)).toList(),
            ),
          ],

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: EmberColors.border),
                    shape: RoundedRectangleBorder(borderRadius: EmberSpacing.borderRadiusMd),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    '넘기기',
                    style: EmberTypography.buttonMedium.copyWith(color: EmberColors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: EmberColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: EmberSpacing.borderRadiusMd),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text('수락하기', style: EmberTypography.buttonMedium),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ember 교환일기 친구 카드
class EmberFriendCard extends StatelessWidget {
  final String partnerNickname;
  final String turnInfo;
  final bool isMyTurn;
  final String? deadline;
  final String? status;
  final VoidCallback onTap;
  final VoidCallback onExchange;
  final VoidCallback? onViewReport;

  const EmberFriendCard({
    super.key,
    required this.partnerNickname,
    required this.turnInfo,
    required this.isMyTurn,
    this.deadline,
    this.status,
    required this.onTap,
    required this.onExchange,
    this.onViewReport,
  });

  bool get _isCompleted {
    final s = status?.toUpperCase() ?? '';
    return s == 'COMPLETED' || s == 'CHAT_CONNECTED' || s == 'ENDED' || s == 'ARCHIVED';
  }

  String get _actionLabel {
    final s = status?.toUpperCase() ?? '';
    if (s == 'COMPLETED' || s == 'CHAT_CONNECTED') return '리포트 보기';
    if (s == 'ENDED' || s == 'ARCHIVED') return '종료됨';
    return isMyTurn ? '일기 쓰기' : '상대 차례';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: EmberSpacing.borderRadiusLg,
          border: Border.all(color: EmberColors.borderLight),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: EmberSpacing.borderRadiusMd,
                color: EmberColors.backgroundPeach,
              ),
              child: const Icon(Icons.menu_book_outlined, color: EmberColors.primary, size: 28),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: Text(partnerNickname, style: EmberTypography.titleMedium, overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: EmberColors.backgroundPink,
                          borderRadius: EmberSpacing.borderRadiusPill,
                        ),
                        child: Text(
                          turnInfo,
                          style: EmberTypography.tag.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (deadline != null && deadline!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('마감 $deadline', style: EmberTypography.captionSmall),
                  ],
                  const SizedBox(height: 10),
                  _ActionChip(
                    label: _actionLabel,
                    isActive: _isCompleted || isMyTurn,
                    onTap: _isCompleted ? onViewReport : (isMyTurn ? onExchange : null),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _ActionChip({required this.label, required this.isActive, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? EmberColors.primary : EmberColors.backgroundPeach,
          borderRadius: EmberSpacing.borderRadiusPill,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : EmberColors.primary,
            fontSize: 12,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Ember 채팅 메시지 카드
class EmberMessageCard extends StatelessWidget {
  final String name;
  final String preview;
  final bool hasUnread;
  final VoidCallback onTap;
  final VoidCallback? onLeave;

  const EmberMessageCard({
    super.key,
    required this.name,
    required this.preview,
    required this.hasUnread,
    required this.onTap,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: EmberSpacing.borderRadiusLg,
          border: Border.all(
            color: hasUnread ? EmberColors.borderPink : EmberColors.borderLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: EmberSpacing.borderRadiusMd,
                color: EmberColors.backgroundPeach,
              ),
              child: const Icon(Icons.chat_bubble_outline, color: EmberColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: EmberTypography.titleMedium),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: EmberColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: EmberTypography.caption.copyWith(
                      color: hasUnread ? EmberColors.primary : EmberColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onLeave != null)
              TextButton(
                onPressed: onLeave,
                child: Text(
                  '나가기',
                  style: EmberTypography.captionSmall.copyWith(color: EmberColors.primary),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: EmberColors.textTertiary, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Ember 키워드 칩
class EmberKeywordChip extends StatelessWidget {
  final String label;

  const EmberKeywordChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: EmberColors.backgroundPeach,
        borderRadius: EmberSpacing.borderRadiusPill,
      ),
      child: Text(label, style: EmberTypography.tag),
    );
  }
}
