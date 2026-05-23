import 'package:flutter/material.dart';
import 'profile_edit_screen.dart';
import 'api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getMyProfile();
      setState(() {
        _nickname = data['realName'] ?? data['nickname'] ?? '사용자';
      });
    } catch (e) {}
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '로그아웃',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF391713),
            fontSize: 18,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '로그아웃 하시겠습니까?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF391713),
            fontSize: 14,
            fontFamily: 'Pretendard',
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await ApiService.logout();
                    } catch (e) {
                      await ApiService.clearTokens();
                    }
                    if (!context.mounted) return;
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/socialLogin', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CA3AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '확인',
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
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE37474),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _WithdrawDialog());
  }

  void _openExtraScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_nickname 님, 안녕하세요',
                    style: TextStyle(
                      color: Color(0xFF391713),
                      fontSize: 22,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileEditScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      '계정정보',
                      style: TextStyle(
                        color: Color(0xFF391713),
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            const Divider(color: Color(0xFFE5E5E5), thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    '버전',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  Text(
                    '1.0.0',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE5E5E5), thickness: 1),
            _MenuItem(
              label: '공지사항',
              onTap: () => _openExtraScreen(
                _ApiListScreen(
                  title: '공지사항',
                  loader: ApiService.getNotices,
                  detailLoader: ApiService.getNoticeDetail,
                ),
              ),
            ),
            const Divider(color: Color(0xFFE5E5E5), thickness: 1),
            _MenuItem(
              label: 'FAQ',
              onTap: () => _openExtraScreen(
                _ApiListScreen(title: 'FAQ', loader: ApiService.getFaq),
              ),
            ),
            const Divider(color: Color(0xFFE5E5E5), thickness: 1),
            _MenuItem(
              label: '교환일기 히스토리',
              onTap: () => _openExtraScreen(
                _ApiListScreen(
                  title: '교환일기 히스토리',
                  loader: ApiService.getExchangeRoomHistory,
                ),
              ),
            ),
            const Divider(color: Color(0xFFE5E5E5), thickness: 1),
            _MenuItem(
              label: '채팅 히스토리',
              onTap: () => _openExtraScreen(
                _ApiListScreen(
                  title: '채팅 히스토리',
                  loader: ApiService.getChatRoomHistory,
                ),
              ),
            ),
            const Divider(color: Color(0xFFE5E5E5), thickness: 1),
            _MenuItem(
              label: '알림 설정',
              onTap: () =>
                  _openExtraScreen(const _NotificationSettingsScreen()),
            ),
            const Divider(color: Color(0xFFE5E5E5), thickness: 1),
            _MenuItem(
              label: '내 문의 목록',
              onTap: () => _openExtraScreen(
                _ApiListScreen(
                  title: '내 문의 목록',
                  loader: ApiService.getSupportInquiries,
                  detailLoader: ApiService.getSupportInquiryDetail,
                ),
              ),
            ),
            const Divider(color: Color(0xFFE5E5E5), thickness: 1),
            _MenuItem(
              label: '차단 관리',
              onTap: () => _openExtraScreen(const _BlockListScreen()),
            ),
            const Divider(color: Color(0xFFE5E5E5), thickness: 1),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _showLogoutDialog(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      '로그아웃',
                      style: TextStyle(
                        color: Color(0xFF391713),
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () => _showWithdrawDialog(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      '회원 탈퇴하기',
                      style: TextStyle(
                        color: Color(0xFF391713),
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                      ),
                    ),
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

// 회원탈퇴 다이얼로그 (체크박스 상태 관리 필요해서 StatefulWidget)
class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog();

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  bool _checked = false;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    if (_completed) {
      // 탈퇴 완료 화면
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '회원탈퇴가 완료되었어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF391713),
            fontSize: 18,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '그동안 이용해주셔서 감사합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF391713),
            fontSize: 14,
            fontFamily: 'Pretendard',
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                await ApiService.logout();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/socialLogin', (route) => false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE37474),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                '확인',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 탈퇴 확인 화면
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        '회원탈퇴',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF391713),
          fontSize: 18,
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '삭제 후에는 다시 확인할 수 없고\n지금까지의 분석 결과와 리포트가 모두 삭제돼요.\n정말 탈퇴하시겠어요?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF391713),
              fontSize: 13,
              fontFamily: 'Pretendard',
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _checked = !_checked),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(4),
                    color: _checked ? const Color(0xFFE37474) : Colors.white,
                  ),
                  child: _checked
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '삭제 내용을 확인했고, 회원탈퇴에 동의해요',
                  style: TextStyle(
                    color: Color(0xFF391713),
                    fontSize: 12,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _checked
                    ? () async {
                        await ApiService.deactivate();
                        setState(() => _completed = true);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CA3AF),
                  disabledBackgroundColor: const Color(0xFFE5E5E5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '확인',
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
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE37474),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '취소',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MenuItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF391713),
                fontSize: 16,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _ApiListScreen extends StatefulWidget {
  final String title;
  final Future<Map<String, dynamic>> Function() loader;
  final Future<Map<String, dynamic>> Function(int id)? detailLoader;

  const _ApiListScreen({
    required this.title,
    required this.loader,
    this.detailLoader,
  });

  @override
  State<_ApiListScreen> createState() => _ApiListScreenState();
}

class _ApiListScreenState extends State<_ApiListScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadItems();
  }

  Future<List<Map<String, dynamic>>> _loadItems() async {
    final response = await widget.loader();
    final data = response['data'] ?? response;
    final list = _findFirstList(data);
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List _findFirstList(dynamic value) {
    if (value is List) return value;
    if (value is Map) {
      for (final key in [
        'items',
        'notices',
        'faq',
        'faqs',
        'exchangeRooms',
        'chatRooms',
        'inquiries',
        'rooms',
        'histories',
        'history',
        'content',
      ]) {
        final child = value[key];
        if (child is List) return child;
      }
      for (final child in value.values) {
        final found = _findFirstList(child);
        if (found.isNotEmpty) return found;
      }
    }
    return const [];
  }

  String _pick(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  int? _itemId(Map<String, dynamic> item) {
    for (final key in ['id', 'noticeId', 'inquiryId']) {
      final value = item[key];
      if (value is int) return value;
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<void> _openDetail(Map<String, dynamic> item) async {
    final loader = widget.detailLoader;
    final id = _itemId(item);
    if (loader == null || id == null) return;
    final detail = await loader(id);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ApiDetailScreen(
          title: _pick(detail, ['title', 'question', 'status']).isEmpty
              ? widget.title
              : _pick(detail, ['title', 'question', 'status']),
          data: detail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFE37474)),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: Text(
                '${widget.title}가 없어요',
                style: const TextStyle(
                  color: Color(0xFF391713),
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFE5E5E5)),
            itemBuilder: (context, index) {
              final item = items[index];
              final title = _pick(item, [
                'title',
                'question',
                'partnerNickname',
                'nickname',
                'name',
                'roomName',
                'status',
              ]);
              final subtitle = _pick(item, [
                'content',
                'answer',
                'lastMessage',
                'preview',
                'summary',
                'createdAt',
                'updatedAt',
                'endedAt',
              ]);
              return ListTile(
                onTap: widget.detailLoader == null
                    ? null
                    : () => _openDetail(item),
                title: Text(
                  title.isEmpty ? '항목 ${index + 1}' : title,
                  style: const TextStyle(
                    color: Color(0xFF391713),
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: subtitle.isEmpty
                    ? null
                    : Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                            fontFamily: 'Pretendard',
                            height: 1.35,
                          ),
                        ),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ApiDetailScreen extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;

  const _ApiDetailScreen({required this.title, required this.data});

  String _value(List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final content = _value(['content', 'answer', 'body', 'message']);
    final status = _value(['status', 'category', 'priority']);
    final date = _value(['createdAt', 'publishedAt', 'updatedAt']);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (status.isNotEmpty)
            Text(
              status,
              style: const TextStyle(
                color: Color(0xFFE37474),
                fontSize: 13,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
          if (date.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              date,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 12,
                fontFamily: 'Pretendard',
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            content.isEmpty ? '내용이 없어요.' : content,
            style: const TextStyle(
              color: Color(0xFF391713),
              fontSize: 15,
              fontFamily: 'Pretendard',
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockListScreen extends StatefulWidget {
  const _BlockListScreen();

  @override
  State<_BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<_BlockListScreen> {
  List<Map<String, dynamic>> _blocks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlocks();
  }

  Future<void> _loadBlocks() async {
    try {
      final response = await ApiService.getBlockList();
      final data = response['data'] ?? response;
      final raw = data is Map ? data['blocks'] : null;
      if (!mounted) return;
      setState(() {
        _blocks = raw is List
            ? raw
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList()
            : [];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unblock(Map<String, dynamic> item) async {
    final userId = item['userId'] is int
        ? item['userId'] as int
        : int.tryParse(item['userId']?.toString() ?? '');
    if (userId == null) return;
    final success = await ApiService.unblockUser(userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '차단을 해제했어요.' : '차단을 해제할 수 없어요.')),
    );
    if (success) _loadBlocks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '차단 관리',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE37474)),
            )
          : _blocks.isEmpty
          ? const Center(
              child: Text(
                '차단한 사용자가 없어요',
                style: TextStyle(
                  color: Color(0xFF391713),
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                ),
              ),
            )
          : ListView.separated(
              itemCount: _blocks.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFE5E5E5)),
              itemBuilder: (context, index) {
                final item = _blocks[index];
                return ListTile(
                  title: Text(
                    item['nickname']?.toString() ?? '사용자',
                    style: const TextStyle(
                      color: Color(0xFF391713),
                      fontSize: 15,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    item['blockedAt']?.toString() ?? '',
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () => _unblock(item),
                    child: const Text(
                      '차단 해제',
                      style: TextStyle(color: Color(0xFFE37474)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _NotificationSettingsScreen extends StatefulWidget {
  const _NotificationSettingsScreen();

  @override
  State<_NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<_NotificationSettingsScreen> {
  bool _matching = true;
  bool _exchange = true;
  bool _chat = true;
  bool _couple = true;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final success = await ApiService.updateNotificationSettings({
        'matchingEnabled': _matching,
        'exchangeEnabled': _exchange,
        'chatEnabled': _chat,
        'coupleEnabled': _couple,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '알림 설정을 저장했어요.' : '알림 설정 저장에 실패했어요.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeThumbColor: const Color(0xFFE37474),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF391713),
          fontSize: 15,
          fontFamily: 'Pretendard',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '알림 설정',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _switchTile(
            '매칭 알림',
            _matching,
            (value) => setState(() => _matching = value),
          ),
          _switchTile(
            '교환일기 알림',
            _exchange,
            (value) => setState(() => _exchange = value),
          ),
          _switchTile('채팅 알림', _chat, (value) => setState(() => _chat = value)),
          _switchTile(
            '커플 알림',
            _couple,
            (value) => setState(() => _couple = value),
          ),
          const Spacer(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE37474),
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    _saving ? '저장 중...' : '저장',
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
          ),
        ],
      ),
    );
  }
}
