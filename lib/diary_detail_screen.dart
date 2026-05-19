import 'package:flutter/material.dart';
import 'dart:ui';
import 'bottom_nav_bar.dart';
import 'api_service.dart';
import 'text_utils.dart';

class DiaryDetailScreen extends StatefulWidget {
  final String title;
  final String time;
  final int diaryId;
  final bool showBottomNav;
  final bool showMatchingButtons;
  final bool showDecisionButtons;
  final int? matchingId;
  final String? initialContent;
  final List<String> initialKeywords;

  const DiaryDetailScreen({
    super.key,
    required this.title,
    required this.time,
    required this.diaryId,
    this.showBottomNav = true,
    this.showMatchingButtons = false,
    this.showDecisionButtons = false,
    this.matchingId,
    this.initialContent,
    this.initialKeywords = const [],
  });

  @override
  State<DiaryDetailScreen> createState() => _DiaryDetailScreenState();
}

class _DiaryDetailScreenState extends State<DiaryDetailScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _diaryDetail;
  List<String> _keywords = [];
  String _aiComment = '';
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _diaryDetail = {
      if ((widget.initialContent ?? widget.title).isNotEmpty)
        'content': widget.initialContent ?? widget.title,
    };
    _keywords = widget.initialKeywords;
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final isExploreOrRequest =
          widget.showDecisionButtons || widget.showMatchingButtons;
      final data = isExploreOrRequest
          ? await ApiService.getDiaryDetail(widget.diaryId)
          : await ApiService.getDiary(widget.diaryId);
      final detail = data['data'] ?? data;
      final fallbackContent = widget.initialContent ?? widget.title;
      setState(() {
        _diaryDetail = {
          if (detail is Map) ...Map<String, dynamic>.from(detail),
          if (fallbackContent.isNotEmpty &&
              (detail is! Map ||
                  (detail['content'] ??
                              detail['contentPreview'] ??
                              detail['previewContent'])
                          ?.toString()
                          .isEmpty !=
                      false))
            'content': fallbackContent,
        };
        _keywords = List<String>.from(
          (detail is Map
                  ? detail['keywords'] ??
                        detail['personalityKeywords'] ??
                        detail['moodTags']
                  : null) ??
              widget.initialKeywords,
        );
        _aiComment = detail is Map
            ? detail['aiComment'] ?? detail['summary'] ?? ''
            : '';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectMatching() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    final success = await ApiService.selectMatching(widget.diaryId);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(success ? '신청했어요' : '신청할 수 없어요')));
    if (success) Navigator.pop(context);
  }

  Future<void> _skipMatching() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);
    await ApiService.skipMatching(widget.diaryId);

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pop(context);
  }

  Future<void> _acceptMatching() async {
    if (_isSubmitting || widget.matchingId == null) return;

    setState(() => _isSubmitting = true);
    final result = await ApiService.acceptMatchingResponse(widget.matchingId!);
    final code = result['code']?.toString();
    final success =
        code == '200' ||
        code == '201' ||
        result['data']?['status']?.toString() == 'MATCHED';
    final message = result['message']?.toString();

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '수락했어요' : message ?? '수락할 수 없어요')),
    );
    if (success) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE37474),
      body: SafeArea(
        child: Column(
          children: [
            // 상단
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 28,
                      color: Color(0xFF391713),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Diary',
                    style: TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 30,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 24,
                      color: Color(0xFF391713),
                    ),
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                  ),
                ],
              ),
            ),

            // 일기 카드
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFE37474),
                        ),
                      )
                    : _buildCardContent(),
              ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),

      bottomNavigationBar: widget.showBottomNav
          ? BottomNavBar(
              currentIndex: _currentIndex,
              onTap: (i) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                  arguments: i,
                );
              },
            )
          : null,
    );
  }

  Widget _buildActionButtons() {
    final isRequest = widget.showMatchingButtons;
    final isDecision = widget.showDecisionButtons;

    if (!isRequest && !isDecision) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Row(
        children: [
          if (isRequest) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA1ACC3),
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text(
                  '거절',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _acceptMatching,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE37474),
                  disabledBackgroundColor: const Color(0xFFF0B7B7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text(
                  '수락',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _selectMatching,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE37474),
                  disabledBackgroundColor: const Color(0xFFF0B7B7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text(
                  '교환일기 신청하기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardContent() {
    final shouldBlur = widget.showDecisionButtons || widget.showMatchingButtons;
    final content = decodeHtmlEntities(
      _diaryDetail?['content'] ??
          _diaryDetail?['contentPreview'] ??
          _diaryDetail?['previewContent'] ??
          widget.initialContent ??
          widget.title,
    );

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: shouldBlur
                ? 220
                : MediaQuery.of(context).size.height * 0.48,
            constraints: shouldBlur
                ? null
                : const BoxConstraints(minHeight: 260),
            decoration: BoxDecoration(
              color: shouldBlur
                  ? const Color(0xFFD7D7D7)
                  : const Color(0xFFFFFAF6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      physics: shouldBlur
                          ? const NeverScrollableScrollPhysics()
                          : const BouncingScrollPhysics(),
                      child: Text(
                        content,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontFamily: 'Pretendard',
                          height: 2.0,
                        ),
                      ),
                    ),
                  ),
                  if (shouldBlur)
                    Positioned.fill(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Container(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 키워드 태그
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _keywords
                    .take(3)
                    .toList()
                    .map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEFE7),
                            borderRadius: BorderRadius.circular(38),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: Color(0xFFE37474),
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _keywords
                    .skip(3)
                    .take(3)
                    .toList()
                    .map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEFE7),
                            borderRadius: BorderRadius.circular(38),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              color: Color(0xFFE37474),
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // AI 분석 코멘트
          Expanded(
            child: Text(
              _aiComment.isEmpty
                  ? widget.showDecisionButtons
                        ? '이 사람과 교환일기를 시작하고 싶다면 아래 버튼을 눌러주세요.'
                        : ''
                  : _aiComment,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
                height: 2.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
