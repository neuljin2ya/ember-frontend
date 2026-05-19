import 'package:flutter/material.dart';
import 'bottom_nav_bar.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'diary_detail_screen.dart';
import 'api_service.dart';
import 'exchange_diary_write_screen.dart';
import 'exchange_room_detail_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _HomeTab(),
    const _FriendsTab(),
    const _EmptyTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    return const _HomeBody();
  }
}

class _FriendsTab extends StatelessWidget {
  const _FriendsTab();

  @override
  Widget build(BuildContext context) {
    return const _FriendsBody();
  }
}

class _EmptyTab extends StatelessWidget {
  const _EmptyTab();

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}

// ────────────────────────────────────────────
// Home Body
// ────────────────────────────────────────────

class _HomeBody extends StatefulWidget {
  const _HomeBody();

  @override
  State<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends State<_HomeBody> {
  int _tabIndex = 0; // 0: 최근, 1: 추천, 2: 내 일기
  List<Map<String, dynamic>> _diaries = [];
  bool _isLoading = true;
  bool _filterRegion = false;
  bool _filterAge = false;
  String? _mySido;
  String? _myAgeGroup;

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
    _loadDiaries();
  }

  Future<void> _loadMyProfile() async {
    try {
      final data = await ApiService.getMyProfile();
      setState(() {
        _mySido = data['sido'];
        _myAgeGroup = data['ageGroup'];
      });
    } catch (e) {}
  }

  Future<void> _loadDiaries() async {
    try {
      Map<String, dynamic> data;
      if (_tabIndex == 0) {
        data = await ApiService.exploreDiaries(
          isRecent: true,
          sido: _filterRegion ? _mySido : null,
          ageGroup: _filterAge ? _myAgeGroup : null,
        );
        final diaries = data['data']?['diaries'] ?? [];
        print('explore 응답: ${diaries.isNotEmpty ? diaries.first : null}');
        setState(() {
          _diaries = List<Map<String, dynamic>>.from(diaries);
          _isLoading = false;
        });
      } else if (_tabIndex == 1) {
        data = await ApiService.exploreDiaries(
          isRecent: false,
          sido: _filterRegion ? _mySido : null,
          ageGroup: _filterAge ? _myAgeGroup : null,
        );
        setState(() {
          _diaries = List<Map<String, dynamic>>.from(
            data['data']?['diaries'] ?? [],
          );
          _isLoading = false;
        });
      } else {
        data = await ApiService.getMyDiaries();
        setState(() {
          _diaries = List<Map<String, dynamic>>.from(
            data['data']?['diaries'] ?? [],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      print('일기 로드 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const double tabSize = 90.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Diary',
                style: TextStyle(
                  color: Color(0xFFE37474),
                  fontSize: 30,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFE37474),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(30),
                        ),
                      ),
                    ),
                  ),

                  // 최근 일기 탭
                  Positioned(
                    top: 55,
                    left: 20,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _tabIndex = 0;
                          _isLoading = true;
                        });
                        _loadDiaries();
                      },
                      child: Column(
                        children: [
                          Container(
                            width: tabSize,
                            height: tabSize,
                            decoration: BoxDecoration(
                              color: _tabIndex == 0
                                  ? const Color(0xFFE37474)
                                  : Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '최근 일기',
                            style: TextStyle(
                              color: Color(0xFF391713),
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 55,
                    left: 20 + tabSize + 20,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _tabIndex = 1;
                          _isLoading = true;
                        });
                        _loadDiaries();
                      },
                      child: Column(
                        children: [
                          Container(
                            width: tabSize,
                            height: tabSize,
                            decoration: BoxDecoration(
                              color: _tabIndex == 1
                                  ? const Color(0xFFE37474)
                                  : Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '추천 일기',
                            style: TextStyle(
                              color: Color(0xFF391713),
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 55,
                    left: 20 + (tabSize + 20) * 2,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _tabIndex = 2;
                          _isLoading = true;
                        });
                        _loadDiaries();
                      },
                      child: Column(
                        children: [
                          Container(
                            width: tabSize,
                            height: tabSize,
                            decoration: BoxDecoration(
                              color: _tabIndex == 2
                                  ? const Color(0xFFE37474)
                                  : Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '내 일기',
                            style: TextStyle(
                              color: Color(0xFF391713),
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 필터 버튼
                  Positioned(
                    top: 110,
                    right: 20,
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (_) => StatefulBuilder(
                            builder: (context, setModalState) {
                              return Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '지역 필터링',
                                          style: TextStyle(
                                            color: Color(0xFFE37474),
                                            fontSize: 16,
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Switch(
                                          value: _filterRegion,
                                          activeColor: const Color(0xFFE37474),
                                          onChanged: (v) {
                                            setModalState(() {});
                                            setState(() {
                                              _filterRegion = v;
                                              _isLoading = true;
                                            });
                                            _loadDiaries();
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          '나이대 필터링',
                                          style: TextStyle(
                                            color: Color(0xFFE37474),
                                            fontSize: 16,
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Switch(
                                          value: _filterAge,
                                          activeColor: const Color(0xFFE37474),
                                          onChanged: (v) {
                                            setModalState(() {});
                                            setState(() {
                                              _filterAge = v;
                                              _isLoading = true;
                                            });
                                            _loadDiaries();
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 8),
                          ],
                        ),
                        child: const Icon(
                          Icons.tune,
                          color: Color(0xFFE37474),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // 리스트
                  Positioned(
                    top: 190,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFE37474),
                            ),
                          )
                        : _diaries.isEmpty
                        ? const Center(
                            child: Text(
                              '일기가 없어요',
                              style: TextStyle(
                                color: Color(0xFF391713),
                                fontFamily: 'Pretendard',
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                            itemCount: _diaries.length,
                            itemBuilder: (context, index) {
                              final diary = _diaries[index];
                              return _DiaryItem(
                                title: () {
                                  if (_tabIndex == 2) {
                                    return diary['summary'] ??
                                        diary['contentPreview'] ??
                                        '내용 없음';
                                  }
                                  final content =
                                      diary['previewContent'] as String?;
                                  if (content != null) {
                                    return content.length > 30
                                        ? '${content.substring(0, 30)}...'
                                        : content;
                                  }
                                  return '내용 없음';
                                }(),
                                time: _tabIndex == 2
                                    ? diary['createdAt']?.toString().substring(
                                            0,
                                            10,
                                          ) ??
                                          ''
                                    : '${diary['ageGroupLabel'] ?? ''} · ${diary['sido'] ?? ''} ${diary['sigungu'] ?? ''}',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DiaryDetailScreen(
                                        title:
                                            diary['previewContent'] ??
                                            diary['summary'] ??
                                            diary['contentPreview'] ??
                                            '',
                                        time:
                                            diary['nickname'] ??
                                            diary['createdAt'] ??
                                            '',
                                        diaryId:
                                            diary['diaryId'] ??
                                            diary['id'] ??
                                            0,
                                        showDecisionButtons: _tabIndex != 2,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
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

class _DiaryItem extends StatelessWidget {
  final String title;
  final String time;
  final VoidCallback onTap;

  const _DiaryItem({
    required this.title,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF391713),
                      fontSize: 18,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: const TextStyle(
                      color: Color(0xFF391713),
                      fontSize: 12,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w300,
                    ),
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

// ────────────────────────────────────────────
// Friends Body
// ────────────────────────────────────────────

class _FriendsBody extends StatefulWidget {
  const _FriendsBody();

  @override
  State<_FriendsBody> createState() => _FriendsBodyState();
}

class _FriendsBodyState extends State<_FriendsBody> {
  int _tabIndex = 0; // 0: Diary, 1: Message, 2: Request

  List<Map<String, dynamic>> _friends = [];
  bool _isLoadingFriends = true;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingMessages = true;

  List<Map<String, dynamic>> _requests = [];
  bool _isLoadingRequests = true;

  @override
  void initState() {
    super.initState();
    _loadExchangeRooms();
  }

  Future<void> _loadExchangeRooms() async {
    try {
      final data = await ApiService.getExchangeRooms();
      setState(() {
        _friends = List<Map<String, dynamic>>.from(
          data['data']?['rooms'] ?? [],
        );
        _isLoadingFriends = false;
      });
    } catch (e) {
      setState(() => _isLoadingFriends = false);
    }

    try {
      final data = await ApiService.getChatRooms();
      setState(() {
        _messages = List<Map<String, dynamic>>.from(
          data['data']?['chatRooms'] ?? [],
        );
        _isLoadingMessages = false;
      });
    } catch (e) {
      setState(() => _isLoadingMessages = false);
    }

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
        _isLoadingRequests = false;
      });
    } catch (e) {
      setState(() => _isLoadingRequests = false);
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
                          _FriendTabButton(
                            label: 'Diary',
                            isSelected: _tabIndex == 0,
                            onTap: () => setState(() => _tabIndex = 0),
                          ),
                          const SizedBox(width: 12),
                          _FriendTabButton(
                            label: 'Message',
                            isSelected: _tabIndex == 1,
                            onTap: () => setState(() => _tabIndex = 1),
                          ),
                          const SizedBox(width: 12),
                          _FriendTabButton(
                            label: 'Request',
                            isSelected: _tabIndex == 2,
                            onTap: () => setState(() => _tabIndex = 2),
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
                          ? ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: _isLoadingFriends
                                  ? 0
                                  : _friends.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFFE37474),
                                thickness: 1,
                              ),
                              itemBuilder: (context, index) {
                                final f = _friends[index];
                                final roomId = f['roomId'] is int
                                    ? f['roomId'] as int
                                    : int.tryParse(
                                            f['roomId']?.toString() ?? '',
                                          ) ??
                                          0;
                                final isMyTurn = f['isMyTurn'] == true;
                                return _FriendItem(
                                  diary: '교환일기',
                                  title: f['partnerNickname'] ?? '',
                                  remaining: '${f['currentTurn'] ?? 0}턴',
                                  isMyTurn: isMyTurn,
                                  onTap: () {
                                    if (roomId == 0) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ExchangeRoomDetailScreen(
                                              roomId: roomId,
                                              partnerNickname:
                                                  f['partnerNickname'] ?? '',
                                            ),
                                      ),
                                    ).then((_) => _loadExchangeRooms());
                                  },
                                  onExchange: () {
                                    if (!isMyTurn || roomId == 0) return;
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ExchangeDiaryWriteScreen(
                                              roomId: roomId,
                                              partnerNickname:
                                                  f['partnerNickname'] ?? '',
                                            ),
                                      ),
                                    ).then((_) => _loadExchangeRooms());
                                  },
                                  onEnd: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        title: const Text(
                                          '교환일기를 종료하시겠습니까?',
                                          style: TextStyle(
                                            color: Color(0xFF111827),
                                            fontSize: 16,
                                            fontFamily: 'Pretendard',
                                          ),
                                        ),
                                        actions: [
                                          SizedBox(
                                            width: double.infinity,
                                            height: 52,
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFA1ACC3,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: const Text(
                                                '끝내기',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            )
                          : _tabIndex == 1
                          ? ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: _isLoadingMessages
                                  ? 0
                                  : _messages.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFFE37474),
                                thickness: 1,
                              ),
                              itemBuilder: (context, index) {
                                final msg = _messages[index];
                                return _MessageItem(
                                  name: msg['partnerNickname'] ?? '알 수 없음',
                                  preview: msg['lastMessage'] ?? '',
                                  isNew: (msg['unreadCount'] ?? 0) > 0,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          name: msg['partnerNickname'] ?? '',
                                          roomId: msg['chatRoomId'] ?? 0,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              itemCount: _isLoadingRequests
                                  ? 0
                                  : _requests.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFFE37474),
                                thickness: 1,
                              ),
                              itemBuilder: (context, index) {
                                final request = _requests[index];
                                return _MessageItem(
                                  name:
                                      request['fromUserNickname'] ??
                                      request['nickname'] ??
                                      request['senderNickname'] ??
                                      '알 수 없음',
                                  preview:
                                      request['diaryPreview'] ??
                                      request['preview'] ??
                                      request['diaryTitle'] ??
                                      '',
                                  isNew: true,
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DiaryDetailScreen(
                                          title:
                                              request['diaryPreview'] ??
                                              request['preview'] ??
                                              '',
                                          time:
                                              request['fromUserAgeGroup'] ??
                                              request['ageGroup'] ??
                                              '',
                                          diaryId:
                                              request['diaryId'] ??
                                              request['id'] ??
                                              0,
                                          showBottomNav: false,
                                          showMatchingButtons: true,
                                          matchingId:
                                              request['matchingId'] ??
                                              request['id'] ??
                                              0,
                                        ),
                                      ),
                                    ).then((_) => _loadExchangeRooms());
                                  },
                                );
                              },
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

class _FriendTabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _FriendTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE37474) : const Color(0xFFFFEFE7),
          borderRadius: BorderRadius.circular(38),
          border: isSelected
              ? Border.all(color: const Color(0xFFE95322))
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFE37474),
            fontSize: 17,
            fontFamily: 'Pretendard',
          ),
        ),
      ),
    );
  }
}

class _FriendItem extends StatelessWidget {
  final String diary, title, remaining;
  final bool isMyTurn;
  final VoidCallback onTap, onExchange, onEnd;
  const _FriendItem({
    required this.diary,
    required this.title,
    required this.remaining,
    required this.isMyTurn,
    required this.onTap,
    required this.onExchange,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
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
                        diary,
                        style: const TextStyle(
                          color: Color(0xFF391713),
                          fontSize: 18,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        remaining,
                        style: const TextStyle(
                          color: Color(0xFFE37474),
                          fontSize: 16,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF391713),
                      fontSize: 13,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w300,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: isMyTurn ? onExchange : null,
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
                            border: Border.all(color: const Color(0xFFE95322)),
                          ),
                          child: Text(
                            isMyTurn ? '교환일기 남기기' : '대기 중',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Pretendard',
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
      ),
    );
  }
}

class _MessageItem extends StatelessWidget {
  final String name, preview;
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
