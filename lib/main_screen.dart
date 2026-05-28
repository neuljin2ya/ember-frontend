import 'package:flutter/material.dart';
import 'bottom_nav_bar.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'diary_detail_screen.dart';
import 'api_service.dart';
import 'diary_screen.dart';
import 'exchange_diary_write_screen.dart';
import 'exchange_room_detail_screen.dart';
import 'notification_screen.dart';
import 'ai_report_screen.dart';
import 'text_utils.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final int initialFriendsTab;

  const MainScreen({
    super.key,
    this.initialIndex = 0,
    this.initialFriendsTab = 0,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const _HomeTab(),
      _FriendsTab(initialTab: widget.initialFriendsTab),
      const _EmptyTab(),
    ];
    _currentIndex = widget.initialIndex.clamp(0, _screens.length - 1).toInt();
  }

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
  final int initialTab;

  const _FriendsTab({this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return _FriendsBody(initialTab: initialTab);
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
  String _guidanceMessage = '';
  bool _hasLoadError = false;
  bool _filterRegion = false;
  bool _filterAge = false;
  String? _mySido;
  String? _mySigungu;
  String? _myAgeGroup;
  String? _selectedSido;

  static const List<String> _sidoOptions = [
    '서울특별시',
    '부산광역시',
    '대구광역시',
    '인천광역시',
    '광주광역시',
    '대전광역시',
    '울산광역시',
    '세종특별자치시',
    '경기도',
    '강원도',
    '충청북도',
    '충청남도',
    '전라북도',
    '전라남도',
    '경상북도',
    '경상남도',
    '제주특별자치도',
  ];

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
        _mySido = data['sido']?.toString();
        _mySigungu = data['sigungu']?.toString();
        _myAgeGroup =
            data['ageGroup']?.toString() ??
            _ageGroupFromBirthDate(data['birthDate']);
      });
    } catch (e) {}
  }

  String? _ageGroupFromBirthDate(dynamic birthDate) {
    final parsed = DateTime.tryParse(birthDate?.toString() ?? '');
    if (parsed == null) return null;
    final today = DateTime.now();
    var age = today.year - parsed.year;
    if (today.month < parsed.month ||
        (today.month == parsed.month && today.day < parsed.day)) {
      age--;
    }
    if (age < 20) return '10대';
    return '${(age ~/ 10) * 10}대';
  }

  String? get _activeSido {
    if (!_filterRegion) return null;
    return _selectedSido ?? _mySido;
  }

  String? get _activeSigungu {
    if (!_filterRegion || _selectedSido != null) return null;
    return _mySigungu;
  }

  String get _regionFilterLabel {
    if (!_filterRegion) return '전체 지역';
    if (_selectedSido != null) return _selectedSido!;
    final myRegion = [
      _mySido,
      _mySigungu,
    ].where((value) => value != null && value.trim().isNotEmpty).join(' ');
    return myRegion.isEmpty ? '내 지역' : '내 지역 ($myRegion)';
  }

  Future<void> _loadDiaries() async {
    try {
      Map<String, dynamic> data;
      if (_tabIndex == 0) {
        data = await ApiService.exploreDiaries(
          isRecent: true,
          sido: _activeSido,
          sigungu: _activeSigungu,
          ageGroup: _filterAge ? _myAgeGroup : null,
        );
        final diaries = data['data']?['diaries'] ?? [];
        print('explore 응답: ${diaries.isNotEmpty ? diaries.first : null}');
        setState(() {
          _diaries = List<Map<String, dynamic>>.from(diaries);
          _guidanceMessage = _extractGuidanceMessage(
            data,
            fallback: '조건에 맞는 일기가 아직 없어요.',
          );
          _hasLoadError = false;
          _isLoading = false;
        });
      } else if (_tabIndex == 1) {
        data = await _loadRecommendedDiaries();
        setState(() {
          _diaries = List<Map<String, dynamic>>.from(
            data['data']?['diaries'] ?? [],
          );
          _guidanceMessage = _extractGuidanceMessage(
            data,
            fallback: '아직 추천할 상대가 없어요. 일기를 더 작성해보세요!',
          );
          _hasLoadError = false;
          _isLoading = false;
        });
      } else {
        data = await ApiService.getMyDiaries();
        setState(() {
          _diaries = List<Map<String, dynamic>>.from(
            data['data']?['diaries'] ?? [],
          );
          _guidanceMessage = _extractGuidanceMessage(
            data,
            fallback: '아직 작성한 일기가 없어요.',
          );
          _hasLoadError = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('일기 로드 오류: $e');
      if (!mounted) return;
      setState(() {
        _diaries = [];
        _guidanceMessage = _friendlyLoadError(e);
        _hasLoadError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _retryLoadDiaries() async {
    setState(() {
      _isLoading = true;
      _hasLoadError = false;
      _guidanceMessage = '';
    });
    await _loadDiaries();
  }

  String _friendlyLoadError(Object error) {
    final message = error.toString();
    if (message.contains('다시 로그인') ||
        message.contains('401') ||
        message.contains('A00')) {
      return '로그인 시간이 만료됐어요. 다시 로그인한 뒤 이용해주세요.';
    }
    if (message.contains('429')) {
      return '요청이 잠시 많아요. 조금 뒤에 다시 시도해주세요.';
    }
    if (message.contains('503') ||
        message.contains('500') ||
        message.contains('서버')) {
      return '서버 응답이 불안정해요. 잠시 후 다시 시도해주세요.';
    }
    if (message.contains('TimeoutException') ||
        message.contains('지연') ||
        message.contains('timed out')) {
      return '응답이 지연되고 있어요. 네트워크 상태를 확인하고 다시 시도해주세요.';
    }
    if (message.contains('SocketException') ||
        message.contains('네트워크') ||
        message.contains('Failed host lookup')) {
      return '네트워크 연결을 확인한 뒤 다시 시도해주세요.';
    }
    return '일기를 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  String _extractGuidanceMessage(
    Map<String, dynamic> response, {
    required String fallback,
  }) {
    final payload = response['data'];
    final message = payload is Map
        ? payload['guidanceMessage'] ??
              payload['message'] ??
              response['guidanceMessage']
        : response['guidanceMessage'];
    final text = message?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  Future<Map<String, dynamic>> _loadRecommendedDiaries() async {
    final recommendation = await ApiService.getRecommendations();
    final payload = recommendation['data'];
    final items = payload is Map ? payload['items'] : null;
    if (items is List && items.isNotEmpty) {
      final previews = <Map<String, dynamic>>[];
      for (final item in items) {
        if (item is! Map) continue;
        final diaryId = item['diaryId'] ?? item['id'];
        final parsedDiaryId = diaryId is int
            ? diaryId
            : int.tryParse(diaryId?.toString() ?? '');
        if (parsedDiaryId == null) continue;
        final preview = await ApiService.getRecommendationPreview(
          parsedDiaryId,
        );
        final previewData = preview['data'];
        if (previewData is Map) {
          previews.add({
            ...Map<String, dynamic>.from(previewData),
            'diaryId': parsedDiaryId,
            'matchingScore': item['matchingScore'],
          });
        }
      }
      if (previews.isNotEmpty) {
        return {
          'data': {'diaries': previews, 'guidanceMessage': null},
        };
      }
    }

    return ApiService.exploreDiaries(
      isRecent: false,
      sido: _activeSido,
      sigungu: _activeSigungu,
      ageGroup: _filterAge ? _myAgeGroup : null,
      keywordFilter: true,
    );
  }

  Future<void> _openDiaryWriter() async {
    try {
      final today = await ApiService.getTodayDiary();
      final payload = today['data'];
      final data = payload is Map ? Map<String, dynamic>.from(payload) : today;
      final diaryId =
          data['diaryId'] ??
          data['id'] ??
          data['todayDiaryId'] ??
          data['diary'];
      final hasTodayDiary =
          data['exists'] == true ||
          data['hasDiary'] == true ||
          data['written'] == true ||
          data['hasTodayDiary'] == true ||
          (diaryId != null && diaryId.toString().isNotEmpty);

      if (hasTodayDiary) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('오늘 일기는 이미 작성했어요.')));
        final parsedDiaryId = diaryId is int
            ? diaryId
            : int.tryParse(diaryId?.toString() ?? '');
        if (parsedDiaryId != null && parsedDiaryId > 0) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DiaryDetailScreen(
                title: decodeHtmlEntities(
                  data['summary'] ??
                      data['contentPreview'] ??
                      data['previewContent'] ??
                      '',
                ),
                time: data['createdAt'] ?? '',
                diaryId: parsedDiaryId,
                showDecisionButtons: false,
              ),
            ),
          );
        }
        if (!mounted) return;
        setState(() => _isLoading = true);
        await _loadDiaries();
        return;
      }
    } catch (_) {
      // 오늘 일기 조회가 실패해도 작성 화면 진입 자체는 막지 않는다.
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DiaryScreen()));
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _loadDiaries();
  }

  @override
  Widget build(BuildContext context) {
    const double tabSize = 90.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 14),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFFE37474),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AiReportScreen(),
                        ),
                      );
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Diary',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFE37474),
                        fontSize: 30,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFFE37474),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationScreen(),
                        ),
                      );
                    },
                  ),
                ],
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
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '지역 필터링',
                                        style: const TextStyle(
                                          color: Color(0xFFE37474),
                                          fontSize: 16,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    DropdownButtonFormField<String>(
                                      initialValue: _filterRegion
                                          ? (_selectedSido ?? '내 지역')
                                          : '전체',
                                      decoration: InputDecoration(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                        filled: true,
                                        fillColor: const Color(0xFFFFF5F5),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      iconEnabledColor: const Color(0xFFE37474),
                                      items: [
                                        const DropdownMenuItem(
                                          value: '전체',
                                          child: Text('전체 지역'),
                                        ),
                                        DropdownMenuItem(
                                          value: '내 지역',
                                          child: Text(
                                            _mySido == null
                                                ? '내 지역'
                                                : '내 지역 ($_mySido ${_mySigungu ?? ''})',
                                          ),
                                        ),
                                        ..._sidoOptions.map(
                                          (sido) => DropdownMenuItem(
                                            value: sido,
                                            child: Text(sido),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setModalState(() {});
                                        setState(() {
                                          _filterRegion = value != '전체';
                                          _selectedSido =
                                              value == null ||
                                                  value == '전체' ||
                                                  value == '내 지역'
                                              ? null
                                              : value;
                                          _isLoading = true;
                                        });
                                        _loadDiaries();
                                      },
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '현재 적용: $_regionFilterLabel',
                                        style: const TextStyle(
                                          color: Color(0xFF9A7A76),
                                          fontSize: 12,
                                          fontFamily: 'Pretendard',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _myAgeGroup == null
                                              ? '나이대 필터링'
                                              : '내 나이대 필터링 ($_myAgeGroup)',
                                          style: const TextStyle(
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
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _guidanceMessage.isEmpty
                                        ? '일기가 없어요'
                                        : _guidanceMessage,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF391713),
                                      fontSize: 14,
                                      height: 1.5,
                                      fontFamily: 'Pretendard',
                                    ),
                                  ),
                                  if (_hasLoadError) ...[
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: _retryLoadDiaries,
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Color(0xFFE37474),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        '다시 시도',
                                        style: TextStyle(
                                          color: Color(0xFFE37474),
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: const Color(0xFFE37474),
                            onRefresh: _retryLoadDiaries,
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                24,
                                8,
                                24,
                                _tabIndex == 2 ? 92 : 24,
                              ),
                              itemCount: _diaries.length,
                              itemBuilder: (context, index) {
                                final diary = _diaries[index];
                                return _DiaryItem(
                                  title: () {
                                    if (_tabIndex == 2) {
                                      return decodeHtmlEntities(
                                        diary['summary'] ??
                                            diary['contentPreview'] ??
                                            '내용 없음',
                                      );
                                    }
                                    final content =
                                        (diary['previewContent'] ??
                                                diary['preview'] ??
                                                diary['summary'])
                                            ?.toString();
                                    if (content != null) {
                                      final decoded = decodeHtmlEntities(
                                        content,
                                      );
                                      return decoded.length > 30
                                          ? '${decoded.substring(0, 30)}...'
                                          : decoded;
                                    }
                                    return '내용 없음';
                                  }(),
                                  time: _tabIndex == 2
                                      ? diary['createdAt']
                                                ?.toString()
                                                .substring(0, 10) ??
                                            ''
                                      : '${diary['ageGroupLabel'] ?? ''} · ${diary['sido'] ?? ''} ${diary['sigungu'] ?? ''}',
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DiaryDetailScreen(
                                          title: decodeHtmlEntities(
                                            diary['previewContent'] ??
                                                diary['summary'] ??
                                                diary['contentPreview'] ??
                                                '',
                                          ),
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
                  ),
                  if (_tabIndex == 2)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: _openDiaryWriter,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('오늘 일기 쓰기'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFE37474),
                            elevation: 8,
                            shadowColor: Colors.black26,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

class _ListStatus extends StatelessWidget {
  final bool isLoading;
  final String message;
  final bool canRetry;
  final VoidCallback onRetry;

  const _ListStatus({
    required this.isLoading,
    required this.message,
    required this.canRetry,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              const CircularProgressIndicator(color: Color(0xFFE37474))
            else ...[
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF391713),
                  fontSize: 14,
                  height: 1.5,
                  fontFamily: 'Pretendard',
                ),
              ),
              if (canRetry) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE37474)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '다시 시도',
                    style: TextStyle(
                      color: Color(0xFFE37474),
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
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
  final int initialTab;

  const _FriendsBody({this.initialTab = 0});

  @override
  State<_FriendsBody> createState() => _FriendsBodyState();
}

class _FriendsBodyState extends State<_FriendsBody> {
  late int _tabIndex; // 0: Diary, 1: Message, 2: Request

  List<Map<String, dynamic>> _friends = [];
  bool _isLoadingFriends = true;
  String _friendsMessage = '진행 중인 교환일기가 없어요.';
  bool _friendsLoadFailed = false;

  List<Map<String, dynamic>> _messages = [];
  bool _isLoadingMessages = true;
  String _messagesMessage = '열려 있는 채팅방이 없어요.';
  bool _messagesLoadFailed = false;

  List<Map<String, dynamic>> _requests = [];
  bool _isLoadingRequests = true;
  String _requestsMessage = '받은 교환일기 신청이 없어요.';
  bool _requestsLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTab.clamp(0, 2).toInt();
    _loadExchangeRooms();
  }

  Future<void> _loadExchangeRooms() async {
    try {
      final data = await ApiService.getExchangeRooms();
      setState(() {
        _friends = List<Map<String, dynamic>>.from(
          data['data']?['rooms'] ?? [],
        );
        _friendsMessage = '진행 중인 교환일기가 없어요.';
        _friendsLoadFailed = false;
        _isLoadingFriends = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _friends = [];
        _friendsMessage = _friendlyLoadError(e);
        _friendsLoadFailed = true;
        _isLoadingFriends = false;
      });
    }

    try {
      final data = await ApiService.getChatRooms();
      setState(() {
        _messages = List<Map<String, dynamic>>.from(
          data['data']?['chatRooms'] ?? [],
        );
        _messagesMessage = '열려 있는 채팅방이 없어요.';
        _messagesLoadFailed = false;
        _isLoadingMessages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = [];
        _messagesMessage = _friendlyLoadError(e);
        _messagesLoadFailed = true;
        _isLoadingMessages = false;
      });
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
        _requestsMessage = '받은 교환일기 신청이 없어요.';
        _requestsLoadFailed = false;
        _isLoadingRequests = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _requests = [];
        _requestsMessage = _friendlyLoadError(e);
        _requestsLoadFailed = true;
        _isLoadingRequests = false;
      });
    }
  }

  Future<void> _retryExchangeRooms() async {
    setState(() {
      _isLoadingFriends = true;
      _isLoadingMessages = true;
      _isLoadingRequests = true;
      _friendsLoadFailed = false;
      _messagesLoadFailed = false;
      _requestsLoadFailed = false;
    });
    await _loadExchangeRooms();
  }

  String _friendlyLoadError(Object error) {
    final message = error.toString();
    if (message.contains('다시 로그인') ||
        message.contains('401') ||
        message.contains('A00')) {
      return '로그인 시간이 만료됐어요. 다시 로그인해주세요.';
    }
    if (message.contains('429')) {
      return '요청이 잠시 많아요. 조금 뒤에 다시 시도해주세요.';
    }
    if (message.contains('503') ||
        message.contains('500') ||
        message.contains('서버')) {
      return '서버 응답이 불안정해요. 잠시 후 다시 시도해주세요.';
    }
    if (message.contains('TimeoutException') ||
        message.contains('지연') ||
        message.contains('timed out')) {
      return '응답이 지연되고 있어요. 네트워크 상태를 확인하고 다시 시도해주세요.';
    }
    if (message.contains('SocketException') ||
        message.contains('네트워크') ||
        message.contains('Failed host lookup')) {
      return '네트워크 연결을 확인한 뒤 다시 시도해주세요.';
    }
    return '목록을 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  Future<void> _endExchangeRoom(Map<String, dynamic> room) async {
    final roomId = room['roomId'] is int
        ? room['roomId'] as int
        : int.tryParse(room['roomId']?.toString() ?? '') ?? 0;
    if (roomId == 0) return;
    final success = await ApiService.endExchangeRoom(roomId);
    if (!mounted) return;
    if (success) {
      await _loadExchangeRooms();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '선택을 보냈어요' : '선택을 보낼 수 없어요')),
    );
  }

  Future<void> _leaveChatRoom(Map<String, dynamic> room) async {
    final roomId = room['chatRoomId'] is int
        ? room['chatRoomId'] as int
        : int.tryParse(room['chatRoomId']?.toString() ?? '') ?? 0;
    if (roomId == 0) return;
    final success = await ApiService.leaveChatRoom(roomId);
    if (!mounted) return;
    if (success) {
      await _loadExchangeRooms();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '채팅방을 나갔어요' : '채팅방을 나갈 수 없어요')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE37474),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 16, 12),
              child: Row(
                children: [
                  const SizedBox(width: 44),
                  const Expanded(
                    child: Text(
                      'Friends',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFF8F8F8),
                        fontSize: 28,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_outlined,
                      color: Color(0xFFF8F8F8),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationScreen(),
                        ),
                      );
                    },
                  ),
                ],
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
                              itemCount: _isLoadingFriends || _friends.isEmpty
                                  ? 1
                                  : _friends.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFFE37474),
                                thickness: 1,
                              ),
                              itemBuilder: (context, index) {
                                if (_isLoadingFriends || _friends.isEmpty) {
                                  return _ListStatus(
                                    isLoading: _isLoadingFriends,
                                    message: _friendsMessage,
                                    canRetry: _friendsLoadFailed,
                                    onRetry: _retryExchangeRooms,
                                  );
                                }
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
                                          '관계 선택을 보낼까요?',
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
                                              onPressed: () async {
                                                Navigator.pop(context);
                                                await _endExchangeRoom(f);
                                              },
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
                                                '계속 선택',
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
                                  ? 1
                                  : _messages.isEmpty
                                  ? 1
                                  : _messages.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFFE37474),
                                thickness: 1,
                              ),
                              itemBuilder: (context, index) {
                                if (_isLoadingMessages || _messages.isEmpty) {
                                  return _ListStatus(
                                    isLoading: _isLoadingMessages,
                                    message: _messagesMessage,
                                    canRetry: _messagesLoadFailed,
                                    onRetry: _retryExchangeRooms,
                                  );
                                }
                                final msg = _messages[index];
                                return _MessageItem(
                                  name: msg['partnerNickname'] ?? '알 수 없음',
                                  preview: msg['lastMessage'] ?? '',
                                  isNew: (msg['unreadCount'] ?? 0) > 0,
                                  trailingLabel: '나가기',
                                  onTrailingTap: () => _leaveChatRoom(msg),
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
                                  ? 1
                                  : _requests.isEmpty
                                  ? 1
                                  : _requests.length,
                              separatorBuilder: (_, __) => const Divider(
                                color: Color(0xFFE37474),
                                thickness: 1,
                              ),
                              itemBuilder: (context, index) {
                                if (_isLoadingRequests || _requests.isEmpty) {
                                  return _ListStatus(
                                    isLoading: _isLoadingRequests,
                                    message: _requestsMessage,
                                    canRetry: _requestsLoadFailed,
                                    onRetry: _retryExchangeRooms,
                                  );
                                }
                                final request = _requests[index];
                                final preview =
                                    request['diaryPreview'] ??
                                    request['preview'] ??
                                    request['previewContent'] ??
                                    request['contentPreview'] ??
                                    request['diaryTitle'] ??
                                    '';
                                final rawKeywords =
                                    request['keywords'] ??
                                    request['personalityKeywords'] ??
                                    request['moodTags'] ??
                                    [];
                                final keywords = rawKeywords is List
                                    ? rawKeywords
                                          .map((e) => e.toString())
                                          .where((e) => e.isNotEmpty)
                                          .toList()
                                    : <String>[];
                                final matchingId = request['matchingId'] ?? request['id'] ?? 0;
                                final nickname = request['fromUserNickname'] ?? request['nickname'] ?? request['senderNickname'] ?? '알 수 없음';
                                final ageGroup = request['fromUserAgeGroup'] ?? request['ageGroup'] ?? '';
                                return _MatchingRequestCard(
                                  nickname: nickname,
                                  ageGroup: ageGroup,
                                  preview: decodeHtmlEntities(preview),
                                  keywords: keywords,
                                  onAccept: () async {
                                    try {
                                      await ApiService.acceptMatchingResponse(matchingId as int);
                                      if (!mounted) return;
                                      setState(() {
                                        _requests.removeAt(index);
                                        _tabIndex = 0;
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('매칭을 수락했어요! 교환일기가 시작됩니다.')),
                                      );
                                      _loadExchangeRooms();
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('수락 실패: $e')),
                                      );
                                    }
                                  },
                                  onReject: () {
                                    setState(() {
                                      _requests.removeAt(index);
                                    });
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
                            '계속',
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
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;
  const _MessageItem({
    required this.name,
    required this.preview,
    required this.isNew,
    required this.onTap,
    this.trailingLabel,
    this.onTrailingTap,
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
            if (trailingLabel != null)
              TextButton(
                onPressed: onTrailingTap,
                child: Text(
                  trailingLabel!,
                  style: const TextStyle(
                    color: Color(0xFFE37474),
                    fontSize: 12,
                    fontFamily: 'Pretendard',
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right, color: Color(0xFF391713)),
          ],
        ),
      ),
    );
  }
}

class _MatchingRequestCard extends StatelessWidget {
  final String nickname, ageGroup, preview;
  final List<String> keywords;
  final VoidCallback onAccept, onReject;

  const _MatchingRequestCard({
    required this.nickname,
    required this.ageGroup,
    required this.preview,
    required this.keywords,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0DB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFEC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person, color: Color(0xFFE37474), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nickname, style: const TextStyle(fontSize: 16, fontFamily: 'Pretendard', fontWeight: FontWeight.w700, color: Color(0xFF391713))),
                    if (ageGroup.isNotEmpty)
                      Text(ageGroup, style: const TextStyle(fontSize: 12, fontFamily: 'Pretendard', color: Color(0xFF9CA3AF))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(preview, style: const TextStyle(fontSize: 14, fontFamily: 'Pretendard', color: Color(0xFF6B7280), height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
          if (keywords.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 4,
              children: keywords.map((k) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(12)),
                child: Text(k, style: const TextStyle(fontSize: 12, fontFamily: 'Pretendard', color: Color(0xFFE37474))),
              )).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFD1D5DB)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('넘기기', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14, fontFamily: 'Pretendard', fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE37474), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text('수락하기', style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Pretendard', fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
