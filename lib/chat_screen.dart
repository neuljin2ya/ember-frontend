import 'package:flutter/material.dart';
import 'dart:io';
import 'api_service.dart';

class ChatScreen extends StatefulWidget {
  final String name;
  final int roomId;
  const ChatScreen({super.key, required this.name, required this.roomId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  int? _myUserId;
  Map<String, dynamic>? _partnerProfile;

  String _partnerName() {
    return _profileText(_partnerProfile, [
      'realName',
      'name',
      'nickname',
      'partnerNickname',
    ], fallback: widget.name);
  }

  ImageProvider _partnerImage() {
    final url = _profileText(_partnerProfile, [
      'profileImageUrl',
      'profileUrl',
      'imageUrl',
      'photoUrl',
      'profileImage',
      'localProfileImagePath',
    ]);
    if (url.isNotEmpty && url.startsWith('http')) {
      return NetworkImage(url);
    }
    if (url.isNotEmpty && File(url).existsSync()) {
      return FileImage(File(url));
    }
    return const AssetImage('assets/images/profile.jpg');
  }

  void _openPartnerProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChatPartnerProfileScreen(
          name: widget.name,
          profile: _partnerProfile,
        ),
      ),
    );
  }

  bool _isMine(Map<String, dynamic> msg) {
    if (msg['isMe'] == true || msg['mine'] == true || msg['isMine'] == true) {
      return true;
    }
    final senderId = msg['senderId'] is int
        ? msg['senderId'] as int
        : int.tryParse(msg['senderId']?.toString() ?? '');
    return _myUserId != null && senderId == _myUserId;
  }

  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text.trim();
    _controller.clear();
    final tempMessage = {
      'content': text,
      'isMe': true,
      'createdAt': DateTime.now().toIso8601String(),
    };
    setState(() {
      _messages.add(tempMessage);
    });
    try {
      final result = await ApiService.sendChatMessage(widget.roomId, text);
      final data = result['data'];
      if (!mounted) return;
      if (data is Map) {
        setState(() {
          final index = _messages.indexOf(tempMessage);
          final sent = Map<String, dynamic>.from(data);
          sent['isMe'] = true;
          if (index >= 0) {
            _messages[index] = sent;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('메시지 전송 실패: $e')));
      }
    }
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _showEndDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 텍스트
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '대화를 그만 하시겠습니까?',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                  height: 1.4,
                ),
              ),
            ),
            // 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE37474),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '대화 이어가기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          final success = await ApiService.leaveChatRoom(
                            widget.roomId,
                          );
                          if (!context.mounted) return;
                          if (success) {
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('채팅방을 나갈 수 없어요')),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFA1ACC3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '끝내기',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Pretendard',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 버튼 Padding 아래에 추가
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await ApiService.reportUser(widget.roomId, '부적절한 내용');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('신고가 접수되었습니다.')),
                        );
                      }
                    },
                    child: const Text(
                      '신고하기',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await ApiService.blockUser(widget.roomId);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('차단되었습니다.')),
                        );
                      }
                    },
                    child: const Text(
                      '차단하기',
                      style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 12,
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

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadPartnerProfile();
    _loadMessages();
  }

  Future<void> _loadMe() async {
    final userId = await ApiService.getCurrentUserId();
    if (mounted) setState(() => _myUserId = userId);
  }

  Future<void> _loadPartnerProfile() async {
    try {
      final data = await ApiService.getChatProfile(widget.roomId);
      if (mounted) setState(() => _partnerProfile = data);
    } catch (e) {}
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ApiService.getChatMessages(widget.roomId);
      setState(() {
        final messages = List<Map<String, dynamic>>.from(
          data['messages'] ?? [],
        );
        messages.sort((a, b) {
          final aSeq = a['sequenceId'] ?? a['messageId'] ?? 0;
          final bSeq = b['sequenceId'] ?? b['messageId'] ?? 0;
          return (aSeq is int ? aSeq : int.tryParse(aSeq.toString()) ?? 0)
              .compareTo(
                bSeq is int ? bSeq : int.tryParse(bSeq.toString()) ?? 0,
              );
        });
        _messages = messages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openPartnerProfile,
          child: Column(
            children: [
              CircleAvatar(radius: 18, backgroundImage: _partnerImage()),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _partnerName(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: Colors.black54,
                  ),
                ],
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _showEndDialog,
            child: const Text(
              '끝내기',
              style: TextStyle(
                color: Color(0xFFE37474),
                fontSize: 14,
                fontFamily: 'Pretendard',
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // 메시지 목록
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 40, bottom: 18),
                      child: GestureDetector(
                        onTap: _openPartnerProfile,
                        child: _PartnerProfileCard(
                          name: widget.name,
                          profile: _partnerProfile,
                          compact: true,
                        ),
                      ),
                    ),
                  );
                }
                final msg = _messages[index - 1];
                return _ChatBubble(
                  text: msg['content'] ?? '',
                  isMe: _isMine(msg),
                );
              },
            ),
          ),

          // 입력창
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFC7C7CC)),
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 3,
                        style: const TextStyle(fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: '메시지',
                          hintStyle: TextStyle(
                            color: Color(0xFFC7C7CC),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE37474),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _profileText(
  Map<String, dynamic>? profile,
  List<String> keys, {
  String fallback = '',
}) {
  if (profile == null) return fallback;
  for (final key in keys) {
    final value = profile[key];
    if (value != null && value.toString().trim().isNotEmpty) {
      return value.toString().trim();
    }
  }
  return fallback;
}

String _ageFromBirthDate(dynamic birthDate) {
  final parsed = DateTime.tryParse(birthDate?.toString() ?? '');
  if (parsed == null) return '';
  final today = DateTime.now();
  var age = today.year - parsed.year;
  if (today.month < parsed.month ||
      (today.month == parsed.month && today.day < parsed.day)) {
    age--;
  }
  return '$age세';
}

ImageProvider _profileImageProvider(Map<String, dynamic>? profile) {
  final url = _profileText(profile, [
    'profileImageUrl',
    'profileUrl',
    'imageUrl',
    'photoUrl',
    'profileImage',
    'localProfileImagePath',
  ]);
  if (url.isNotEmpty && url.startsWith('http')) {
    return NetworkImage(url);
  }
  if (url.isNotEmpty && File(url).existsSync()) {
    return FileImage(File(url));
  }
  return const AssetImage('assets/images/profile.jpg');
}

class _PartnerProfileCard extends StatelessWidget {
  final String name;
  final Map<String, dynamic>? profile;
  final bool compact;

  const _PartnerProfileCard({
    required this.name,
    required this.profile,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = _profileText(profile, [
      'realName',
      'name',
      'nickname',
      'partnerNickname',
    ], fallback: name);
    final region = [
      _profileText(profile, ['sido']),
      _profileText(profile, ['sigungu']),
    ].where((e) => e.isNotEmpty).join(' ');
    final age = _profileText(profile, [
      'age',
      'ageGroup',
    ], fallback: _ageFromBirthDate(profile?['birthDate']));
    final job = _profileText(profile, ['job', 'school', 'occupation']);
    final tags = profile?['personalityTags'] is List
        ? (profile!['personalityTags'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .take(3)
              .join(', ')
        : _profileText(profile, ['personalityKeywords', 'personality']);
    final details = [
      if (region.isNotEmpty) '$region 거주',
      if (age.isNotEmpty) age,
      if (job.isNotEmpty) job,
      if (tags.isNotEmpty) tags,
    ];

    return Container(
      width: compact ? 190 : double.infinity,
      height: compact ? 220 : 300,
      constraints: BoxConstraints(maxWidth: compact ? 190 : 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD9D9D9),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C1D3A58),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: compact ? 28 : 38,
            backgroundImage: _profileImageProvider(profile),
          ),
          const Spacer(),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF686868),
              fontSize: 16,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            details.isEmpty ? '프로필 정보가 아직 없어요' : details.join('\n'),
            style: const TextStyle(
              color: Color(0xFF8B8B8B),
              fontSize: 13,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatPartnerProfileScreen extends StatelessWidget {
  final String name;
  final Map<String, dynamic>? profile;

  const _ChatPartnerProfileScreen({required this.name, required this.profile});

  @override
  Widget build(BuildContext context) {
    final displayName = _profileText(profile, [
      'realName',
      'name',
      'nickname',
      'partnerNickname',
    ], fallback: name);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _PartnerProfileCard(
            name: name,
            profile: profile,
            compact: false,
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isMe;

  const _ChatBubble({required this.text, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            const CircleAvatar(
              radius: 16,
              backgroundImage: AssetImage('assets/images/profile.jpg'),
            ),
          if (!isMe) const SizedBox(width: 8),
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFFE37474) : const Color(0xFFE9E9E9),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                fontSize: 15,
                fontFamily: 'Pretendard',
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
