import 'package:flutter/material.dart';
import 'api_service.dart';
import 'create_profile.dart';
import 'diary_screen.dart';
import 'main.dart' show registerFcmTokenToServer;
import 'tutorial_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final canContinue = await _checkVersion();
    if (!mounted || !canContinue) return;

    // 저장된 토큰으로 자동 로그인 시도
    final savedToken = await ApiService.getAccessToken();
    if (savedToken != null && savedToken.isNotEmpty) {
      try {
        final profile = await ApiService.getMyProfile();
        if (!mounted) return;
        registerFcmTokenToServer();
        await _routeBySignupProgress(profile);
        return;
      } catch (_) {
        // 토큰 만료/무효 → 로그인 화면으로
      }
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/socialLogin');
  }

  bool _hasCompletedProfile(Map<String, dynamic> profile) {
    bool filled(String key) =>
        profile[key]?.toString().trim().isNotEmpty == true;
    return filled('realName') &&
        filled('gender') &&
        filled('birthDate') &&
        filled('sido') &&
        filled('sigungu');
  }

  bool _hasAnyDiary(Map<String, dynamic> response) {
    final payload = response['data'];
    final data = payload is Map ? Map<String, dynamic>.from(payload) : response;
    final diaries = data['diaries'];
    return diaries is List && diaries.isNotEmpty;
  }

  bool _hasCompletedTutorial(Map<String, dynamic> profile) {
    if (!profile.containsKey('tutorialCompleted') &&
        !profile.containsKey('tutorialCompletedAt')) {
      return true;
    }
    if (profile['tutorialCompleted'] == true) return true;
    final completedAt = profile['tutorialCompletedAt']?.toString().trim();
    return completedAt != null && completedAt.isNotEmpty;
  }

  Future<void> _routeBySignupProgress(Map<String, dynamic> profile) async {
    if (!_hasCompletedProfile(profile)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const CreateProfile(realName: '')),
      );
      return;
    }

    if (!_hasCompletedTutorial(profile)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const TutorialScreen(requiredForSignup: true),
        ),
      );
      return;
    }

    final diaries = await ApiService.getMyDiaries();
    if (!mounted) return;
    if (!_hasAnyDiary(diaries)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const DiaryScreen(requiredForSignup: true),
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(context, '/home');
  }

  Future<bool> _checkVersion() async {
    try {
      final response = await ApiService.checkAppVersion(
        currentVersion: _currentVersion,
      );
      final data = response['data'];
      if (data is! Map) return true;

      final updateType = data['updateType']?.toString() ?? 'NONE';
      if (updateType == 'NONE') return true;

      final latestVersion = data['latestVersion']?.toString() ?? '';
      final storeUrl = data['storeUrl']?.toString() ?? '';
      final isForce = updateType == 'FORCE';
      if (!mounted) return false;

      final shouldContinue = await showDialog<bool>(
        context: context,
        barrierDismissible: !isForce,
        builder: (context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(
              isForce ? '업데이트가 필요해요' : '새 버전이 있어요',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF391713),
                fontSize: 18,
                fontFamily: 'Pretendard',
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Text(
              [
                if (latestVersion.isNotEmpty) '최신 버전: $latestVersion',
                '앱을 안정적으로 사용하려면 업데이트해주세요.',
                if (storeUrl.isNotEmpty) '\n스토어 주소:\n$storeUrl',
              ].join('\n'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF391713),
                fontSize: 13,
                fontFamily: 'Pretendard',
                height: 1.5,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              if (!isForce)
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    '나중에',
                    style: TextStyle(color: Color(0xFF8F8888)),
                  ),
                ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, !isForce),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE37474),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(isForce ? '확인' : '업데이트'),
              ),
            ],
          );
        },
      );

      return shouldContinue ?? !isForce;
    } catch (_) {
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF86A08A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 243,
              height: 243,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 16),
            const Text(
              'Ember',
              style: TextStyle(
                color: Color(0xFFE37474),
                fontSize: 64,
                fontFamily: 'LeagueSpartan',
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
