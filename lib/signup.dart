import 'package:flutter/material.dart';
import 'terms_detail.dart';
import 'create_profile.dart';
import 'api_service.dart';
import 'terms_contents.dart';

class SignUp extends StatefulWidget {
  final String realName;
  const SignUp({super.key, required this.realName});

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  bool _agreeAll = false;
  bool _agreeService = false;
  bool _agreePrivacy = false;

  void _toggleAll(bool value) {
    setState(() {
      _agreeAll = value;
      _agreeService = value;
      _agreePrivacy = value;
    });
  }

  void _updateAll() {
    setState(() {
      _agreeAll = _agreeService && _agreePrivacy;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text(
                      '이용 약관 동의',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 24,
                        fontFamily: 'Pretendard',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 모두 동의
                    GestureDetector(
                      onTap: () => _toggleAll(!_agreeAll),
                      child: Container(
                        width: double.infinity,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEFEC),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            _CheckIcon(checked: _agreeAll),
                            const SizedBox(width: 12),
                            const Text(
                              '모두 동의합니다',
                              style: TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 16,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    _TermsItem(
                      label: '[필수] 서비스 이용약관 동의',
                      checked: _agreeService,
                      onChanged: (v) {
                        setState(() => _agreeService = v);
                        _updateAll();
                      },
                      onView: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsDetail(
                              title: '[필수] 서비스 이용약관',
                              content: serviceTermsContent,
                            ),
                          ),
                        );
                      },
                    ),

                    _TermsItem(
                      label: '[필수] 개인정보 수집 및 이용 동의',
                      checked: _agreePrivacy,
                      onChanged: (v) {
                        setState(() => _agreePrivacy = v);
                        _updateAll();
                      },
                      onView: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TermsDetail(
                              title: '[필수] 개인정보 수집 및 이용 동의',
                              content: privacyPolicyContent,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 시작하기 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: (_agreeService && _agreePrivacy)
                      ? () async {
                          try {
                            final token = await ApiService.getAccessToken();
                            if (token == null || token.isEmpty) {
                              throw Exception('로그인 정보가 없어요. 다시 로그인해주세요.');
                            }
                            final aiAnalysis = await ApiService.postConsent(
                              'AI_ANALYSIS',
                            );
                            final aiDataUsage = await ApiService.postConsent(
                              'AI_DATA_USAGE',
                            );
                            if (!aiAnalysis || !aiDataUsage) {
                              throw Exception('약관 동의 저장에 실패했어요.');
                            }
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CreateProfile(realName: widget.realName),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('오류: $e')));
                            }
                          }
                        }
                      : null,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE37474),
                    disabledBackgroundColor: const Color(0xFFD1D5DB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '시작하기',
                    style: TextStyle(
                      color: Color(0xFFF9FAFB),
                      fontSize: 16,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// 체크 아이콘
// ────────────────────────────────────────────

class _CheckIcon extends StatelessWidget {
  final bool checked;
  const _CheckIcon({required this.checked});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _CheckPainter(checked: checked)),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final bool checked;
  _CheckPainter({required this.checked});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = checked ? const Color(0xFFE37474) : const Color(0xFF9CA3AF)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.15, size.height * 0.52);
    path.lineTo(size.width * 0.42, size.height * 0.78);
    path.lineTo(size.width * 0.85, size.height * 0.25);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.checked != checked;
}

// ────────────────────────────────────────────
// 약관 항목 위젯
// ────────────────────────────────────────────

class _TermsItem extends StatelessWidget {
  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onView;

  const _TermsItem({
    required this.label,
    required this.checked,
    required this.onChanged,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => onChanged(!checked),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _CheckIcon(checked: checked),
          ),
        ),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 14,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        GestureDetector(
          onTap: onView,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '보기',
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 12,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
