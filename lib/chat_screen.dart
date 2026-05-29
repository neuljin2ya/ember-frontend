import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_handler.dart';
import 'api_service.dart';
import 'websocket_service.dart';

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
  StompUnsubscribe? _wsSub;
  Timer? _couplePollingTimer;
  Map<String, dynamic>? _coupleStatus;
  bool _coupleStatusInitialized = false;

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

  int? _partnerUserId() {
    final profile = _partnerProfile;
    if (profile == null) return null;
    for (final key in [
      'targetUserId',
      'partnerUserId',
      'partnerId',
      'userId',
      'memberId',
      'id',
    ]) {
      final value = profile[key];
      if (value is int) return value;
      final parsed = int.tryParse(value?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<void> _reportOrBlockPartner({required bool block}) async {
    final messenger = ScaffoldMessenger.of(context);
    final targetUserId = _partnerUserId();
    if (targetUserId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('상대방 정보를 불러온 뒤 다시 시도해주세요.')),
      );
      return;
    }

    try {
      final success = block
          ? await ApiService.blockUser(targetUserId)
          : await ApiService.reportUser(targetUserId, '부적절한 내용');
      if (!mounted) return;
      if (success) {
        if (block) Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text(block ? '차단되었습니다.' : '신고가 접수되었습니다.')),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(block ? '차단할 수 없어요.' : '신고를 접수할 수 없어요.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('처리 실패: $e')));
    }
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

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    final text = _controller.text.trim();
    _controller.clear();

    // WebSocket으로 전송 (서버가 브로드캐스트하면 구독에서 수신)
    final ws = WebSocketService.instance;
    if (ws.isConnected) {
      ws.send(widget.roomId, text);
    } else {
      // WebSocket 미연결 시 REST fallback
      ApiService.sendChatMessage(widget.roomId, text).catchError((e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('메시지 전송 실패: $e')));
        }
      });
    }

    // 낙관적 UI 업데이트
    setState(() {
      _messages.add({
        'content': text,
        'senderId': _myUserId,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });

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
                      await _reportOrBlockPartner(block: false);
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
                      await _reportOrBlockPartner(block: true);
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

  Future<void> _checkCoupleStatus() async {
    try {
      final status = await ApiService.getCoupleStatus(widget.roomId);
      if (!mounted) return;
      final wasCouple = _coupleStatus?['isCouple'] == true;
      setState(() => _coupleStatus = status);
      // 첫 로드 시 이미 커플이면 축하 화면 안 띄움, 세션 중 전환 시만 표시
      if (!_coupleStatusInitialized) {
        _coupleStatusInitialized = true;
        if (status['isCouple'] == true) _couplePollingTimer?.cancel();
        return;
      }
      if (status['isCouple'] == true && !wasCouple) {
        _couplePollingTimer?.cancel();
        _showCoupleCelebration();
      }
    } catch (_) {}
  }

  bool get _showCoupleRequestBanner {
    final s = _coupleStatus;
    if (s == null) return false;
    return s['hasPendingRequest'] == true && s['isRequester'] != true;
  }

  Future<void> _handleCoupleHeart() async {
    // 먼저 커플 요청 시도 — 상대가 이미 보냈으면 에러 → 수락/거절 표시
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('커플 신청', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 20)),
        content: Text('${widget.name}님에게 커플 신청을 보낼까요?', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Pretendard', fontSize: 14, height: 1.5, color: Color(0xFF6B7280))),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소', style: TextStyle(color: Color(0xFF9CA3AF)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE37474), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: const Text('신청하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await ApiService.postCoupleRequest(widget.roomId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('커플 신청을 보냈어요!')));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      // 이미 요청이 존재 → 상대가 보낸 것일 수 있음 → 수락/거절 표시
      if (msg.contains('이미') || msg.contains('CR003') || msg.contains('존재')) {
        _showCoupleResponseDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('신청 실패: $e')));
      }
    }
  }

  Future<void> _showCoupleRequestDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('커플 신청', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 20)),
        content: Text('${widget.name}님에게 커플 신청을 보낼까요?\n상대가 수락하면 커플이 됩니다.', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Pretendard', fontSize: 14, height: 1.5, color: Color(0xFF6B7280))),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소', style: TextStyle(color: Color(0xFF9CA3AF)))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'request'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE37474), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: const Text('신청하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result == 'request') {
      try {
        await ApiService.postCoupleRequest(widget.roomId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('커플 신청을 보냈어요!')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('신청 실패: $e')));
      }
    }
  }

  Future<void> _showCoupleResponseDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.favorite, color: Color(0xFFE37474), size: 48),
        title: const Text('커플 요청이 왔어요!', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, fontSize: 20)),
        content: Text('${widget.name}님이 커플 신청을 보냈어요.\n수락하시겠어요?', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Pretendard', fontSize: 14, height: 1.5, color: Color(0xFF6B7280))),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'reject'),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('거절하기', style: TextStyle(color: Color(0xFF9CA3AF))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, 'accept'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE37474), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
            child: const Text('수락하기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      if (result == 'accept') {
        await ApiService.acceptCouple(widget.roomId);
        if (mounted) _showCoupleCelebration();
      } else {
        await ApiService.rejectCouple(widget.roomId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('커플 요청을 거절했어요.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('처리 실패: $e')));
    }
  }

  void _showCoupleCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              const Text('축하합니다!', style: TextStyle(fontSize: 24, fontFamily: 'Pretendard', fontWeight: FontWeight.w700, color: Color(0xFFE37474))),
              const SizedBox(height: 8),
              Text('${widget.name}님과\n커플이 되었어요!', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontFamily: 'Pretendard', height: 1.5, color: Color(0xFF391713))),
              const SizedBox(height: 8),
              const Text('서로의 진심이 통했네요.\n앞으로도 좋은 시간 보내세요!', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontFamily: 'Pretendard', color: Color(0xFF9CA3AF), height: 1.5)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE37474), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('확인', style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Pretendard', fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSafetyAction(String action) async {
    final targetId = _partnerUserId();
    if (targetId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('상대방 정보를 불러올 수 없어요.')));
      return;
    }
    if (action == 'report') {
      final reason = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('신고하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '신고 사유를 입력해주세요 (10자 이상)', border: OutlineInputBorder()),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('신고', style: TextStyle(color: Color(0xFFEF4444)))),
            ],
          );
        },
      );
      if (reason == null || reason.isEmpty) return;
      if (reason.length < 10) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고 사유는 10자 이상 입력해주세요.')));
        return;
      }
      final success = await ApiService.reportUser(targetId, reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '신고가 접수되었어요.' : '신고를 접수할 수 없어요.')));
    } else if (action == 'block') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('차단하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          content: const Text('이 사용자를 차단하면 매칭, 교환일기, 채팅이 모두 종료됩니다. 차단하시겠어요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('차단', style: TextStyle(color: Color(0xFFEF4444)))),
          ],
        ),
      );
      if (confirm != true) return;
      final success = await ApiService.blockUser(targetId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '사용자를 차단했어요.' : '차단할 수 없어요.')));
        if (success) Navigator.pop(context);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMe();
    _loadPartnerProfile();
    _loadMessages();
    _connectWebSocket();
    _checkCoupleStatus();
    _couplePollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkCoupleStatus());
  }

  Future<void> _connectWebSocket() async {
    final ws = WebSocketService.instance;
    await ws.connect();
    _wsSub = ws.subscribe(widget.roomId, (msg) {
      // 자기가 보낸 메시지는 낙관적 UI로 이미 추가했으므로 스킵
      final senderId = msg['senderId'];
      if (senderId == _myUserId) return;
      if (!mounted) return;
      setState(() => _messages.add(msg));
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    });
    ws.sendRead(widget.roomId);
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
    _couplePollingTimer?.cancel();
    _wsSub?.call();
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
          IconButton(
            icon: const Icon(Icons.favorite_border, color: Color(0xFFE37474)),
            onPressed: _handleCoupleHeart,
            tooltip: '커플',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF9CA3AF)),
            onSelected: _handleSafetyAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('신고하기', style: TextStyle(color: Color(0xFFEF4444)))),
              PopupMenuItem(value: 'block', child: Text('차단하기', style: TextStyle(color: Color(0xFFEF4444)))),
            ],
          ),
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

          // 커플 요청 배너
          if (_showCoupleRequestBanner)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFF1F0), Color(0xFFFFE8EC)]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFCDD2)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.favorite, color: Color(0xFFE37474), size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '${_coupleStatus?['requesterNickname'] ?? '상대방'}님이\n커플 요청을 보냈어요!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard', fontWeight: FontWeight.w600, color: Color(0xFF391713), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            try {
                              await ApiService.rejectCouple(widget.roomId);
                              if (mounted) {
                                setState(() => _coupleStatus = null);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('커플 요청을 거절했어요.')));
                              }
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('거절 실패: $e')));
                            }
                          },
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: const Text('거절', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontFamily: 'Pretendard', fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await ApiService.acceptCouple(widget.roomId);
                              if (mounted) {
                                setState(() => _coupleStatus = {'isCouple': true});
                                _couplePollingTimer?.cancel();
                                _showCoupleCelebration();
                              }
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('수락 실패: $e')));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE37474), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12)),
                          child: const Text('수락', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Pretendard', fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
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
