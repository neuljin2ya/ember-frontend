import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'diary_analysis_screen.dart';
import 'api_service.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DateTime _selectedDate = DateTime.now();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int _bodyLength = 0;

  Future<void> _pickDate() async {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (_) => Container(
          height: 280,
          color: Colors.white,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _selectedDate,
            onDateTimeChanged: (date) {
              setState(() => _selectedDate = date);
            },
          ),
        ),
      );
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFE37474),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year.toString().substring(2)}';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isOverLimit = _bodyLength >= 2000;

    return GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFE37474),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 날짜 바
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 30, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    const Icon(Icons.chevron_left, color: Colors.black54),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Row(
                        children: const [
                          Icon(Icons.calendar_today,
                              size: 18, color: Colors.black87),
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
                    ),
                    const Icon(Icons.chevron_right, color: Colors.black54),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // 아래에서 올라오는 흰 카드 (create_profile과 동일 형태)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF8F8F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              height: MediaQuery.of(context).size.height * 0.87,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 날짜 태그 + 더보기
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE37474),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time,
                                  size: 12, color: Colors.white),
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
                      ),
                      const Icon(Icons.more_vert,
                          color: Colors.black38, size: 20),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 제목 + 글자수
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
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
                        '$_bodyLength/2000',
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
                      maxLength: 2000,
                      buildCounter: (_, {required currentLength,
                        required isFocused, maxLength}) => null,
                      onChanged: (v) =>
                          setState(() => _bodyLength = v.length),
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
                    padding: const EdgeInsets.symmetric(vertical: 50),
                    child: Center(
                      child: GestureDetector(
                        onTap: () async {
                          if (_bodyController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('일기 내용을 입력해주세요.')),
                            );
                            return;
                          }
                          try {
                            await ApiService.postDiary(
                              content: _bodyController.text.trim(),
                              visibility: 'PRIVATE',
                            );
                            if (context.mounted) {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => DiaryAnalysisScreen(),
                              ));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('오류가 발생했습니다.')),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 60, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE37474),
                            borderRadius: BorderRadius.circular(52),
                            border: Border.all(color: const Color(0xFFE95322)),
                          ),
                          child: const Text(
                            'Done',
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
          ],
        ),
      ),

    ),
    );
  }
}