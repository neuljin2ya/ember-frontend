import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'api_service.dart';

class ExchangeDiaryWriteScreen extends StatefulWidget {
  final int roomId;
  final String partnerNickname;

  const ExchangeDiaryWriteScreen({
    super.key,
    required this.roomId,
    required this.partnerNickname,
  });

  @override
  State<ExchangeDiaryWriteScreen> createState() =>
      _ExchangeDiaryWriteScreenState();
}

class _ExchangeDiaryWriteScreenState extends State<ExchangeDiaryWriteScreen> {
  DateTime _selectedDate = DateTime.now();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  int _bodyLength = 0;
  bool _isSubmitting = false;

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

  Future<void> _submit() async {
    if (_bodyController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일기 내용을 입력해주세요.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ApiService.postExchangeDiary(
        roomId: widget.roomId,
        content: _bodyController.text.trim(),
        date:
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('교환일기를 보냈어요!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오류가 발생했습니다.')),
        );
      }
    }
    setState(() => _isSubmitting = false);
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

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFFE37474),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 상대방 닉네임
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left,
                        color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      '${widget.partnerNickname}에게 쓰는 일기',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const Spacer(),

            // 흰 카드
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF8F8F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              height: MediaQuery.of(context).size.height * 0.82,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 날짜 태그
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time,
                              size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(_selectedDate),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 제목 + 글자수
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _titleController,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: const InputDecoration(
                            hintText: '제목',
                            hintStyle: TextStyle(
                              color: Color(0xFFB8B8B8),
                              fontSize: 18,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w700,
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
                      ),
                      decoration: const InputDecoration(
                        hintText: '오늘 하루를 기록해보세요.',
                        hintStyle: TextStyle(
                          color: Color(0xFFB8B8B8),
                          fontSize: 14,
                          fontFamily: 'Pretendard',
                          height: 1.64,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),

                  // Done 버튼
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: GestureDetector(
                        onTap: _isSubmitting ? null : _submit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 60, vertical: 10),
                          decoration: BoxDecoration(
                            color: _isSubmitting
                                ? const Color(0xFFD1D5DB)
                                : const Color(0xFFE37474),
                            borderRadius: BorderRadius.circular(52),
                            border:
                            Border.all(color: const Color(0xFFE95322)),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
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
    );
  }
}