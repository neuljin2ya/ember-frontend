import 'package:flutter/material.dart';
import 'bottom_nav_bar.dart';
import 'diary_detail_screen.dart';
import 'api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRecent = true;

  List<Map<String, dynamic>> _diaries = [];
  bool _isLoading = true;
  int _currentIndex = 0;

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
    const double tabR = tabSize / 2;
    // 탭 원 중심 x 좌표 (화면 기준)
    const double tab1CenterX = 130 + tabR;
    const double tab2CenterX = 130 + tabSize + 36 + tabR;

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
                  // 빨간 배경
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFE37474),
                        borderRadius:
                        BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                    ),
                  ),

                  // 흰 카드 (볼록한 부분에 탭 원이 들어감)
                  // 흰 카드
                  Positioned(top: 100, left: 0, right: 0, bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                    ),
                  ),


                  // 탭 원 (흰 카드의 볼록한 부분 안에 위치)
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
                                  : const Color(0xFFFFFFFF),
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
                              color: !_isRecent
                                  ? const Color(0xFFE37474)
                                  : const Color(0xFFFFFFFF),
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
                    top: 170,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: _isLoading ? 0 : _diaries.length,
                      itemBuilder: (context, index) {
                        final diary = _diaries[index];
                        return _DiaryItem(
                          title: diary['title'] ?? '제목 없음',
                          time: diary['createdAt'] ?? '',
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(
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

      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _BumpCardPainter extends CustomPainter {
  final bool isRecent;
  final double tab1CenterX;
  final double tab2CenterX;
  final double tabR;

  _BumpCardPainter({
    required this.isRecent,
    required this.tab1CenterX,
    required this.tab2CenterX,
    required this.tabR,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final double cardR = 30.0;
    final double cx = isRecent ? tab1CenterX : tab2CenterX;
    final double topY = tabR; // 카드 기본 상단
    final double bumpTopY = 0; // 볼록 최고점

    final path = Path();

    // 왼쪽 위 둥근 모서리
    path.moveTo(0, topY + cardR);
    path.quadraticBezierTo(0, topY, cardR, topY);

    // 볼록 부분 왼쪽
    path.lineTo(cx - tabR, topY);
    // 왼쪽 전환 곡선
    path.quadraticBezierTo(cx - tabR, bumpTopY, cx - tabR + 10, bumpTopY);
    // 볼록 원호 (위로 볼록 = clockwise false)
    path.arcToPoint(
      Offset(cx + tabR - 10, bumpTopY),
      radius: Radius.circular(tabR),
      clockwise: false,
    );
    // 오른쪽 전환 곡선
    path.quadraticBezierTo(cx + tabR, bumpTopY, cx + tabR, topY);

    // 오른쪽 위 둥근 모서리
    path.lineTo(size.width - cardR, topY);
    path.quadraticBezierTo(size.width, topY, size.width, topY + cardR);

    // 오른쪽 아래, 왼쪽 아래
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BumpCardPainter old) => old.isRecent != isRecent;
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