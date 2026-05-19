import 'package:flutter/material.dart';
import 'api_service.dart';

class AiReportScreen extends StatefulWidget {
  const AiReportScreen({super.key});

  @override
  State<AiReportScreen> createState() => _AiReportScreenState();
}

class _AiReportScreenState extends State<AiReportScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _lifestyle;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final results = await Future.wait([
        ApiService.getMyAiProfile(),
        ApiService.getLifestyleReport(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0];
        _lifestyle = results[1];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _tags(String key) {
    final value = _profile?[key];
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final available = _profile?['analysisAvailable'] == true;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF391713)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'AI Report',
          style: TextStyle(
            color: Color(0xFF391713),
            fontSize: 18,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE37474)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4F1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    available
                        ? '지금까지의 일기를 바탕으로 분석한 나의 성향이에요.'
                        : 'AI 분석은 일기 3편 이상부터 열려요.\n조금만 더 기록하면 성향 리포트를 볼 수 있어요.',
                    style: const TextStyle(
                      color: Color(0xFF391713),
                      fontSize: 15,
                      fontFamily: 'Pretendard',
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _ReportSection(
                  title: '관계 성향',
                  tags: _tags('dominantPersonalityTags'),
                ),
                _ReportSection(title: '감정', tags: _tags('dominantEmotionTags')),
                _ReportSection(
                  title: '라이프스타일',
                  tags: _tags('dominantLifestyleTags'),
                ),
                _ReportSection(title: '글쓰기 톤', tags: _tags('dominantToneTags')),
                if (_lifestyle != null) ...[
                  const SizedBox(height: 8),
                  _InfoTile(
                    title: '라이프스타일 리포트',
                    value: _lifestyle?['analysisAvailable'] == false
                        ? '일기 ${_lifestyle?['requiredDiaryCount'] ?? 5}편 이상부터 확인할 수 있어요.'
                        : '활성화됨',
                  ),
                ],
              ],
            ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final List<String> tags;

  const _ReportSection({required this.title, required this.tags});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF391713),
              fontSize: 16,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (tags.isEmpty ? ['분석 대기 중'] : tags)
                .map(
                  (tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
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
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String value;

  const _InfoTile({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF391713),
              fontSize: 14,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontFamily: 'Pretendard',
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
