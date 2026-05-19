import 'package:flutter/material.dart';
import 'profile_edit_screen.dart';
import 'api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _nickname = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getMyProfile();
      setState(() {
        _nickname = data['realName'] ?? data['nickname'] ?? '사용자';
      });
    } catch (e) {}
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '로그아웃',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF391713),
            fontSize: 18,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '로그아웃 하시겠습니까?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF391713),
            fontSize: 14,
            fontFamily: 'Pretendard',
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/socialLogin', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9CA3AF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE37474),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '취소',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _WithdrawDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$_nickname 님, 안녕하세요',
                    style: TextStyle(
                      color: Color(0xFF391713),
                      fontSize: 22,
                      fontFamily: 'Pretendard',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProfileEditScreen(),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      '계정정보',
                      style: TextStyle(
                        color: Color(0xFF391713),
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            const Divider(color: Color(0xFFE5E5E5), thickness: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    '버전',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  Text(
                    '1.0.0',
                    style: TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFFE5E5E5), thickness: 1),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () => _showLogoutDialog(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      '로그아웃',
                      style: TextStyle(
                        color: Color(0xFF391713),
                        fontSize: 14,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: () => _showWithdrawDialog(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      '회원 탈퇴하기',
                      style: TextStyle(
                        color: Color(0xFF391713),
                        fontSize: 14,
                        fontFamily: 'Pretendard',
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

// 회원탈퇴 다이얼로그 (체크박스 상태 관리 필요해서 StatefulWidget)
class _WithdrawDialog extends StatefulWidget {
  const _WithdrawDialog();

  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  bool _checked = false;
  bool _completed = false;

  @override
  Widget build(BuildContext context) {
    if (_completed) {
      // 탈퇴 완료 화면
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '회원탈퇴가 완료되었어요',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF391713),
            fontSize: 18,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          '그동안 이용해주셔서 감사합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF391713),
            fontSize: 14,
            fontFamily: 'Pretendard',
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                await ApiService.logout();
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/socialLogin', (route) => false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE37474),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                '확인',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'Pretendard',
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 탈퇴 확인 화면
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        '회원탈퇴',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF391713),
          fontSize: 18,
          fontFamily: 'Pretendard',
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '삭제 후에는 다시 확인할 수 없고\n지금까지의 분석 결과와 리포트가 모두 삭제돼요.\n정말 탈퇴하시겠어요?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF391713),
              fontSize: 13,
              fontFamily: 'Pretendard',
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _checked = !_checked),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD1D5DB)),
                    borderRadius: BorderRadius.circular(4),
                    color: _checked ? const Color(0xFFE37474) : Colors.white,
                  ),
                  child: _checked
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '삭제 내용을 확인했고, 회원탈퇴에 동의해요',
                  style: TextStyle(
                    color: Color(0xFF391713),
                    fontSize: 12,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _checked
                    ? () async {
                        await ApiService.deactivate();
                        setState(() => _completed = true);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9CA3AF),
                  disabledBackgroundColor: const Color(0xFFE5E5E5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE37474),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '취소',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MenuItem({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF391713),
                fontSize: 16,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w400,
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
