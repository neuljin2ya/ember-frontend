import 'package:flutter/material.dart';
import 'api_service.dart';

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

    Navigator.pushReplacementNamed(context, '/socialLogin');
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
