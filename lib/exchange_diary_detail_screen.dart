import 'package:flutter/material.dart';
import 'api_service.dart';

class ExchangeDiaryDetailScreen extends StatefulWidget {
  final int roomId;
  final int diaryId;
  final String partnerNickname;

  const ExchangeDiaryDetailScreen({
    super.key,
    required this.roomId,
    required this.diaryId,
    required this.partnerNickname,
  });

  @override
  State<ExchangeDiaryDetailScreen> createState() =>
      _ExchangeDiaryDetailScreenState();
}

class _ExchangeDiaryDetailScreenState extends State<ExchangeDiaryDetailScreen> {
  Map<String, dynamic>? _diary;
  bool _isLoading = true;
  String? _myReaction;
  int? _myUserId;

  final List<Map<String, dynamic>> _reactions = [
    {'type': 'HEART', 'emoji': '❤️'},
    {'type': 'SAD', 'emoji': '😢'},
    {'type': 'HAPPY', 'emoji': '😊'},
    {'type': 'FIRE', 'emoji': '🔥'},
  ];

  @override
  void initState() {
    super.initState();
    _loadMyUserId();
    _loadDiary();
  }

  Future<void> _loadMyUserId() async {
    final userId = await ApiService.getCurrentUserId();
    if (mounted) setState(() => _myUserId = userId);
  }

  bool get _isMine =>
      _myUserId != null && _diary?['authorId'] == _myUserId;

  Future<void> _loadDiary() async {
    try {
      final data = await ApiService.getExchangeDiaryDetail(
        roomId: widget.roomId,
        diaryId: widget.diaryId,
      );
      setState(() {
        _diary = data;
        _myReaction = data['reaction'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendReaction(String type) async {
    try {
      await ApiService.postExchangeDiaryReaction(
        roomId: widget.roomId,
        diaryId: widget.diaryId,
        reaction: type,
      );
      setState(() => _myReaction = type);
    } catch (e) {}
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
                  Text(
                    _isMine ? '나의 일기' : '${widget.partnerNickname}의 일기',
                    style: const TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 22,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // 흰 카드
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
                          // 일기 내용
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 날짜
                                  Text(
                                    _diary?['readAt']?.toString().split('T').first ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFFE37474),
                                      fontSize: 13,
                                      fontFamily: 'Pretendard',
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // 제목
                                  if (_diary?['title'] != null)
                                    Text(
                                      _diary!['title'],
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 20,
                                        fontFamily: 'Pretendard',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  // 본문
                                  Text(
                                    _diary?['content'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontFamily: 'Pretendard',
                                      height: 1.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 리액션 버튼
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, -4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: _reactions.map((r) {
                                final isSelected = _myReaction == r['type'];
                                return GestureDetector(
                                  onTap: () => _sendReaction(r['type']),
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFFFFEFE7)
                                          : const Color(0xFFF8F8F8),
                                      borderRadius: BorderRadius.circular(16),
                                      border: isSelected
                                          ? Border.all(
                                              color: const Color(0xFFE37474),
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        r['emoji'],
                                        style: const TextStyle(fontSize: 28),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
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
