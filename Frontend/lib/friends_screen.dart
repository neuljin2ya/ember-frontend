import 'package:flutter/material.dart';
import 'bottom_nav_bar.dart';
import 'chat_screen.dart';
import 'exchange_diary_write_screen.dart';
import 'api_service.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int _currentIndex = 1;
  int _tabIndex = 0; // 0: Diary, 1: Message, 2: 신청

  List<Map<String, dynamic>> _diaries = [];
  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _requests = [];

  bool _isDiaryLoading = true;
  bool _isMessageLoading = true;
  bool _isRequestLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    _loadDiaries();
    _loadMessages();
    _loadRequests();
  }

  // GET /api/exchange-rooms
  // 응답: { data: { rooms: [ { roomId, roomUuid, partnerNickname, status, currentTurn, isMyTurn, lastDiaryAt, deadline } ] } }
  Future<void> _loadDiaries() async {
    try {
      final data = await ApiService.getExchangeRooms();
      setState(() {
        _diaries = List<Map<String, dynamic>>.from(
          data['data']?['rooms'] ?? [],
        );
        _isDiaryLoading = false;
      });
    } catch (e) {
      setState(() => _isDiaryLoading = false);
    }
  }

  // GET /api/chat-rooms
  // 응답: { data: { chatRooms: [ { chatRoomId, partnerNickname, lastMessage, lastMessageAt, unreadCount } ] } }
  Future<void> _loadMessages() async {
    try {
      final data = await ApiService.getChatRooms();
      setState(() {
        _messages = List<Map<String, dynamic>>.from(
          data['data']?['chatRooms'] ?? [],
        );
        _isMessageLoading = false;
      });
    } catch (e) {
      setState(() => _isMessageLoading = false);
    }
  }

  // GET /api/matching/requests/received
  Future<void> _loadRequests() async {
    try {
      final data = await ApiService.getReceivedRequests();
      final payload = data['data'];
      final rawRequests = payload is List
          ? payload
          : payload is Map
          ? payload['requests'] ?? []
          : [];
      setState(() {
        _requests = List<Map<String, dynamic>>.from(rawRequests);
        _isRequestLoading = false;
      });
    } catch (e) {
      setState(() => _isRequestLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE37474),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Friends',
                style: TextStyle(
                  color: Color(0xFFF8F8F8),
                  fontSize: 28,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        children: [
                          _TabButton(
                            label: 'Diary',
                            isSelected: _tabIndex == 0,
                            onTap: () => setState(() => _tabIndex = 0),
                          ),
                          const SizedBox(width: 8),
                          _TabButton(
                            label: 'Message',
                            isSelected: _tabIndex == 1,
                            onTap: () => setState(() => _tabIndex = 1),
                          ),
                          const SizedBox(width: 8),
                          _TabButton(
                            label: '신청',
                            isSelected: _tabIndex == 2,
                            onTap: () => setState(() => _tabIndex = 2),
                            badgeCount: _requests.length,
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(color: Color(0xFFE37474), thickness: 1),
                    ),
                    Expanded(
                      child: _tabIndex == 0
                          ? _buildDiaryList()
                          : _tabIndex == 1
                          ? _buildMessageList()
                          : _buildRequestList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }

  // ── Diary 탭 ──────────────────────────────────────────────
  Widget _buildDiaryList() {
    if (_isDiaryLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE37474)),
      );
    }
    if (_diaries.isEmpty) {
      return const Center(
        child: Text(
          '진행 중인 교환일기가 없어요',
          style: TextStyle(
            color: Color(0xFFA1ACC3),
            fontSize: 14,
            fontFamily: 'Pretendard',
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFE37474),
      onRefresh: _loadDiaries,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _diaries.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Color(0xFFE37474), thickness: 1),
        itemBuilder: (context, index) {
          final d = _diaries[index];
          final roomId = d['roomId'] is int
              ? d['roomId'] as int
              : int.tryParse(d['roomId']?.toString() ?? '') ?? 0;
          return _DiaryRoomItem(
            partnerNickname: d['partnerNickname'] ?? '',
            turnCount: d['currentTurn'] ?? 0,
            isMyTurn: d['isMyTurn'] ?? false,
            deadlineAt: d['deadline'],
            onWrite: () {
              if (roomId == 0) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExchangeDiaryWriteScreen(
                    roomId: roomId,
                    partnerNickname: d['partnerNickname'] ?? '',
                  ),
                ),
              ).then((_) => _loadDiaries());
            },
            onEnd: () => _showEndDialog(d['roomUuid']),
          );
        },
      ),
    );
  }

  void _showEndDialog(String? roomUuid) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '교환일기를 종료하시겠습니까?',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 16,
            fontFamily: 'Pretendard',
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFA1ACC3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(color: Color(0xFFA1ACC3), fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    if (roomUuid != null) {
                      await ApiService.endExchangeRoom(roomUuid);
                      _loadDiaries();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA1ACC3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: const Text(
                    '끝내기',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Message 탭 ────────────────────────────────────────────
  Widget _buildMessageList() {
    if (_isMessageLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE37474)),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          '메시지가 없어요',
          style: TextStyle(
            color: Color(0xFFA1ACC3),
            fontSize: 14,
            fontFamily: 'Pretendard',
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFE37474),
      onRefresh: _loadMessages,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _messages.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Color(0xFFE37474), thickness: 1),
        itemBuilder: (context, index) {
          final msg = _messages[index];
          final unreadCount = msg['unreadCount'] ?? 0;
          final isNew = unreadCount > 0;
          return _MessageItem(
            name: msg['partnerNickname'] ?? '',
            preview: isNew
                ? '새 메시지 ${unreadCount}개'
                : (msg['lastMessage'] ?? ''),
            isNew: isNew,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    name: msg['partnerNickname'] ?? '',
                    roomId: msg['chatRoomId'] ?? 0,
                  ),
                ),
              ).then((_) => _loadMessages());
            },
          );
        },
      ),
    );
  }

  // ── 신청 탭 ────────────────────────────────────────────────
  Widget _buildRequestList() {
    if (_isRequestLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE37474)),
      );
    }
    if (_requests.isEmpty) {
      return const Center(
        child: Text(
          '받은 신청이 없어요',
          style: TextStyle(
            color: Color(0xFFA1ACC3),
            fontSize: 14,
            fontFamily: 'Pretendard',
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: const Color(0xFFE37474),
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _requests.length,
        separatorBuilder: (_, __) =>
            const Divider(color: Color(0xFFE37474), thickness: 1),
        itemBuilder: (context, index) {
          final req = _requests[index];
          return _RequestItem(
            nickname: req['fromUserNickname'] ?? '',
            diaryTitle: req['diaryPreview'] ?? '',
            onAccept: () => _acceptRequest(req['matchingId'] ?? req['id']),
            onReject: () => _rejectRequest(req['matchingId'] ?? req['id']),
          );
        },
      ),
    );
  }

  Future<void> _acceptRequest(dynamic matchingId) async {
    final id = _asInt(matchingId);
    if (id == null) return;
    final success = await ApiService.acceptMatching(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '수락했어요! 교환일기가 시작됩니다 🎉' : '수락할 수 없어요'),
        backgroundColor: success
            ? const Color(0xFFE37474)
            : const Color(0xFFA1ACC3),
      ),
    );
    if (success) {
      setState(() => _tabIndex = 0);
      _loadRequests();
      _loadDiaries();
    }
  }

  Future<void> _rejectRequest(dynamic matchingId) async {
    final id = _asInt(matchingId);
    if (id == null) return;
    await ApiService.skipMatching(id);
    if (!mounted) return;
    _loadRequests();
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

// ── 탭 버튼 ───────────────────────────────────────────────────
class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFE37474)
                  : const Color(0xFFFFEFE7),
              borderRadius: BorderRadius.circular(38),
              border: isSelected
                  ? Border.all(color: const Color(0xFFE95322))
                  : null,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFE37474),
                fontSize: 16,
                fontFamily: 'Pretendard',
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF391713),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── 교환일기 방 아이템 ─────────────────────────────────────────
class _DiaryRoomItem extends StatelessWidget {
  final String partnerNickname;
  final int turnCount;
  final bool isMyTurn;
  final String? deadlineAt;
  final VoidCallback onWrite;
  final VoidCallback onEnd;

  const _DiaryRoomItem({
    required this.partnerNickname,
    required this.turnCount,
    required this.isMyTurn,
    required this.deadlineAt,
    required this.onWrite,
    required this.onEnd,
  });

  String _formatDeadline(String? dt) {
    if (dt == null) return '';
    try {
      final date = DateTime.parse(dt);
      final diff = date.difference(DateTime.now());
      if (diff.inDays > 0) return 'D-${diff.inDays}';
      if (diff.inHours > 0) return '${diff.inHours}시간 남음';
      return '오늘 마감';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final deadline = _formatDeadline(deadlineAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              image: const DecorationImage(
                image: AssetImage('assets/images/profile.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      partnerNickname,
                      style: const TextStyle(
                        color: Color(0xFF391713),
                        fontSize: 18,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isMyTurn
                            ? const Color(0xFFFFEFE7)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isMyTurn ? '내 차례' : '상대 차례',
                        style: TextStyle(
                          color: isMyTurn
                              ? const Color(0xFFE37474)
                              : const Color(0xFFA1ACC3),
                          fontSize: 11,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${turnCount}회 진행',
                      style: const TextStyle(
                        color: Color(0xFF391713),
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    if (deadline.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        deadline,
                        style: const TextStyle(
                          color: Color(0xFFE37474),
                          fontSize: 12,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: isMyTurn ? onWrite : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isMyTurn
                              ? const Color(0xFFE37474)
                              : const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(100),
                          border: isMyTurn
                              ? Border.all(color: const Color(0xFFE95322))
                              : null,
                        ),
                        child: Text(
                          '교환일기 남기기',
                          style: TextStyle(
                            color: isMyTurn
                                ? Colors.white
                                : const Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onEnd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEFE7),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          '끝내기',
                          style: TextStyle(
                            color: Color(0xFFE37474),
                            fontSize: 12,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 메시지 아이템 ─────────────────────────────────────────────
class _MessageItem extends StatelessWidget {
  final String name;
  final String preview;
  final bool isNew;
  final VoidCallback onTap;

  const _MessageItem({
    required this.name,
    required this.preview,
    required this.isNew,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                image: const DecorationImage(
                  image: AssetImage('assets/images/profile.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFF391713),
                      fontSize: 18,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: TextStyle(
                      color: isNew
                          ? const Color(0xFFE37474)
                          : const Color(0xFF391713),
                      fontSize: 13,
                      fontFamily: 'Pretendard',
                      fontWeight: isNew ? FontWeight.w500 : FontWeight.w300,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF391713)),
          ],
        ),
      ),
    );
  }
}

// ── 신청 아이템 ───────────────────────────────────────────────
class _RequestItem extends StatefulWidget {
  final String nickname;
  final String diaryTitle;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestItem({
    required this.nickname,
    required this.diaryTitle,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_RequestItem> createState() => _RequestItemState();
}

class _RequestItemState extends State<_RequestItem> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: const DecorationImage(
                image: AssetImage('assets/images/profile.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.nickname,
                  style: const TextStyle(
                    color: Color(0xFF391713),
                    fontSize: 18,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.diaryTitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.diaryTitle,
                    style: const TextStyle(
                      color: Color(0xFF391713),
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w300,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                _isLoading
                    ? const SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                          color: Color(0xFFE37474),
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() => _isLoading = true);
                              widget.onAccept();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE37474),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color: const Color(0xFFE95322),
                                ),
                              ),
                              child: const Text(
                                '수락',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() => _isLoading = true);
                              widget.onReject();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEFE7),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: const Text(
                                '거절',
                                style: TextStyle(
                                  color: Color(0xFFE37474),
                                  fontSize: 12,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
