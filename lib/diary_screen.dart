import 'dart:async';

import 'package:flutter/material.dart';
import 'diary_analysis_screen.dart';
import 'api_service.dart';

class DiaryScreen extends StatefulWidget {
  final bool requiredForSignup;

  const DiaryScreen({super.key, this.requiredForSignup = false});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> with WidgetsBindingObserver {
  static const int _wednesday = DateTime.wednesday;
  final DateTime _selectedDate = DateTime.now();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int _bodyLength = 0;
  Map<String, dynamic>? _weeklyTopic;
  bool _useWeeklyTopic = false;
  bool _isTopicLoading = true;
  Timer? _draftTimer;
  int? _activeDraftId;
  String _lastSavedDraftContent = '';
  bool _isDraftSaving = false;

  bool get _canSubmit =>
      _titleController.text.trim().isNotEmpty &&
      _bodyController.text.trim().length >= 200 &&
      _bodyController.text.trim().length <= 1000;

  bool get _canUseWeeklyTopic {
    final topic = _weeklyTopic;
    if (topic == null) return false;
    return DateTime.now().weekday == _wednesday &&
        topic['isActive'] == true &&
        topic['topicId'] != null &&
        topic['title'] != null;
  }

  int? get _selectedTopicId {
    if (!_useWeeklyTopic || !_canUseWeeklyTopic) return null;
    final id = _weeklyTopic?['topicId'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadWeeklyTopic();
    _loadDrafts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveDraftIfNeeded());
    }
  }

  Future<void> _loadWeeklyTopic() async {
    try {
      final response = await ApiService.getWeeklyTopic();
      final data = response['data'];
      if (!mounted) return;
      setState(() {
        _weeklyTopic = data is Map ? Map<String, dynamic>.from(data) : null;
        _isTopicLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isTopicLoading = false);
    }
  }

  void _selectWeeklyTopic() {
    final title = _weeklyTopic?['title']?.toString() ?? '';
    setState(() {
      _useWeeklyTopic = true;
      if (_titleController.text.trim().isEmpty && title.isNotEmpty) {
        _titleController.text = title;
      }
    });
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(seconds: 2),
      () => unawaited(_saveDraftIfNeeded()),
    );
  }

  Future<void> _loadDrafts() async {
    try {
      final response = await ApiService.getDrafts();
      final payload = response['data'];
      final rawDrafts = payload is Map
          ? payload['drafts'] ?? payload['items'] ?? []
          : payload is List
          ? payload
          : [];
      final drafts = List<Map<String, dynamic>>.from(rawDrafts);
      if (drafts.isEmpty || !mounted) return;

      final draft = drafts.first;
      final content = draft['content']?.toString() ?? '';
      if (content.trim().isEmpty) return;

      final shouldRestore = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('임시저장 일기를 불러올까요?'),
          content: Text(
            content.length > 80 ? '${content.substring(0, 80)}...' : content,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('아니요'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE37474),
              ),
              child: const Text('불러오기'),
            ),
          ],
        ),
      );

      if (!mounted || shouldRestore != true) return;
      setState(() {
        _activeDraftId = draft['draftId'] is int
            ? draft['draftId'] as int
            : int.tryParse(draft['draftId']?.toString() ?? '');
        _bodyController.text = content;
        _bodyLength = content.length;
        _lastSavedDraftContent = content.trim();
        final topicId = draft['topicId'];
        if (topicId != null &&
            topicId.toString() == _weeklyTopic?['topicId']?.toString()) {
          _useWeeklyTopic = true;
          _titleController.text = _weeklyTopic?['title']?.toString() ?? '';
        }
      });
    } catch (_) {}
  }

  Future<void> _saveDraftIfNeeded() async {
    if (_isDraftSaving) return;
    final content = _bodyController.text.trim();
    if (content.isEmpty || content.length > 1000) return;
    if (content == _lastSavedDraftContent) return;

    _isDraftSaving = true;
    try {
      final previousDraftId = _activeDraftId;
      if (previousDraftId != null) {
        await ApiService.deleteDraft(previousDraftId);
        _activeDraftId = null;
      }
      final response = await ApiService.createDraft(
        content: content,
        topicId: _selectedTopicId,
      );
      final payload = response['data'];
      if (payload is Map) {
        final draftId = payload['draftId'];
        _activeDraftId = draftId is int
            ? draftId
            : int.tryParse(draftId?.toString() ?? '');
      }
      _lastSavedDraftContent = content;
    } catch (_) {
      // 드래프트 자동저장은 사용자 흐름을 막지 않는다.
    } finally {
      _isDraftSaving = false;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  void dispose() {
    unawaited(_saveDraftIfNeeded());
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOverLimit = _bodyLength >= 1000;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: const Color(0xFFE37474),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // 상단 날짜 바
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C1D3A58),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48, height: 48),
                      Row(
                        children: const [
                          Icon(
                            Icons.calendar_today,
                            size: 18,
                            color: Colors.black87,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Today',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 48, height: 48),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 아래에서 올라오는 흰 카드 (create_profile과 동일 형태)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 날짜 태그 + 더보기
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE37474),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDate(_selectedDate),
                                  style: const TextStyle(
                                    color: Color(0xFFFFFDFD),
                                    fontSize: 13,
                                    fontFamily: 'Pretendard',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.more_vert,
                            color: Colors.black38,
                            size: 20,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      if (_isTopicLoading)
                        const SizedBox(
                          height: 2,
                          child: LinearProgressIndicator(
                            color: Color(0xFFE37474),
                          ),
                        )
                      else if (_canUseWeeklyTopic) ...[
                        GestureDetector(
                          onTap: _selectWeeklyTopic,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: _useWeeklyTopic
                                  ? const Color(0xFFFFECEC)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _useWeeklyTopic
                                    ? const Color(0xFFE37474)
                                    : const Color(0xFFE9E9E9),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _useWeeklyTopic
                                      ? Icons.check_circle
                                      : Icons.auto_awesome,
                                  color: const Color(0xFFE37474),
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '수요일 랜덤 주제',
                                        style: TextStyle(
                                          color: Color(0xFFE37474),
                                          fontSize: 12,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _weeklyTopic?['title']?.toString() ??
                                            '',
                                        style: const TextStyle(
                                          color: Color(0xFF391713),
                                          fontSize: 14,
                                          fontFamily: 'Pretendard',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // 제목 + 글자수
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              onChanged: (_) {
                                setState(() {});
                                _scheduleDraftSave();
                              },
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 18,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.36,
                              ),
                              decoration: const InputDecoration(
                                hintText: '제목',
                                hintStyle: TextStyle(
                                  color: Color(0xFFB8B8B8),
                                  fontSize: 18,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.36,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          Text(
                            '$_bodyLength/1000',
                            style: TextStyle(
                              color: isOverLimit
                                  ? const Color(0xFFE37474)
                                  : const Color(0xFFB8B8B8),
                              fontSize: 13,
                              fontFamily: 'Pretendard',
                              fontWeight: isOverLimit
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),

                      const Divider(color: Color(0xFFEEEEEE), height: 20),

                      // 본문
                      Expanded(
                        child: TextField(
                          controller: _bodyController,
                          maxLines: null,
                          expands: true,
                          maxLength: 1000,
                          buildCounter:
                              (
                                _, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) => null,
                          onChanged: (v) => setState(() {
                            _bodyLength = v.length;
                            _scheduleDraftSave();
                          }),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 14,
                            fontFamily: 'Pretendard',
                            height: 1.64,
                            letterSpacing: 0.28,
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                '오늘 당신의 이야기를 들려주세요.\n오늘 있었던 작은 일, 스쳐 지나간 생각,\n기분 좋았던 순간이나 조금 지쳤던 마음까지\n있는 그대로 적어주세요.\n\n당신의 하루는 누군가에게는\n당신을 이해할 수 있는 가장 솔직한 단서가 됩니다.\n\n일기 속에서 자연스럽게 전해질 거예요.\n지금 이 순간의 당신을 기록해보세요.\n이 글은 누군가와 교환되어\n새로운 연결의 시작이 됩니다.',
                            hintStyle: TextStyle(
                              color: Color(0xFFB8B8B8),
                              fontSize: 14,
                              fontFamily: 'Pretendard',
                              height: 1.64,
                              letterSpacing: 0.28,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),

                      // Done 버튼
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
                        child: Center(
                          child: GestureDetector(
                            onTap: _canSubmit
                                ? () async {
                                    if (_bodyController.text.trim().isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('일기 내용을 입력해주세요.'),
                                        ),
                                      );
                                      return;
                                    }
                                    if (_bodyController.text.trim().length <
                                        200) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '일기는 최소 200자 이상 작성해주세요.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    if (_bodyController.text.trim().length >
                                        1000) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            '일기는 최대 1000자까지 작성 가능해요.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    try {
                                      final token =
                                          await ApiService.getAccessToken();
                                      if (token == null || token.isEmpty) {
                                        throw Exception(
                                          '로그인 정보가 없어요. 다시 로그인해주세요.',
                                        );
                                      }
                                      final result = await ApiService.postDiary(
                                        content: _bodyController.text.trim(),
                                        visibility: 'PRIVATE',
                                        topicId: _selectedTopicId,
                                      );
                                      final draftId = _activeDraftId;
                                      if (draftId != null) {
                                        try {
                                          await ApiService.deleteDraft(draftId);
                                        } catch (_) {}
                                      }
                                      final data = result['data'];
                                      final diaryId = data is Map
                                          ? data['diaryId'] ?? data['id']
                                          : result['diaryId'];
                                      final parsedDiaryId = diaryId is int
                                          ? diaryId
                                          : int.tryParse(
                                              diaryId?.toString() ?? '',
                                            );
                                      if (parsedDiaryId == null) {
                                        throw Exception(
                                          '저장된 일기 번호를 확인할 수 없어요.',
                                        );
                                      }
                                      if (context.mounted) {
                                        final route = MaterialPageRoute(
                                          builder: (_) => DiaryAnalysisScreen(
                                            diaryId: parsedDiaryId,
                                            requiredForSignup:
                                                widget.requiredForSignup,
                                          ),
                                        );
                                        if (widget.requiredForSignup) {
                                          Navigator.pushReplacement(
                                            context,
                                            route,
                                          );
                                        } else {
                                          Navigator.push(context, route);
                                        }
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('일기 저장 실패: $e'),
                                          ),
                                        );
                                        final message = e.toString();
                                        if (message.contains('다시 로그인') ||
                                            message.contains('계정 정보')) {
                                          Navigator.of(
                                            context,
                                          ).pushNamedAndRemoveUntil(
                                            '/socialLogin',
                                            (route) => false,
                                          );
                                        }
                                      }
                                    }
                                  }
                                : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 46,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: _canSubmit
                                    ? const Color(0xFFE37474)
                                    : const Color(0xFFE8B4B4),
                                borderRadius: BorderRadius.circular(52),
                                border: Border.all(
                                  color: _canSubmit
                                      ? const Color(0xFFE95322)
                                      : const Color(0xFFE8B4B4),
                                ),
                              ),
                              child: const Text(
                                'Done',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
