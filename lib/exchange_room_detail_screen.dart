import 'package:flutter/material.dart';

import 'api_service.dart';
import 'exchange_diary_detail_screen.dart';
import 'exchange_diary_write_screen.dart';

class ExchangeRoomDetailScreen extends StatefulWidget {
  final int roomId;
  final String partnerNickname;

  const ExchangeRoomDetailScreen({
    super.key,
    required this.roomId,
    required this.partnerNickname,
  });

  @override
  State<ExchangeRoomDetailScreen> createState() =>
      _ExchangeRoomDetailScreenState();
}

class _ExchangeRoomDetailScreenState extends State<ExchangeRoomDetailScreen> {
  Map<String, dynamic>? _room;
  Map<String, dynamic>? _nextStepStatus;
  bool _isLoading = true;
  bool _isReportLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRoom();
  }

  Future<void> _loadRoom() async {
    try {
      final data = await ApiService.getExchangeRoomDetail(widget.roomId);
      Map<String, dynamic>? nextStepStatus;
      try {
        nextStepStatus = await ApiService.getNextStepStatus(widget.roomId);
      } catch (e) {
        nextStepStatus = null;
      }
      if (!mounted) return;
      setState(() {
        _room = data;
        _nextStepStatus = nextStepStatus;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _partnerNickname {
    final partner = _room?['partner'];
    if (partner is Map && partner['nickname'] != null) {
      return partner['nickname'].toString();
    }
    return widget.partnerNickname;
  }

  List<Map<String, dynamic>> get _diaries {
    final diaries = _room?['diaries'];
    if (diaries is List) return List<Map<String, dynamic>>.from(diaries);
    return const [];
  }

  Future<void> _openWrite() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExchangeDiaryWriteScreen(
          roomId: widget.roomId,
          partnerNickname: _partnerNickname,
        ),
      ),
    );
    _loadRoom();
  }

  Future<void> _chooseNextStep(String choice) async {
    final success = await ApiService.postNextStep(widget.roomId, choice);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '선택을 보냈어요' : '선택을 보낼 수 없어요')),
    );
    if (success) _loadRoom();
  }

  bool get _canViewReport {
    final status = (_room?['status'] ?? _nextStepStatus?['status'])
        ?.toString()
        .toUpperCase();
    return status == 'COMPLETED' ||
        status == 'CHAT_CONNECTED' ||
        status == 'ARCHIVED';
  }

  Future<void> _openReport() async {
    if (_isReportLoading) return;
    setState(() => _isReportLoading = true);
    try {
      final report = await ApiService.getExchangeRoomReport(widget.roomId);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => _ExchangeReportDialog(report: report),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('리포트를 불러올 수 없어요: $e')));
    } finally {
      if (mounted) setState(() => _isReportLoading = false);
    }
  }

  String _formatDate(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length >= 10) return text.substring(0, 10);
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final isMyTurn = _room?['isMyTurn'] == true;
    final nextStepRequired = _room?['nextStepRequired'] == true;
    final currentTurn = _room?['currentTurn'];
    final deadline = _formatDate(_room?['deadline']);

    return Scaffold(
      backgroundColor: const Color(0xFFE37474),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFF391713),
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      _partnerNickname,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF8F8F8),
                        fontSize: 24,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
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
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEFE7),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isMyTurn ? '내가 쓸 차례예요' : '상대가 쓰는 차례예요',
                                    style: const TextStyle(
                                      color: Color(0xFFE37474),
                                      fontSize: 18,
                                      fontFamily: 'Pretendard',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    [
                                      if (currentTurn != null)
                                        '$currentTurn번째 턴 진행 중',
                                      if (deadline.isNotEmpty) '마감 $deadline',
                                      if (_nextStepStatus?['status'] != null)
                                        '관계 확장 ${_nextStepStatus!['status']}',
                                    ].join(' · '),
                                    style: const TextStyle(
                                      color: Color(0xFF391713),
                                      fontSize: 13,
                                      fontFamily: 'Pretendard',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: _diaries.isEmpty
                                ? const Center(
                                    child: Text(
                                      '아직 주고받은 교환일기가 없어요',
                                      style: TextStyle(
                                        color: Color(0xFF391713),
                                        fontFamily: 'Pretendard',
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      8,
                                      24,
                                      24,
                                    ),
                                    itemCount: _diaries.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final diary = _diaries[index];
                                      final content =
                                          diary['content']?.toString() ?? '';
                                      final turn = diary['turnNumber'];
                                      return _ExchangeDiaryTile(
                                        title: turn == null
                                            ? '교환일기'
                                            : '$turn번째 교환일기',
                                        preview: content,
                                        date: _formatDate(diary['createdAt']),
                                        reaction:
                                            diary['reaction']?.toString() ?? '',
                                        onTap: () {
                                          final diaryId = diary['diaryId'];
                                          if (diaryId is! int) return;
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ExchangeDiaryDetailScreen(
                                                    roomId: widget.roomId,
                                                    diaryId: diaryId,
                                                    partnerNickname:
                                                        _partnerNickname,
                                                  ),
                                            ),
                                          ).then((_) => _loadRoom());
                                        },
                                      );
                                    },
                                  ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            child: nextStepRequired
                                ? Row(
                                    children: [
                                      Expanded(
                                        child: _RoomActionButton(
                                          label: '계속하기',
                                          color: const Color(0xFFA1ACC3),
                                          onPressed: () =>
                                              _chooseNextStep('CONTINUE'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _RoomActionButton(
                                          label: '채팅하기',
                                          color: const Color(0xFFE37474),
                                          onPressed: () =>
                                              _chooseNextStep('CHAT'),
                                        ),
                                      ),
                                    ],
                                  )
                                : _canViewReport
                                ? SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isReportLoading
                                          ? null
                                          : _openReport,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFE37474,
                                        ),
                                        disabledBackgroundColor: const Color(
                                          0xFFF0B7B7,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        _isReportLoading
                                            ? '불러오는 중...'
                                            : 'AI 공통점 리포트',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  )
                                : SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: isMyTurn ? _openWrite : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFFE37474,
                                        ),
                                        disabledBackgroundColor: const Color(
                                          0xFFF0B7B7,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        isMyTurn ? '교환일기 남기기' : '상대 차례를 기다리는 중',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _RoomActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ExchangeReportDialog extends StatelessWidget {
  final Map<String, dynamic> report;

  const _ExchangeReportDialog({required this.report});

  List<String> _stringList(String key) {
    final value = report[key];
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final keywords = _stringList('commonKeywords');
    final lifestyles = _stringList('lifestylePatterns');
    final similarity = report['emotionSimilarity']?.toString();
    final summary =
        report['summary'] ??
        report['description'] ??
        report['comment'] ??
        '두 사람의 교환일기에서 발견한 공통점을 정리했어요.';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'AI 공통점 리포트',
        style: TextStyle(
          color: Color(0xFF391713),
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              summary.toString(),
              style: const TextStyle(
                color: Color(0xFF391713),
                fontFamily: 'Pretendard',
                height: 1.5,
              ),
            ),
            if (similarity != null) ...[
              const SizedBox(height: 14),
              Text('감정 유사도 $similarity'),
            ],
            if (keywords.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ReportChips(title: '공통 키워드', values: keywords),
            ],
            if (lifestyles.isNotEmpty) ...[
              const SizedBox(height: 14),
              _ReportChips(title: '라이프스타일', values: lifestyles),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기', style: TextStyle(color: Color(0xFFE37474))),
        ),
      ],
    );
  }
}

class _ReportChips extends StatelessWidget {
  final String title;
  final List<String> values;

  const _ReportChips({required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF391713),
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (value) => Chip(
                  label: Text(value),
                  backgroundColor: const Color(0xFFFFEFE7),
                  labelStyle: const TextStyle(color: Color(0xFFE37474)),
                  side: BorderSide.none,
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ExchangeDiaryTile extends StatelessWidget {
  final String title;
  final String preview;
  final String date;
  final String reaction;
  final VoidCallback onTap;

  const _ExchangeDiaryTile({
    required this.title,
    required this.preview,
    required this.date,
    required this.reaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF391713),
                            fontSize: 16,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (date.isNotEmpty)
                        Text(
                          date,
                          style: const TextStyle(
                            color: Color(0xFFA1ACC3),
                            fontSize: 12,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preview.isEmpty ? '내용을 불러오는 중이에요' : preview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF391713),
                      fontSize: 13,
                      fontFamily: 'Pretendard',
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            if (reaction.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                reaction,
                style: const TextStyle(
                  color: Color(0xFFE37474),
                  fontSize: 12,
                  fontFamily: 'Pretendard',
                ),
              ),
            ],
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFF391713)),
          ],
        ),
      ),
    );
  }
}
