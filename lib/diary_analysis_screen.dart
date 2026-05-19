import 'package:flutter/material.dart';
import 'api_service.dart';
import 'ai_report_screen.dart';
import 'text_utils.dart';

class DiaryAnalysisScreen extends StatefulWidget {
  final int? diaryId;

  const DiaryAnalysisScreen({super.key, this.diaryId});

  @override
  State<DiaryAnalysisScreen> createState() => _DiaryAnalysisScreenState();
}

class _DiaryAnalysisScreenState extends State<DiaryAnalysisScreen> {
  Map<String, dynamic>? _diary;
  bool _isLoading = true;
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    if (widget.diaryId == null) {
      setState(() => _isLoading = false);
      return;
    }

    for (var i = 0; i < 5; i++) {
      try {
        final data = await ApiService.getDiary(widget.diaryId!);
        final status = data['analysisStatus']?.toString();
        if (!mounted) return;
        setState(() {
          _diary = data;
          _isDone = status == 'COMPLETED' || status == null;
          _isLoading = false;
        });
        if (_isDone) return;
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  List<String> _tags(String key) {
    final value = _diary?[key];
    if (value is! List) return const [];
    return value
        .map((tag) {
          if (tag is Map) {
            return tag['label'] ?? tag['name'] ?? tag['tag'] ?? '';
          }
          return tag;
        })
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final summary = decodeHtmlEntities(_diary?['summary'] ?? '');
    final personality = _tags('personalityKeywords');
    final emotions = _tags('emotionTags');
    final lifestyle = _tags('lifestyleTags');
    final tone = _tags('toneTags');
    final hasAnalysisDetails =
        summary.isNotEmpty ||
        personality.isNotEmpty ||
        emotions.isNotEmpty ||
        lifestyle.isNotEmpty ||
        tone.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE37474)),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.auto_awesome,
                                  color: Color(0xFFE37474),
                                  size: 58,
                                ),
                              ),
                              const SizedBox(height: 22),
                              Center(
                                child: Text(
                                  _isDone ? 'AI 분석 결과' : 'AI 분석 중이에요',
                                  style: const TextStyle(
                                    color: Color(0xFF391713),
                                    fontSize: 24,
                                    fontFamily: 'Pretendard',
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Center(
                                child: Text(
                                  _isDone
                                      ? '오늘 일기에서 발견한 마음의 결이에요.'
                                      : '분석이 조금 더 걸릴 수 있어요. 결과가 준비되면 리포트에서 다시 볼 수 있어요.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF6B7280),
                                    fontSize: 14,
                                    fontFamily: 'Pretendard',
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              if (hasAnalysisDetails)
                                const SizedBox(height: 28),
                              if (summary.isNotEmpty)
                                _ResultCard(title: '요약', child: Text(summary)),
                              _TagSection(title: '성격 키워드', tags: personality),
                              _TagSection(title: '감정', tags: emotions),
                              _TagSection(title: '라이프스타일', tags: lifestyle),
                              _TagSection(title: '톤', tags: tone),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/home');
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFE37474)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '홈으로',
                              style: TextStyle(color: Color(0xFFE37474)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AiReportScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE37474),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'AI 리포트',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ResultCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xFF391713),
          fontSize: 14,
          fontFamily: 'Pretendard',
          height: 1.5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final String title;
  final List<String> tags;

  const _TagSection({required this.title, required this.tags});

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return _ResultCard(
      title: title,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags
            .map(
              (tag) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFE7),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: Color(0xFFE37474),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
