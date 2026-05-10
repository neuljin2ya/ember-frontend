import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math';
import 'bottom_nav_bar.dart';
import 'api_service.dart';

class DiaryDetailScreen extends StatefulWidget {
  final String title;
  final String time;
  final int diaryId;
  final bool showBottomNav;
  final bool showMatchingButtons;
  final int? matchingId;

  const DiaryDetailScreen({
    super.key,
    required this.title,
    required this.time,
    required this.diaryId,
    this.showBottomNav = true,
    this.showMatchingButtons = false,
    this.matchingId,
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

  int _cardIndex = 0;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final data = await ApiService.getDiaryDetail(widget.diaryId);
      setState(() {
        _diaryDetail = data;
        _keywords = List<String>.from(data['keywords'] ?? []);
        _aiComment = data['aiComment'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSwipeLeft() async {
    await ApiService.selectMatching(widget.diaryId);
  }

  void _nextCard() {
    setState(() {
      _cardIndex++;
      _dragOffset = Offset.zero;
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // 드래그 진행률 (-1 ~ 1)
    final progress = _dragOffset.dx / screenWidth;
    final angle = progress * 0.3; // 회전 각도
    final isSwipingLeft = _dragOffset.dx < 0;

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
                    icon: const Icon(Icons.chevron_left,
                        size: 28, color: Color(0xFF391713)),
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
                    icon: const Icon(Icons.close,
                        size: 24, color: Color(0xFF391713)),
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                  ),
                ],
              ),
            ),

            // 카드 스택
            Expanded(
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // 뒤 카드 (회색으로 살짝 덮인 상태)
                  Positioned.fill(
                    child: Transform.scale(
                      scale: 0.95 + (0.05 * _dragOffset.dx.abs() / screenWidth),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        child: Stack(
                          children: [
                            _buildCardContent(),
                            // 회색 오버레이 (드래그할수록 투명해짐)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(
                                    0.2 - (0.2 * _dragOffset.dx.abs() / screenWidth).clamp(0.0, 0.2)),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(30)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 앞 카드 (드래그 가능)
                  GestureDetector(
                    onPanStart: (_) => setState(() => _isDragging = true),
                    onPanUpdate: (details) {
                      setState(() {
                        _dragOffset += details.delta;
                      });
                    },
                    onPanEnd: (details) {
                      final velocity = details.velocity.pixelsPerSecond.dx;
                      if (_dragOffset.dx < -screenWidth * 0.3 || velocity < -500) {
                        // 왼쪽 스와이프 완료
                        _animateOut(context, screenWidth);
                        _onSwipeLeft();
                      } else if (_dragOffset.dx > screenWidth * 0.3 || velocity > 500) {
                        // 오른쪽 스와이프 완료 → 다음 카드
                        _animateOut(context, -screenWidth);
                        ApiService.skipMatching(widget.diaryId);
                      } else {
                        // 원위치
                        setState(() {
                          _dragOffset = Offset.zero;
                          _isDragging = false;
                        });
                      }
                    },
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translate(_dragOffset.dx, _dragOffset.dy * 0.3)
                        ..rotateZ(angle),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                          BorderRadius.vertical(top: Radius.circular(30)),
                        ),
                        child: _buildCardContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Expanded(카드 스택) 아래에 추가
            if (widget.showMatchingButtons)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await ApiService.acceptMatching(widget.matchingId!);
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE37474),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('수락', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Pretendard')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA1ACC3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('거절', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Pretendard')),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),

      bottomNavigationBar: widget.showBottomNav
          ? BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      )
          : null,
    );
  }

  void _animateOut(BuildContext context, double targetX) async {
    // 빠르게 날아가는 효과
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      setState(() {
        _dragOffset = Offset(
          _dragOffset.dx + targetX / 10,
          _dragOffset.dy,
        );
      });
    }
    _nextCard();
  }

  Widget _buildCardContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 회색 네모 + 블러
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFFD7D7D7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _diaryDetail?['content'] ?? '',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        height: 2.0,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                      child: Container(
                        color: Colors.white.withOpacity(0.05),
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
                children: _keywords.take(3).toList()
                    .map((tag) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
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
                ))
                    .toList(),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _keywords.skip(3).take(3).toList()
                    .map((tag) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
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
                ))
                    .toList(),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // AI 분석 코멘트
          Expanded(
            child: Text(
              _aiComment.isEmpty
                  ? '이 사람과 교환일기를 시작하고 싶다면 왼쪽으로,\n아니라면 오른쪽으로 스와이프해보세요!'
                  : _aiComment,
              textAlign: TextAlign.center,
              style: TextStyle(
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