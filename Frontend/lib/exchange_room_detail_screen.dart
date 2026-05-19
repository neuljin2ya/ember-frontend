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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoom();
  }

  Future<void> _loadRoom() async {
    try {
      final data = await ApiService.getExchangeRoomDetail(widget.roomId);
      if (!mounted) return;
      setState(() {
        _room = data;
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
