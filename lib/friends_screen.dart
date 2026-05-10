import 'package:flutter/material.dart';
import 'bottom_nav_bar.dart';
import 'chat_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int _currentIndex = 1;
  bool _isDiaryTab = true;

  final List<Map<String, dynamic>> _friends = [
    {
      'diary': '교환일기',
      'title': '사람 덕분에 웃음이 많았던 하루 일기',
      'remaining': '2회 남음',
    },
    {
      'diary': '교환일기',
      'title': '직장에서 힘든 하루 일기',
      'remaining': '1회 남음',
    },
    {
      'diary': '교환일기',
      'title': '가족과 피크닉 간 하루 일기',
      'remaining': '2회 남음',
    },
    {
      'diary': '교환일기',
      'title': '친구와 롯데월드 간 하루 일기',
      'remaining': '3회 남음',
    },
  ];

  final List<Map<String, dynamic>> _messages = [
    {
      'name': '김유진',
      'preview': '새 메시지 1개',
      'isNew': true,
    },
    {
      'name': '김정서',
      'preview': '새메세지 2개',
      'isNew': true,
    },
    {
      'name': '류하진',
      'preview': '회원님 : 내일 시간 되시나요?',
      'isNew': false,
    },
    {
      'name': '오이서',
      'preview': '회원님 : 안녕하세요!',
      'isNew': false,
    },
  ];

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

            // 흰 카드
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    // 탭 버튼
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        children: [
                          _TabButton(
                            label: 'Diary',
                            isSelected: _isDiaryTab,
                            onTap: () => setState(() => _isDiaryTab = true),
                          ),
                          const SizedBox(width: 12),
                          _TabButton(
                            label: 'Message',
                            isSelected: !_isDiaryTab,
                            onTap: () => setState(() => _isDiaryTab = false),
                          ),
                        ],
                      ),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(color: Color(0xFFE37474), thickness: 1),
                    ),

                    // 탭 내용
                    Expanded(
                      child: _isDiaryTab
                          ? _buildDiaryList()
                          : _buildMessageList(),
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

  Widget _buildDiaryList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _friends.length,
      separatorBuilder: (_, __) =>
      const Divider(color: Color(0xFFE37474), thickness: 1),
      itemBuilder: (context, index) {
        final friend = _friends[index];
        return _FriendItem(
          diary: friend['diary'],
          title: friend['title'],
          remaining: friend['remaining'],
          onExchange: () {},
          onEnd: () {
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
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA1ACC3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        '끝내기',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _messages.length,
      separatorBuilder: (_, __) =>
      const Divider(color: Color(0xFFE37474), thickness: 1),
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _MessageItem(
          name: msg['name'],
          preview: msg['preview'],
          isNew: msg['isNew'],
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatScreen(name: msg['name'], roomId: msg['roomId'] ?? 0),
            ));
          },
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
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
          border: isSelected ? Border.all(color: const Color(0xFFE95322)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFE37474),
            fontSize: 17,
            fontFamily: 'Pretendard',
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _FriendItem extends StatelessWidget {
  final String diary;
  final String title;
  final String remaining;
  final VoidCallback onExchange;
  final VoidCallback onEnd;

  const _FriendItem({
    required this.diary,
    required this.title,
    required this.remaining,
    required this.onExchange,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
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
                  ],
                ),
                const SizedBox(height: 4),
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFF391713),
                        fontSize: 13,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w300),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onExchange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE37474),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: const Color(0xFFE95322)),
                        ),
                        child: const Text('교환일기 남기기',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onEnd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEFE7),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text('끝내기',
                            style: TextStyle(
                                color: Color(0xFFE37474),
                                fontSize: 12,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w400)),
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
                          fontFamily: 'Pretendard',
                          fontWeight: isNew ? FontWeight.w500 : FontWeight.w300),
                      overflow: TextOverflow.ellipsis),
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