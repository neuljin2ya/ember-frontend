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
import 'theme/colors.dart';
import 'theme/typography.dart';
import 'theme/spacing.dart';
import 'widgets/ember_button.dart';
import 'widgets/ember_card.dart';
import 'widgets/ember_empty_state.dart';

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
    '서울특별시', '부산광역시', '대구광역시', '인천광역시', '광주광역시',
    '대전광역시', '울산광역시', '세종특별자치시', '경기도', '강원도',
    '충청북도', '충청남도', '전라북도', '전라남도', '경상북도', '경상남도', '제주특별자치도',
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
        _myAgeGroup = data['ageGroup']?.toString() ?? _ageGroupFromBirthDate(data['birthDate']);
      });
    } catch (e) {}
  }

  String? _ageGroupFromBirthDate(dynamic birthDate) {
    final parsed = DateTime.tryParse(birthDate?.toString() ?? '');
    if (parsed == null) return null;
    final today = DateTime.now();
    var age = today.year - parsed.year;
    if (today.month < parsed.month || (today.month == parsed.month && today.day < parsed.day)) age--;
    if (age < 20) return '10대';
    return '${(age ~/ 10) * 10}대';
  }

  String? get _activeSido => _filterRegion ? (_selectedSido ?? _mySido) : null;

  String? get _activeSigungu {
    if (!_filterRegion || _selectedSido != null) return null;
    return _mySigungu;
  }

  String get _regionFilterLabel {
    if (!_filterRegion) return '전체 지역';
    if (_selectedSido != null) return _selectedSido!;
    final myRegion = [_mySido, _mySigungu].where((v) => v != null && v.trim().isNotEmpty).join(' ');
    return myRegion.isEmpty ? '내 지역' : '내 지역 ($myRegion)';
  }

  Future<void> _loadDiaries() async {
    try {
      Map<String, dynamic> data;
      if (_tabIndex == 0) {
        data = await ApiService.exploreDiaries(isRecent: true, sido: _activeSido, sigungu: _activeSigungu, ageGroup: _filterAge ? _myAgeGroup : null);
        final diaries = data['data']?['diaries'] ?? [];
        setState(() {
          _diaries = List<Map<String, dynamic>>.from(diaries);
          _guidanceMessage = _extractGuidanceMessage(data, fallback: '조건에 맞는 일기가 아직 없어요.');
          _hasLoadError = false;
          _isLoading = false;
        });
      } else if (_tabIndex == 1) {
        data = await _loadRecommendedDiaries();
        setState(() {
          _diaries = List<Map<String, dynamic>>.from(data['data']?['diaries'] ?? []);
          _guidanceMessage = _extractGuidanceMessage(data, fallback: '아직 추천할 상대가 없어요. 일기를 더 작성해보세요!');
          _hasLoadError = false;
          _isLoading = false;
        });
      } else {
        data = await ApiService.getMyDiaries();
        setState(() {
          _diaries = List<Map<String, dynamic>>.from(data['data']?['diaries'] ?? []);
          _guidanceMessage = _extractGuidanceMessage(data, fallback: '아직 작성한 일기가 없어요.');
          _hasLoadError = false;
          _isLoading = false;
        });
      }
    } catch (e) {
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
    setState(() { _isLoading = true; _hasLoadError = false; _guidanceMessage = ''; });
    await _loadDiaries();
  }

  String _friendlyLoadError(Object error) {
    final message = error.toString();
    if (message.contains('다시 로그인') || message.contains('401') || message.contains('A00')) return '로그인 시간이 만료됐어요. 다시 로그인한 뒤 이용해주세요.';
    if (message.contains('429')) return '요청이 잠시 많아요. 조금 뒤에 다시 시도해주세요.';
    if (message.contains('503') || message.contains('500') || message.contains('서버')) return '서버 응답이 불안정해요. 잠시 후 다시 시도해주세요.';
    if (message.contains('TimeoutException') || message.contains('지연') || message.contains('timed out')) return '응답이 지연되고 있어요. 네트워크 상태를 확인하고 다시 시도해주세요.';
    if (message.contains('SocketException') || message.contains('네트워크') || message.contains('Failed host lookup')) return '네트워크 연결을 확인한 뒤 다시 시도해주세요.';
    return '일기를 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  String _extractGuidanceMessage(Map<String, dynamic> response, {required String fallback}) {
    final payload = response['data'];
    final message = payload is Map ? payload['guidanceMessage'] ?? payload['message'] ?? response['guidanceMessage'] : response['guidanceMessage'];
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
        final parsedDiaryId = diaryId is int ? diaryId : int.tryParse(diaryId?.toString() ?? '');
        if (parsedDiaryId == null) continue;
        final preview = await ApiService.getRecommendationPreview(parsedDiaryId);
        final previewData = preview['data'];
        if (previewData is Map) {
          previews.add({...Map<String, dynamic>.from(previewData), 'diaryId': parsedDiaryId, 'matchingScore': item['matchingScore']});
        }
      }
      if (previews.isNotEmpty) return {'data': {'diaries': previews, 'guidanceMessage': null}};
    }
    return ApiService.exploreDiaries(isRecent: false, sido: _activeSido, sigungu: _activeSigungu, ageGroup: _filterAge ? _myAgeGroup : null, keywordFilter: true);
  }

  Future<void> _openDiaryWriter() async {
    try {
      final today = await ApiService.getTodayDiary();
      final payload = today['data'];
      final data = payload is Map ? Map<String, dynamic>.from(payload) : today;
      final diaryId = data['diaryId'] ?? data['id'] ?? data['todayDiaryId'] ?? data['diary'];
      final hasTodayDiary = data['exists'] == true || data['hasDiary'] == true || data['written'] == true || data['hasTodayDiary'] == true || (diaryId != null && diaryId.toString().isNotEmpty);

      if (hasTodayDiary) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오늘 일기는 이미 작성했어요.')));
        final parsedDiaryId = diaryId is int ? diaryId : int.tryParse(diaryId?.toString() ?? '');
        if (parsedDiaryId != null && parsedDiaryId > 0) {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DiaryDetailScreen(
              title: decodeHtmlEntities(data['summary'] ?? data['contentPreview'] ?? data['previewContent'] ?? ''),
              time: data['createdAt'] ?? '',
              diaryId: parsedDiaryId,
              showDecisionButtons: false,
            ),
          ));
        }
        if (!mounted) return;
        setState(() => _isLoading = true);
        await _loadDiaries();
        return;
      }
    } catch (_) {}

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiaryScreen()));
    if (!mounted) return;
    setState(() => _isLoading = true);
    await _loadDiaries();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EmberSpacing.screenAll,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: EmberColors.border,
                    borderRadius: EmberSpacing.borderRadiusPill,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('지역 필터링', style: EmberTypography.titleMedium.copyWith(color: EmberColors.primary)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _filterRegion ? (_selectedSido ?? '내 지역') : '전체',
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: EmberColors.backgroundPinkLight,
                    border: OutlineInputBorder(borderRadius: EmberSpacing.borderRadiusMd, borderSide: BorderSide.none),
                  ),
                  iconEnabledColor: EmberColors.primary,
                  items: [
                    const DropdownMenuItem(value: '전체', child: Text('전체 지역')),
                    DropdownMenuItem(value: '내 지역', child: Text(_mySido == null ? '내 지역' : '내 지역 ($_mySido ${_mySigungu ?? ''})')),
                    ..._sidoOptions.map((sido) => DropdownMenuItem(value: sido, child: Text(sido))),
                  ],
                  onChanged: (value) {
                    setModalState(() {});
                    setState(() {
                      _filterRegion = value != '전체';
                      _selectedSido = value == null || value == '전체' || value == '내 지역' ? null : value;
                      _isLoading = true;
                    });
                    _loadDiaries();
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('현재 적용: $_regionFilterLabel', style: EmberTypography.captionSmall),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _myAgeGroup == null ? '나이대 필터링' : '내 나이대 필터링 ($_myAgeGroup)',
                      style: EmberTypography.titleMedium.copyWith(color: EmberColors.primary),
                    ),
                    Switch(
                      value: _filterAge,
                      activeThumbColor: EmberColors.primary,
                      onChanged: (v) {
                        setModalState(() {});
                        setState(() { _filterAge = v; _isLoading = true; });
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
  }

  @override
  Widget build(BuildContext context) {
    final tabLabels = ['최근 일기', '추천 일기', '내 일기'];

    return Scaffold(
      backgroundColor: EmberColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.auto_awesome, color: EmberColors.primary),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiReportScreen())),
                  ),
                  Expanded(
                    child: Text('Diary', textAlign: TextAlign.center, style: EmberTypography.heading1),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: EmberColors.primary),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                  ),
                ],
              ),
            ),

            // Tab Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(3, (i) => Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                    child: EmberTabChip(
                      label: tabLabels[i],
                      isSelected: _tabIndex == i,
                      onTap: () {
                        setState(() { _tabIndex = i; _isLoading = true; });
                        _loadDiaries();
                      },
                    ),
                  )),
                ),
              ),
            ),

            // Filter + Content
            Expanded(
              child: Stack(
                children: [
                  // Content area with top decoration
                  Column(
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [EmberColors.primary.withValues(alpha: 0.1), Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _isLoading
                            ? const EmberEmptyState(isLoading: true, message: '')
                            : _diaries.isEmpty
                                ? EmberEmptyState(
                                    message: _guidanceMessage.isEmpty ? '일기가 없어요' : _guidanceMessage,
                                    canRetry: _hasLoadError,
                                    onRetry: _retryLoadDiaries,
                                    icon: Icons.menu_book_outlined,
                                  )
                                : RefreshIndicator(
                                    color: EmberColors.primary,
                                    onRefresh: _retryLoadDiaries,
                                    child: ListView.builder(
                                      padding: EdgeInsets.fromLTRB(20, 8, 20, _tabIndex == 2 ? 88 : 20),
                                      itemCount: _diaries.length,
                                      itemBuilder: (context, index) {
                                        final diary = _diaries[index];
                                        // 키워드/태그 추출
                                        final rawKeywords = diary['personalityKeywords'] ?? diary['moodTags'] ?? diary['keywords'] ?? [];
                                        final cardKeywords = rawKeywords is List
                                            ? rawKeywords.map((e) => e is Map ? (e['label'] ?? e['name'] ?? e.toString()) : e.toString()).where((e) => e.toString().isNotEmpty).take(3).map((e) => e.toString()).toList()
                                            : <String>[];
                                        // 유사도 배지
                                        final similarityBadge = diary['similarityBadge']?.toString();
                                        final matchScore = _tabIndex == 1 ? (diary['matchingScore'] is num ? (diary['matchingScore'] as num).toDouble() : null) : null;

                                        return EmberDiaryCard(
                                          title: () {
                                            if (_tabIndex == 2) return decodeHtmlEntities(diary['summary'] ?? diary['contentPreview'] ?? '내용 없음');
                                            final content = (diary['previewContent'] ?? diary['preview'] ?? diary['summary'])?.toString();
                                            if (content != null) {
                                              final decoded = decodeHtmlEntities(content);
                                              return decoded.length > 50 ? '${decoded.substring(0, 50)}...' : decoded;
                                            }
                                            return '내용 없음';
                                          }(),
                                          subtitle: _tabIndex == 2
                                              ? diary['createdAt']?.toString().substring(0, 10) ?? ''
                                              : [
                                                  diary['ageGroupLabel'] ?? '',
                                                  if ((diary['sido'] ?? '').toString().isNotEmpty) diary['sido'],
                                                  if (similarityBadge != null && similarityBadge != 'null') '♡$similarityBadge',
                                                ].where((e) => e != null && e.toString().isNotEmpty).join(' · '),
                                          matchingScore: matchScore,
                                          keywords: cardKeywords,
                                          onTap: () {
                                            Navigator.push(context, MaterialPageRoute(
                                              builder: (_) => DiaryDetailScreen(
                                                title: decodeHtmlEntities(diary['previewContent'] ?? diary['summary'] ?? diary['contentPreview'] ?? ''),
                                                time: diary['nickname'] ?? diary['createdAt'] ?? '',
                                                diaryId: diary['diaryId'] ?? diary['id'] ?? 0,
                                                showDecisionButtons: _tabIndex != 2,
                                              ),
                                            ));
                                          },
                                        );
                                      },
                                    ),
                                  ),
                      ),
                    ],
                  ),

                  // Filter FAB
                  if (_tabIndex != 2)
                    Positioned(
                      top: 8,
                      right: 20,
                      child: GestureDetector(
                        onTap: _showFilterSheet,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 2))],
                          ),
                          child: const Icon(Icons.tune, color: EmberColors.primary, size: 20),
                        ),
                      ),
                    ),

                  // Write FAB
                  if (_tabIndex == 2)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: EmberPillButton(
                          label: '오늘 일기 쓰기',
                          icon: Icons.edit,
                          onPressed: _openDiaryWriter,
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
  late int _tabIndex;

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
        _friends = List<Map<String, dynamic>>.from(data['data']?['rooms'] ?? []);
        _friendsMessage = '진행 중인 교환일기가 없어요.';
        _friendsLoadFailed = false;
        _isLoadingFriends = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _friends = []; _friendsMessage = _friendlyLoadError(e); _friendsLoadFailed = true; _isLoadingFriends = false; });
    }

    try {
      final data = await ApiService.getChatRooms();
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data['data']?['chatRooms'] ?? []);
        _messagesMessage = '열려 있는 채팅방이 없어요.';
        _messagesLoadFailed = false;
        _isLoadingMessages = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _messages = []; _messagesMessage = _friendlyLoadError(e); _messagesLoadFailed = true; _isLoadingMessages = false; });
    }

    try {
      final data = await ApiService.getReceivedRequests();
      final payload = data['data'];
      final rawRequests = payload is List ? payload : payload is Map ? payload['requests'] ?? [] : [];
      setState(() {
        _requests = List<Map<String, dynamic>>.from(rawRequests);
        _requestsMessage = '받은 교환일기 신청이 없어요.';
        _requestsLoadFailed = false;
        _isLoadingRequests = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _requests = []; _requestsMessage = _friendlyLoadError(e); _requestsLoadFailed = true; _isLoadingRequests = false; });
    }
  }

  Future<void> _retryExchangeRooms() async {
    setState(() { _isLoadingFriends = true; _isLoadingMessages = true; _isLoadingRequests = true; _friendsLoadFailed = false; _messagesLoadFailed = false; _requestsLoadFailed = false; });
    await _loadExchangeRooms();
  }

  String _friendlyLoadError(Object error) {
    final message = error.toString();
    if (message.contains('다시 로그인') || message.contains('401') || message.contains('A00')) return '로그인 시간이 만료됐어요. 다시 로그인해주세요.';
    if (message.contains('429')) return '요청이 잠시 많아요. 조금 뒤에 다시 시도해주세요.';
    if (message.contains('503') || message.contains('500') || message.contains('서버')) return '서버 응답이 불안정해요. 잠시 후 다시 시도해주세요.';
    if (message.contains('TimeoutException') || message.contains('지연') || message.contains('timed out')) return '응답이 지연되고 있어요. 네트워크 상태를 확인하고 다시 시도해주세요.';
    if (message.contains('SocketException') || message.contains('네트워크') || message.contains('Failed host lookup')) return '네트워크 연결을 확인한 뒤 다시 시도해주세요.';
    return '목록을 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  Future<void> _endExchangeRoom(Map<String, dynamic> room) async {
    final roomId = room['roomId'] is int ? room['roomId'] as int : int.tryParse(room['roomId']?.toString() ?? '') ?? 0;
    if (roomId == 0) return;
    final success = await ApiService.endExchangeRoom(roomId);
    if (!mounted) return;
    if (success) await _loadExchangeRooms();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '선택을 보냈어요' : '선택을 보낼 수 없어요')));
  }

  Future<void> _leaveChatRoom(Map<String, dynamic> room) async {
    final roomId = room['chatRoomId'] is int ? room['chatRoomId'] as int : int.tryParse(room['chatRoomId']?.toString() ?? '') ?? 0;
    if (roomId == 0) return;
    final success = await ApiService.leaveChatRoom(roomId);
    if (!mounted) return;
    if (success) await _loadExchangeRooms();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '채팅방을 나갔어요' : '채팅방을 나갈 수 없어요')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmberColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
              child: Row(
                children: [
                  const SizedBox(width: 44),
                  Expanded(
                    child: Text('Friends', textAlign: TextAlign.center, style: EmberTypography.heading2),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined, color: EmberColors.textOnPrimary),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: EmberColors.background,
                  borderRadius: EmberSpacing.borderRadiusSection,
                ),
                child: Column(
                  children: [
                    // Sub-tabs
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            EmberTabChip(label: '교환일기', isSelected: _tabIndex == 0, onTap: () => setState(() => _tabIndex = 0)),
                            const SizedBox(width: 10),
                            EmberTabChip(label: '채팅', isSelected: _tabIndex == 1, onTap: () => setState(() => _tabIndex = 1)),
                            const SizedBox(width: 10),
                            EmberTabChip(label: '받은 요청', isSelected: _tabIndex == 2, onTap: () => setState(() => _tabIndex = 2)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // List content
                    Expanded(child: _buildTabContent()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_tabIndex == 0) return _buildFriendsList();
    if (_tabIndex == 1) return _buildMessagesList();
    return _buildRequestsList();
  }

  Widget _buildFriendsList() {
    if (_isLoadingFriends || _friends.isEmpty) {
      return EmberEmptyState(isLoading: _isLoadingFriends, message: _friendsMessage, canRetry: _friendsLoadFailed, onRetry: _retryExchangeRooms, icon: Icons.menu_book_outlined);
    }
    return RefreshIndicator(
      color: EmberColors.primary,
      onRefresh: _retryExchangeRooms,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _friends.length,
        itemBuilder: (context, index) {
          final f = _friends[index];
          final roomId = f['roomId'] is int ? f['roomId'] as int : int.tryParse(f['roomId']?.toString() ?? '') ?? 0;
          final isMyTurn = f['isMyTurn'] == true;
          return EmberFriendCard(
            partnerNickname: f['partnerNickname'] ?? '',
            turnInfo: '${f['currentTurn'] ?? 0}턴',
            isMyTurn: isMyTurn,
            deadline: (f['deadline']?.toString().length ?? 0) >= 10 ? f['deadline'].toString().substring(0, 10) : null,
            status: f['status']?.toString(),
            onTap: () {
              if (roomId == 0) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => ExchangeRoomDetailScreen(roomId: roomId, partnerNickname: f['partnerNickname'] ?? ''))).then((_) => _loadExchangeRooms());
            },
            onExchange: () {
              if (!isMyTurn || roomId == 0) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => ExchangeDiaryWriteScreen(roomId: roomId, partnerNickname: f['partnerNickname'] ?? ''))).then((_) => _loadExchangeRooms());
            },
            onViewReport: () async {
              if (roomId == 0) return;
              try {
                final report = await ApiService.getExchangeRoomReport(roomId);
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Text('AI 공통점 리포트', style: EmberTypography.dialogTitle.copyWith(color: EmberColors.primary)),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (report['aiDescription'] ?? report['summary'] ?? report['description'] ?? '두 사람의 공통점을 분석했어요.').toString(),
                            style: EmberTypography.bodySmall.copyWith(height: 1.6),
                          ),
                          if (report['commonKeywords'] is List && (report['commonKeywords'] as List).isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text('공통 키워드', style: EmberTypography.titleSmall),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6, runSpacing: 6,
                              children: (report['commonKeywords'] as List).map((k) => EmberKeywordChip(label: k.toString())).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text('닫기', style: TextStyle(color: EmberColors.primary))),
                    ],
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('리포트를 불러올 수 없어요: $e')));
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMessagesList() {
    if (_isLoadingMessages || _messages.isEmpty) {
      return EmberEmptyState(isLoading: _isLoadingMessages, message: _messagesMessage, canRetry: _messagesLoadFailed, onRetry: _retryExchangeRooms, icon: Icons.chat_bubble_outline);
    }
    return RefreshIndicator(
      color: EmberColors.primary,
      onRefresh: _retryExchangeRooms,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          return EmberMessageCard(
            name: msg['partnerNickname'] ?? '알 수 없음',
            preview: msg['lastMessage'] ?? '',
            hasUnread: (msg['unreadCount'] ?? 0) > 0,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(name: msg['partnerNickname'] ?? '', roomId: msg['chatRoomId'] ?? 0))),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList() {
    if (_isLoadingRequests || _requests.isEmpty) {
      return EmberEmptyState(isLoading: _isLoadingRequests, message: _requestsMessage, canRetry: _requestsLoadFailed, onRetry: _retryExchangeRooms, icon: Icons.mail_outline);
    }
    return RefreshIndicator(
      color: EmberColors.primary,
      onRefresh: _retryExchangeRooms,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final request = _requests[index];
          final preview = request['diaryPreview'] ?? request['preview'] ?? request['previewContent'] ?? request['contentPreview'] ?? request['diaryTitle'] ?? '';
          final rawKeywords = request['keywords'] ?? request['personalityKeywords'] ?? request['moodTags'] ?? [];
          final keywords = rawKeywords is List ? rawKeywords.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() : <String>[];
          final matchingId = request['matchingId'] ?? request['id'] ?? 0;
          final nickname = request['fromUserNickname'] ?? request['nickname'] ?? request['senderNickname'] ?? '알 수 없음';
          final ageGroup = request['fromUserAgeGroup'] ?? request['ageGroup'] ?? '';

          return EmberMatchingCard(
            nickname: nickname,
            ageGroup: ageGroup,
            preview: decodeHtmlEntities(preview),
            keywords: keywords,
            onAccept: () async {
              try {
                await ApiService.acceptMatchingResponse(matchingId as int);
                if (!mounted) return;
                setState(() { _requests.removeAt(index); _tabIndex = 0; });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('매칭을 수락했어요! 교환일기가 시작됩니다.')));
                _loadExchangeRooms();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('수락 실패: $e')));
              }
            },
            onReject: () => setState(() => _requests.removeAt(index)),
          );
        },
      ),
    );
  }
}
