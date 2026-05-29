import 'package:flutter/material.dart';

import 'api_service.dart';
import 'diary_screen.dart';
import 'text_utils.dart';

class TutorialScreen extends StatefulWidget {
  final bool requiredForSignup;

  const TutorialScreen({super.key, this.requiredForSignup = false});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  List<Map<String, dynamic>> _pages = const [];
  bool _isLoading = true;
  bool _isCompleting = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPages() async {
    try {
      final response = await ApiService.getTutorialPages();
      final raw = response['data'];
      final pages = raw is List
          ? raw
                .whereType<Map>()
                .map((page) => Map<String, dynamic>.from(page))
                .toList()
          : <Map<String, dynamic>>[];
      pages.sort((a, b) {
        final left = int.tryParse(a['pageOrder']?.toString() ?? '') ?? 0;
        final right = int.tryParse(b['pageOrder']?.toString() ?? '') ?? 0;
        return left.compareTo(right);
      });

      if (!mounted) return;
      setState(() {
        _pages = pages.isEmpty ? _fallbackPages : pages;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pages = _fallbackPages;
        _isLoading = false;
      });
    }
  }

  Future<void> _completeTutorial() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    try {
      final ok = await ApiService.completeTutorial();
      if (!mounted) return;
      if (!ok) throw Exception('튜토리얼 완료 저장에 실패했어요.');
      if (widget.requiredForSignup) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DiaryScreen(requiredForSignup: true)),
          (route) => false,
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCompleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('튜토리얼 완료 실패: $e')));
    }
  }

  void _next() {
    if (_currentIndex >= _pages.length - 1) {
      _completeTutorial();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  bool get _isLast => _currentIndex >= _pages.length - 1;

  static const List<Map<String, dynamic>> _fallbackPages = [
    {
      'pageOrder': 1,
      'title': '일기로 시작해요',
      'body': '오늘의 이야기를 남기면 AI가 감정과 성향을 분석해 더 잘 맞는 연결을 도와줘요.',
    },
    {
      'pageOrder': 2,
      'title': '서로의 일기를 읽어요',
      'body': '탐색에서 마음이 가는 일기를 선택하고, 수락되면 교환일기 방이 열려요.',
    },
    {
      'pageOrder': 3,
      'title': '천천히 대화로 이어져요',
      'body': '교환일기를 주고받은 뒤 서로 원하면 채팅으로 자연스럽게 넘어갈 수 있어요.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE37474)),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 30),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _isCompleting
                              ? null
                              : () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_ios_new),
                          color: const Color(0xFF391713),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _isCompleting ? null : _completeTutorial,
                          child: const Text(
                            '건너뛰기',
                            style: TextStyle(
                              color: Color(0xFFE37474),
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _pages.length,
                        onPageChanged: (index) {
                          setState(() => _currentIndex = index);
                        },
                        itemBuilder: (context, index) {
                          return _TutorialPage(page: _pages[index]);
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (index) {
                        final selected = index == _currentIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: selected ? 34 : 18,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFE37474)
                                : const Color(0xFFEAEAEA),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isCompleting ? null : _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE37474),
                          disabledBackgroundColor: const Color(0xFFE8B4B4),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isCompleting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : Text(
                                _isLast ? '시작하기' : '다음',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TutorialPage extends StatelessWidget {
  final Map<String, dynamic> page;

  const _TutorialPage({required this.page});

  @override
  Widget build(BuildContext context) {
    final title = decodeHtmlEntities(page['title'] ?? '');
    final body = decodeHtmlEntities(page['body'] ?? page['content'] ?? '');
    final imageUrl = page['imageUrl']?.toString();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0ED),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.auto_stories,
                        size: 62,
                        color: Color(0xFFE37474),
                      ),
                    )
                  : const Icon(
                      Icons.auto_stories,
                      size: 62,
                      color: Color(0xFFE37474),
                    ),
            ),
            const SizedBox(height: 38),
            Text(
              title.isEmpty ? 'Ember 시작하기' : title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF391713),
                fontSize: 28,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 16,
                fontFamily: 'Pretendard',
                height: 1.65,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
