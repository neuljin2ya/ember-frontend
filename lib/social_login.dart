import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'api_service.dart';
import 'main.dart' show registerFcmTokenToServer;
import 'signup.dart';

class SocialLogin extends StatefulWidget {
  const SocialLogin({super.key});

  @override
  State<SocialLogin> createState() => _SocialLoginState();
}

class _SocialLoginState extends State<SocialLogin> {
  bool _isLoggingIn = false;

  Future<bool> _confirmRestoreAccount() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('탈퇴 유예 계정이에요'),
          content: const Text('아직 계정 복구가 가능해요. 이전 계정을 복구하고 계속할까요?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE37474),
              ),
              child: const Text('복구하기'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<OAuthToken> _loginWithKakao() async {
    if (!await isKakaoTalkInstalled()) {
      return UserApi.instance.loginWithKakaoAccount();
    }

    try {
      return await UserApi.instance.loginWithKakaoTalk();
    } on PlatformException catch (e) {
      debugPrint('카카오톡 로그인 실패, 웹 로그인으로 재시도: ${e.code} ${e.message}');
      return UserApi.instance.loginWithKakaoAccount();
    }
  }

  Future<void> _handleLogin() async {
    if (_isLoggingIn) return;
    setState(() => _isLoggingIn = true);

    try {
      final token = await _loginWithKakao();
      final user = await UserApi.instance.me();
      final result = await ApiService.kakaoLogin(
        token.accessToken,
        user.kakaoAccount?.email ?? '',
      );
      debugPrint('result 전체: $result');

      if (!mounted) return;
      final data = result['data'] is Map ? result['data'] as Map : {};
      final role = data['role'] ?? result['role'];
      final accountStatus = data['accountStatus'] ?? result['accountStatus'];
      final restoreToken = data['restoreToken'] ?? result['restoreToken'];
      final onboardingCompleted =
          data['onboardingCompleted'] ??
          result['onboardingCompleted'] ??
          false;

      if (restoreToken != null) {
        await ApiService.clearTokens();
        if (!mounted) return;
        final shouldRestore = await _confirmRestoreAccount();
        if (!mounted || !shouldRestore) return;

        await ApiService.restoreAccount(restoreToken.toString());
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('계정을 복구했어요.')));

        if (onboardingCompleted != true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SignUp(realName: '')),
          );
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      }

      if (accountStatus != null && accountStatus != 'ACTIVE') {
        await ApiService.clearTokens();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('비활성화된 계정이에요. 관리자에게 문의해주세요.')),
        );
        return;
      }

      final savedToken = await ApiService.getAccessToken();
      if (savedToken == null || savedToken.isEmpty) {
        throw Exception('로그인 토큰 저장에 실패했어요. 다시 로그인해주세요.\n서버 응답: $result');
      }

      // 로그인 성공 후 FCM 토큰 서버 등록
      registerFcmTokenToServer();

      if (onboardingCompleted != true) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SignUp(realName: '')),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e, s) {
      debugPrint('카카오 로그인 오류: $e');
      debugPrint('스택: $s');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('로그인 오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 80),
            GestureDetector(
              onTap: _isLoggingIn ? null : _handleLogin,
              child: Opacity(
                opacity: _isLoggingIn ? 0.55 : 1,
                child: Image.asset(
                  'assets/images/kakao_login_medium_narrow.png',
                  width: 260,
                ),
              ),
            ),
            if (_isLoggingIn) ...[
              const SizedBox(height: 18),
              const CircularProgressIndicator(color: Color(0xFFE37474)),
            ],
          ],
        ),
      ),
    );
  }
}
