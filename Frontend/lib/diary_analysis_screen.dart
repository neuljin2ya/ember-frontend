import 'package:flutter/material.dart';
import 'home_screen.dart';

class DiaryAnalysisScreen extends StatefulWidget {
  const DiaryAnalysisScreen({super.key});

  @override
  State<DiaryAnalysisScreen> createState() => _DiaryAnalysisScreenState();
}

class _DiaryAnalysisScreenState extends State<DiaryAnalysisScreen> {
  int _dotCount = 1;
  bool _isDone = false;

  @override
  void initState() {
    super.initState();
    _startDotAnimation();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isDone = true);
    });
  }

  void _startDotAnimation() async {
    while (mounted && !_isDone) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted || _isDone) break;
      setState(() => _dotCount = _dotCount == 3 ? 1 : _dotCount + 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // 원
              Container(
                width: 139,
                height: 139,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE37474),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: _isDone
                      ? const Icon(
                    Icons.check,
                    color: Color(0xFFE37474),
                    size: 60,
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _dotCount,
                          (i) => Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE37474),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _isDone ? '일기 분석 완료' : '당신의 일기를 분석하고 있어요',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF391713),
                    fontSize: 22,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _isDone
                      ? '다른 사람들과 오늘 하루를 나누러 가볼까요?'
                      : '당신의 하루를 하나씩 살펴보고 있어요.\n글 속에 담긴 마음과 결을 분석 중입니다.\n잠시만 기다려주세요, 새로운 연결을 준비하고 있어요.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF391713),
                    fontSize: 15,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w500,
                    height: 1.56,
                  ),
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: _isDone
                    ? GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/home');
                    },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE37474),
                      borderRadius: BorderRadius.circular(52),
                      border:
                      Border.all(color: const Color(0xFFE95322)),
                    ),
                    child: const Text(
                      '시작하기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                    : const SizedBox(height: 38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}