import 'package:flutter/material.dart';
import 'bottom_nav_bar.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'diary_detail_screen.dart';
import 'api_service.dart';
import 'exchange_diary_write_screen.dart';
import 'exchange_diary_detail_screen.dart';


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
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
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
  bool _isRecent = true;
  List<Map<String, dynamic>> _diaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDiaries();
  }

  Future<void> _loadDiaries() async {
    try {
      final data = await ApiService.exploreDiaries(isRecent: _isRecent);
      setState(() {
        _diaries = List<Map<String, dynamic>>.from(data['diaries'] ?? []);
        _isLoading = false;
      });
    } catch (e) {
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
              child: Text('Diary',
                  style: TextStyle(
                    color: Color(0xFFE37474),
                    fontSize: 30,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w700,
                  )),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFE37474),
                        borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
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
                        borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                    ),
                  ),

                  // 최근 일기 탭
                  Positioned(
                    top: 55,
                    left: 130,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isRecent = true;
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
                              color: _isRecent
                                  ? const Color(0xFFE37474)
                                  : Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('최근 일기',
                              style: TextStyle(
                                  color: Color(0xFF391713),
                                  fontSize: 12,
                                  fontFamily: 'Pretendard')),
                        ],
                      ),
                    ),
                  ),

                  // 인기 일기 탭
                  Positioned(
                    top: 55,
                    left: 130 + tabSize + 36,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isRecent = false;
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
                              color: _isRecent
                                  ? Colors.white
                                  : const Color(0xFFE37474),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text('인기 일기',
                              style: TextStyle(
                                  color: Color(0xFF391713),
                                  fontSize: 12,
                                  fontFamily: 'Pretendard')),
                        ],
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
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFFE37474)))
                        : _diaries.isEmpty
                        ? const Center(
                        child: Text('일기가 없어요',
                            style: TextStyle(
                                color: Color(0xFF391713),
                                fontFamily: 'Pretendard')))
                        : ListView.builder(
                      padding:
                      const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: _diaries.length,
                      itemBuilder: (context, index) {
                        final diary = _diaries[index];
                        return _DiaryItem(
                          title: diary['title'] ?? '제목 없음',
                          time: diary['createdAt'] ?? '',
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DiaryDetailScreen(
                                    title: diary['title'] ?? '',
                                    time: diary['createdAt'] ?? '',
                                    diaryId: diary['id'] ?? 0,
                                  ),
                                ));
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

  const _DiaryItem(
      {required this.title, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFF391713),
                        fontSize: 18,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(time,
                    style: const TextStyle(
                        color: Color(0xFF391713),
                        fontSize: 12,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w300)),
              ],
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
  bool _isDiaryTab = true;

  List<Map<String, dynamic>> _friends = [];
  bool _isLoadingFriends = true;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingMessages = true;

  @override
  void initState() {
    super.initState();
    _loadExchangeRooms();
  }

  Future<void> _loadExchangeRooms() async {
    try {
      final data = await ApiService.getExchangeRooms();
      setState(() {
        _friends = List<Map<String, dynamic>>.from(data['rooms'] ?? []);
        _isLoadingFriends = false;
      });
    } catch (e) {
      setState(() => _isLoadingFriends = false);
    }

    try {
      final data = await ApiService.getChatRooms();
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data['rooms'] ?? []);
        _isLoadingMessages = false;
      });
    } catch (e) {
      setState(() => _isLoadingMessages = false);
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
              child: Text('Friends',
                  style: TextStyle(
                      color: Color(0xFFF8F8F8),
                      fontSize: 28,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700)),
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
                              isSelected: _isDiaryTab,
                              onTap: () =>
                                  setState(() => _isDiaryTab = true)),
                          const SizedBox(width: 12),
                          _FriendTabButton(
                              label: 'Message',
                              isSelected: !_isDiaryTab,
                              onTap: () =>
                                  setState(() => _isDiaryTab = false)),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(color: Color(0xFFE37474), thickness: 1),
                    ),
                    Expanded(
                      child: _isDiaryTab
                          ? ListView.separated(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _isLoadingFriends ? 0 : _friends.length,
                        separatorBuilder: (_, __) => const Divider(
                            color: Color(0xFFE37474), thickness: 1),
                        itemBuilder: (context, index) {
                          final f = _friends[index];
                          return _FriendItem(
                              diary: '교환일기',
                              title: f['lastDiaryTitle'] ?? '제목 없음',
                              remaining: '${f['remainingTurns'] ?? 0}회 남음',
                              onExchange: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => ExchangeDiaryWriteScreen(
                                    roomId: f['roomId'] ?? 0,
                                    partnerNickname: f['partnerNickname'] ?? '',
                                  ),
                                ));
                              },
                              onEnd: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(20)),
                                    title: const Text(
                                        '교환일기를 종료하시겠습니까?',
                                        style: TextStyle(
                                            color: Color(0xFF111827),
                                            fontSize: 16,
                                            fontFamily: 'Pretendard')),
                                    actions: [
                                      SizedBox(
                                        width: double.infinity,
                                        height: 52,
                                        child: ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                              const Color(0xFFA1ACC3),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(8))),
                                          child: const Text('끝내기',
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              });
                        },
                      )
                          : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _isLoadingMessages ? 0 : _messages.length,
                        separatorBuilder: (_, __) => const Divider(
                            color: Color(0xFFE37474), thickness: 1),
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          return _MessageItem(
                            name: msg['partnerNickname'] ?? '알 수 없음',
                            preview: msg['lastMessage'] ?? '',
                            isNew: msg['hasUnread'] ?? false,
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  name: msg['partnerNickname'] ?? '',
                                  roomId: msg['roomId'] ?? 0,
                                ),
                              ));
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
  const _FriendTabButton(
      {required this.label,
        required this.isSelected,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE37474)
              : const Color(0xFFFFEFE7),
          borderRadius: BorderRadius.circular(38),
          border:
          isSelected ? Border.all(color: const Color(0xFFE95322)) : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFE37474),
                fontSize: 17,
                fontFamily: 'Pretendard')),
      ),
    );
  }
}

class _FriendItem extends StatelessWidget {
  final String diary, title, remaining;
  final VoidCallback onExchange, onEnd;
  const _FriendItem(
      {required this.diary,
        required this.title,
        required this.remaining,
        required this.onExchange,
        required this.onEnd});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                      fit: BoxFit.cover))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(diary,
                              style: const TextStyle(
                                  color: Color(0xFF391713),
                                  fontSize: 18,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w500)),
                          Text(remaining,
                              style: const TextStyle(
                                  color: Color(0xFFE37474),
                                  fontSize: 16,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w500)),
                        ]),
                    const SizedBox(height: 4),
                    Text(title,
                        style: const TextStyle(
                            color: Color(0xFF391713),
                            fontSize: 13,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w300),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(children: [
                      GestureDetector(
                          onTap: onExchange,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFE37474),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(
                                      color: const Color(0xFFE95322))),
                              child: const Text('교환일기 남기기',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontFamily: 'Pretendard')))),
                      const SizedBox(width: 8),
                      GestureDetector(
                          onTap: onEnd,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFFEFE7),
                                  borderRadius: BorderRadius.circular(100)),
                              child: const Text('끝내기',
                                  style: TextStyle(
                                      color: Color(0xFFE37474),
                                      fontSize: 12,
                                      fontFamily: 'Pretendard')))),
                    ]),
                  ])),
        ],
      ),
    );
  }
}

class _MessageItem extends StatelessWidget {
  final String name, preview;
  final bool isNew;
  final VoidCallback onTap;
  const _MessageItem(
      {required this.name,
        required this.preview,
        required this.isNew,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  image: const DecorationImage(
                      image: AssetImage('assets/images/profile.jpg'),
                      fit: BoxFit.cover))),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Color(0xFF391713),
                            fontSize: 18,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(preview,
                        style: TextStyle(
                            color: isNew
                                ? const Color(0xFFE37474)
                                : const Color(0xFF391713),
                            fontSize: 13,
                            fontFamily: 'Pretendard'),
                        overflow: TextOverflow.ellipsis),
                  ])),
          const Icon(Icons.chevron_right, color: Color(0xFF391713)),
        ]),
      ),
    );
  }
}