import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'signup.dart';
import 'api_service.dart';

class SocialLogin extends StatelessWidget {
  const SocialLogin({super.key});

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
              onTap: () async {
                try {
                  final token = await _loginWithKakao();

                  final user = await UserApi.instance.me();

                  final result = await ApiService.kakaoLogin(
                    token.accessToken,
                    user.kakaoAccount?.email ?? '',
                  );
                  print('result 전체: $result');

                  if (context.mounted) {
                    final data = result['data'] ?? {};
                    final role = data['role'] ?? result['role'];
                    final onboardingCompleted =
                        data['onboardingCompleted'] ??
                        result['onboardingCompleted'] ??
                        role == 'ROLE_USER';

                    if (onboardingCompleted != true) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SignUp(realName: ''),
                        ),
                      );
                    } else {
                      Navigator.pushReplacementNamed(context, '/home');
                    }
                  }
                } catch (e, s) {
                  print('카카오 로그인 오류: $e');
                  print('스택: $s');
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('로그인 오류: $e')));
                  }
                }
              },
              child: Image.asset(
                'assets/images/kakao_login_medium_narrow.png',
                width: 260,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
