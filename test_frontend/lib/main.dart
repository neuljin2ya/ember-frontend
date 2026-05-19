import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';

// 백그라운드 메시지 핸들러 (top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM 백그라운드] ${message.notification?.title}: ${message.notification?.body}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  KakaoSdk.init(nativeAppKey: '033bc5c71a42c748495bf1ec7b0ef77e');
  runApp(const EmberTestApp());
}

class EmberTestApp extends StatelessWidget {
  const EmberTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppState().navigatorKey,
      title: 'Ember Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6B35),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ── 공통 상태 관리 ──
class AppState {
  static final AppState _instance = AppState._();
  factory AppState() => _instance;
  AppState._();

  final String baseUrl = 'https://ember-app.duckdns.org';
  final Dio dio = Dio();

  String? accessToken;
  String? refreshToken;
  String? kakaoAccessToken;
  int? userId;
  int onboardingStep = 0;
  bool onboardingCompleted = false;
  String? accountStatus;
  String? restoreToken;

  Options get authHeaders => Options(
    headers: {'Authorization': 'Bearer $accessToken'},
  );

  String errMsg(dynamic e) {
    if (e is DioException && e.response?.data != null) {
      final data = e.response!.data;
      if (data is Map) return '[${data['code']}] ${data['message']}';
    }
    return '$e';
  }

  // FCM 토큰 등록 + 포그라운드 알림 설정
  Future<void> setupFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      final token = await messaging.getToken();
      if (token != null && accessToken != null) {
        await dio.post('$baseUrl/api/users/me/fcm-token',
          data: {'token': token, 'deviceType': 'ANDROID'},
          options: authHeaders,
        );
        debugPrint('[FCM] 토큰 등록 완료: ${token.substring(0, 20)}...');
      }

      messaging.onTokenRefresh.listen((newToken) async {
        if (accessToken != null) {
          await dio.post('$baseUrl/api/users/me/fcm-token',
            data: {'token': newToken, 'deviceType': 'ANDROID'},
            options: authHeaders,
          );
          debugPrint('[FCM] 토큰 갱신 등록');
        }
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM 포그라운드] ${message.notification?.title}: ${message.notification?.body}');
        if (_navigatorKey.currentContext != null) {
          final ctx = _navigatorKey.currentContext!;
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text('${message.notification?.title ?? "알림"}: ${message.notification?.body ?? ""}'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(label: '확인', onPressed: () {}),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('[FCM] 설정 실패: $e');
    }
  }

  static final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;
}

// ══════════════════════════════════════
// 1.1 스플래시 및 자동 로그인
// ══════════════════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String status = '로딩 중...';

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  Future<void> _checkAutoLogin() async {
    await Future.delayed(const Duration(seconds: 2));
    final app = AppState();

    if (app.refreshToken == null) {
      setState(() => status = '로그인이 필요합니다');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _goToLogin();
      return;
    }

    try {
      final res = await app.dio.post('${app.baseUrl}/api/auth/refresh',
        data: {'refreshToken': app.refreshToken});
      app.accessToken = res.data['data']['accessToken'];
      app.refreshToken = res.data['data']['refreshToken'];
      if (mounted) _goToHome();
    } catch (e) {
      setState(() => status = '세션 만료');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _goToLogin();
    }
  }

  void _goToLogin() => Navigator.pushReplacement(
    context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  void _goToHome() => Navigator.pushReplacement(
    context, MaterialPageRoute(builder: (_) => const HomeScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔥', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Ember', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(status, style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// 2.2 소셜 로그인 (카카오)
// ══════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? message;
  bool loading = false;

  Future<void> _kakaoLogin() async {
    setState(() { loading = true; message = null; });
    final app = AppState();

    try {
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      app.kakaoAccessToken = token.accessToken;
      setState(() => message = '카카오 로그인 성공');

      final res = await app.dio.post('${app.baseUrl}/api/auth/social', data: {
        'provider': 'KAKAO',
        'socialToken': app.kakaoAccessToken,
      });
      final data = res.data['data'];
      app.accessToken = data['accessToken'];
      app.refreshToken = data['refreshToken'];
      app.userId = data['userId'];
      app.onboardingStep = data['onboardingStep'];
      app.onboardingCompleted = data['onboardingCompleted'];
      app.accountStatus = data['accountStatus'];
      app.restoreToken = data['restoreToken'];

      setState(() => message = '서버 로그인 성공! (userId=${data['userId']})');

      await app.setupFcm();

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (data['accountStatus'] == 'PENDING_DELETION') {
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const RestoreScreen()));
        } else if (data['isNewUser'] == true) {
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const ConsentScreen()));
        } else if (data['onboardingStep'] == 0) {
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
        } else if (data['onboardingStep'] == 1) {
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const IdealTypeScreen()));
        } else {
          Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } catch (e) {
      setState(() { message = app.errMsg(e); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text('Ember 시작하기', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('프로필 사진 없이, 내면을 먼저 보는 소개팅',
                style: TextStyle(color: Colors.white54), textAlign: TextAlign.center),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : _kakaoLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: Colors.black87,
                  ),
                  child: loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('카카오로 시작', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: loading ? null : () => _devLogin(8),
                  child: const Text('Dev 로그인 (건강한하늘)', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: loading ? null : () => _devLogin(9),
                  child: const Text('Dev 로그인 (맑은바다)', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: loading ? null : _devRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('신규 가입 시뮬레이션', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(message!, style: TextStyle(
                  color: message!.contains('성공') ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _devRegister() async {
    setState(() { loading = true; message = null; });
    final app = AppState();
    try {
      final res = await app.dio.post('${app.baseUrl}/api/dev/register');
      app.accessToken = res.data['accessToken'];
      app.userId = res.data['userId'];
      setState(() => message = '신규 유저 생성! (userId=${app.userId})');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const ConsentScreen()));
      }
    } catch (e) {
      setState(() { message = app.errMsg(e); loading = false; });
    }
  }

  Future<void> _devLogin(int userId) async {
    setState(() { loading = true; message = null; });
    final app = AppState();
    try {
      final res = await app.dio.get('${app.baseUrl}/api/dev/token', queryParameters: {'userId': userId});
      app.accessToken = res.data['accessToken'];
      app.userId = userId;
      setState(() => message = 'Dev 로그인 성공! (userId=$userId)');
      await app.setupFcm();
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } catch (e) {
      setState(() { message = app.errMsg(e); loading = false; });
    }
  }
}

// ══════════════════════════════════════
// 2.2 약관 동의 (신규 가입)
// ══════════════════════════════════════
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool userTerms = false;
  bool aiTerms = false;
  String? message;

  Future<void> _submit() async {
    final app = AppState();
    try {
      if (userTerms) {
        await app.dio.post('${app.baseUrl}/api/consent',
          data: {'consentType': 'AI_ANALYSIS'}, options: app.authHeaders);
      }
      if (aiTerms) {
        await app.dio.post('${app.baseUrl}/api/consent',
          data: {'consentType': 'AI_DATA_USAGE'}, options: app.authHeaders);
      }
      if (mounted) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
      }
    } catch (e) {
      setState(() => message = app.errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('약관 동의')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('서비스 이용을 위해\n약관에 동의해주세요',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            CheckboxListTile(
              title: const Text('서비스 이용약관 (필수)'),
              value: userTerms,
              onChanged: (v) => setState(() => userTerms = v!),
            ),
            CheckboxListTile(
              title: const Text('AI 분석 동의 (필수)'),
              value: aiTerms,
              onChanged: (v) => setState(() => aiTerms = v!),
            ),
            const Spacer(),
            if (message != null) Text(message!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: userTerms && aiTerms ? _submit : null,
                child: const Text('전체 동의 후 계속'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// 2.6 계정 복구
// ══════════════════════════════════════
class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber, size: 64, color: Colors.amber),
              const SizedBox(height: 16),
              const Text('탈퇴 유예 중인 계정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      final res = await app.dio.post('${app.baseUrl}/api/auth/restore',
                        data: {'restoreToken': app.restoreToken});
                      app.accessToken = res.data['data']['accessToken'];
                      app.refreshToken = res.data['data']['refreshToken'];
                      if (context.mounted) {
                        Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(app.errMsg(e))));
                      }
                    }
                  },
                  child: const Text('계정 복구'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
                child: const Text('탈퇴 진행', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// 3.1 기본 프로필 설정
// ══════════════════════════════════════
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final app = AppState();
  String nickname = '';
  final realNameCtrl = TextEditingController();
  final birthCtrl = TextEditingController(text: '2000-01-15');
  final schoolCtrl = TextEditingController();
  String gender = 'MALE';
  String sido = '경기도';
  String sigungu = '성남시';
  String? message;

  @override
  void initState() {
    super.initState();
    _generateNickname();
  }

  Future<void> _generateNickname() async {
    try {
      final res = await app.dio.post('${app.baseUrl}/api/users/nickname/generate');
      setState(() => nickname = res.data['data']['nickname']);
    } catch (e) {
      setState(() => message = app.errMsg(e));
    }
  }

  Future<void> _submit() async {
    try {
      await app.dio.post('${app.baseUrl}/api/users/profile',
        data: {
          'nickname': nickname,
          'realName': realNameCtrl.text,
          'birthDate': birthCtrl.text,
          'gender': gender,
          'sido': sido,
          'sigungu': sigungu,
          'school': schoolCtrl.text.isEmpty ? null : schoolCtrl.text,
        },
        options: app.authHeaders);
      if (mounted) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const IdealTypeScreen()));
      }
    } catch (e) {
      setState(() => message = app.errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('프로필 설정 (1/2)')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('기본 프로필 설정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(controller: realNameCtrl,
              decoration: const InputDecoration(labelText: '실명', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: InputDecorator(
                decoration: const InputDecoration(labelText: '닉네임', border: OutlineInputBorder()),
                child: Text(nickname.isEmpty ? '생성 중...' : nickname))),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _generateNickname, child: const Text('다시 생성')),
            ]),
            const SizedBox(height: 16),
            TextField(controller: birthCtrl,
              decoration: const InputDecoration(labelText: '생년월일 (YYYY-MM-DD)', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            const Text('성별'),
            Row(children: [
              ChoiceChip(label: const Text('남'), selected: gender == 'MALE',
                onSelected: (_) => setState(() => gender = 'MALE')),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text('여'), selected: gender == 'FEMALE',
                onSelected: (_) => setState(() => gender = 'FEMALE')),
            ]),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: '시/도', border: OutlineInputBorder()),
              controller: TextEditingController(text: sido),
              onChanged: (v) => sido = v),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(labelText: '시/군/구', border: OutlineInputBorder()),
              controller: TextEditingController(text: sigungu),
              onChanged: (v) => sigungu = v),
            const SizedBox(height: 16),
            TextField(controller: schoolCtrl,
              decoration: const InputDecoration(labelText: '학교 (선택)', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            if (message != null) Text(message!, style: const TextStyle(color: Colors.redAccent)),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: nickname.isNotEmpty && realNameCtrl.text.isNotEmpty ? _submit : null,
                child: const Text('다음'))),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// 3.2 이상형 키워드 설정
// ══════════════════════════════════════
class IdealTypeScreen extends StatefulWidget {
  const IdealTypeScreen({super.key});

  @override
  State<IdealTypeScreen> createState() => _IdealTypeScreenState();
}

class _IdealTypeScreenState extends State<IdealTypeScreen> {
  final app = AppState();
  List<dynamic> keywords = [];
  Set<int> selected = {};
  String? message;

  @override
  void initState() {
    super.initState();
    _loadKeywords();
  }

  Future<void> _loadKeywords() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/users/ideal-type/keyword-list');
      setState(() => keywords = res.data['data']['keywords']);
    } catch (e) {
      setState(() => message = app.errMsg(e));
    }
  }

  Future<void> _submit() async {
    try {
      await app.dio.post('${app.baseUrl}/api/users/ideal-type/keywords',
        data: {'keywordIds': selected.toList()}, options: app.authHeaders);
      if (mounted) {
        Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const TutorialScreen()));
      }
    } catch (e) {
      setState(() => message = app.errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이상형 설정 (2/2)')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('어떤 성격의 사람을\n원하시나요?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${selected.length}/3 선택됨', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: keywords.map((k) {
                final id = k['id'] as int;
                final isSelected = selected.contains(id);
                return FilterChip(
                  label: Text(k['label']),
                  selected: isSelected,
                  onSelected: (v) {
                    setState(() {
                      if (v && selected.length < 3) selected.add(id);
                      else selected.remove(id);
                    });
                  },
                );
              }).toList(),
            ),
            const Spacer(),
            if (message != null) Text(message!, style: const TextStyle(color: Colors.redAccent)),
            SizedBox(width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: selected.isNotEmpty ? _submit : null,
                child: const Text('시작하기'))),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// 3.3 튜토리얼
// ══════════════════════════════════════
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final app = AppState();
  final _pageController = PageController();
  int _currentPage = 0;
  bool _loading = true;
  List<Map<String, dynamic>> _pages = const [];

  // 서버 응답 비어있을 때 폴백
  static const List<Map<String, dynamic>> _fallback = [
    {'icon': '📝', 'title': '매일 일기 쓰기', 'body': '하루를 돌아보며 일기를 작성해보세요'},
    {'icon': '🤖', 'title': 'AI가 추천하는 상대', 'body': 'AI가 성격을 분석하고 맞는 상대를 추천해줍니다'},
    {'icon': '📖', 'title': '교환 일기로 관계 형성', 'body': '서로 일기를 교환하며 내면을 알아가세요'},
    {'icon': '💬', 'title': '채팅으로 만남', 'body': '교환이 끝나면 채팅으로 더 가까워지세요'},
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/tutorials/pages', options: app.authHeaders);
      final pages = (res.data['data']?['pages'] as List?) ?? [];
      final mapped = pages.map<Map<String, dynamic>>((p) => {
        'pageOrder': p['pageOrder'],
        'title': p['title'] ?? '',
        'body': p['body'] ?? '',
        'imageUrl': p['imageUrl'],
      }).toList()..sort((a, b) => (a['pageOrder'] ?? 0).compareTo(b['pageOrder'] ?? 0));
      setState(() {
        _pages = mapped.isEmpty ? _fallback : mapped;
        _loading = false;
      });
    } catch (_) {
      setState(() { _pages = _fallback; _loading = false; });
    }
  }

  Future<void> _finish() async {
    try {
      await app.dio.post('${app.baseUrl}/api/users/tutorial/complete', options: app.authHeaders);
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // 페이지 인디케이터
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: i == _currentPage ? 24 : 8, height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: i == _currentPage ? Colors.orange : Colors.white24),
              )),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, index) {
                final page = _pages[index];
                final imageUrl = page['imageUrl'] as String?;
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Image.network(imageUrl, width: 200, errorBuilder: (_, __, ___) =>
                          Text(page['icon'] ?? '✨', style: const TextStyle(fontSize: 80)))
                      else
                        Text(page['icon'] ?? '✨', style: const TextStyle(fontSize: 80)),
                      const SizedBox(height: 32),
                      Text(page['title'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      Text(page['body'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
                      const Spacer(),
                    ],
                  ),
                );
              },
            ),
          ),
          // 하단 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
            child: Column(children: [
              SizedBox(width: double.infinity, height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage == _pages.length - 1) {
                      _finish();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut);
                    }
                  },
                  child: Text(_currentPage == _pages.length - 1 ? '시작하기' : '다음'),
                ),
              ),
              TextButton(
                onPressed: _finish,
                child: const Text('건너뛰기', style: TextStyle(color: Colors.white54))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════
// 홈 화면 (4탭 구조)
// ══════════════════════════════════════
class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int _currentTab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentTab,
        children: const [
          DiaryUnifiedTab(),
          ExploreTab(),
          CommunicationTab(),
          MoreTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.auto_stories), label: '일기'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: '탐색'),
          BottomNavigationBarItem(icon: Icon(Icons.forum), label: '소통'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: '더보기'),
        ],
      ),
    );
  }
}

// ── 일기 통합 탭 (작성 / 히스토리 / 임시저장) ──
class DiaryUnifiedTab extends StatefulWidget {
  const DiaryUnifiedTab({super.key});

  @override
  State<DiaryUnifiedTab> createState() => _DiaryUnifiedTabState();
}

class _DiaryUnifiedTabState extends State<DiaryUnifiedTab> {
  int _subIndex = 0;

  static const _labels = ['작성', '히스토리', '임시저장'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔥 일기'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SegmentedButton<int>(
              segments: List.generate(_labels.length, (i) =>
                ButtonSegment<int>(value: i, label: Text(_labels[i]))),
              selected: {_subIndex},
              onSelectionChanged: (s) => setState(() => _subIndex = s.first),
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _subIndex,
        children: const [
          _DiaryWriteBody(),
          _DiaryHistoryBody(),
          _DraftBody(),
        ],
      ),
    );
  }
}

// ── 소통 통합 탭 (교환일기 / 채팅) ──
class CommunicationTab extends StatefulWidget {
  const CommunicationTab({super.key});

  @override
  State<CommunicationTab> createState() => _CommunicationTabState();
}

class _CommunicationTabState extends State<CommunicationTab> {
  int _subIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('소통'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(value: 0, label: Text('교환일기'), icon: Icon(Icons.swap_horiz, size: 16)),
                ButtonSegment<int>(value: 1, label: Text('채팅'), icon: Icon(Icons.chat_bubble, size: 16)),
              ],
              selected: {_subIndex},
              onSelectionChanged: (s) => setState(() => _subIndex = s.first),
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _subIndex,
        children: const [
          _ExchangeBody(),
          _ChatBody(),
        ],
      ),
    );
  }
}

// ── 일기 작성 바디 래퍼 (DiaryUnifiedTab 내부용) ──
class _DiaryWriteBody extends StatelessWidget {
  const _DiaryWriteBody();
  @override
  Widget build(BuildContext context) => const DiaryWriteTab(standaloneAppBar: false);
}

// ── 4.1 일기 작성 탭 ──
class DiaryWriteTab extends StatefulWidget {
  final bool standaloneAppBar;
  const DiaryWriteTab({super.key, this.standaloneAppBar = true});

  @override
  State<DiaryWriteTab> createState() => _DiaryWriteTabState();
}

class _DiaryWriteTabState extends State<DiaryWriteTab> {
  final app = AppState();
  final contentCtrl = TextEditingController();
  bool? todayExists;
  int? todayDiaryId;
  String? message;
  bool isEdit = false;
  String? weeklyTopic;
  bool aiLoading = false;
  Map<String, dynamic>? aiResult;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_checkToday(), _loadWeeklyTopic()]);
    if (todayExists != true) {
      await _checkDrafts();
    }
  }

  Future<void> _loadWeeklyTopic() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/diaries/weekly-topic', options: app.authHeaders);
      final data = res.data['data'];
      if (data != null && data['topic'] != null) {
        setState(() => weeklyTopic = data['topic']);
      }
    } catch (_) {}
  }

  Future<void> _checkToday() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/diaries/today', options: app.authHeaders);
      final data = res.data['data'];
      setState(() {
        todayExists = data['exists'];
        todayDiaryId = data['diaryId'];
      });
      if (todayExists == true && todayDiaryId != null) {
        final detail = await app.dio.get('${app.baseUrl}/api/diaries/$todayDiaryId', options: app.authHeaders);
        contentCtrl.text = detail.data['data']['content'];
        setState(() => isEdit = detail.data['data']['isEditable']);
      }
    } catch (e) {
      setState(() => message = app.errMsg(e));
    }
  }

  Future<void> _checkDrafts() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/diaries/drafts', options: app.authHeaders);
      final drafts = res.data['data']['drafts'] as List;
      if (drafts.isNotEmpty && mounted) {
        final latest = drafts.first;
        final result = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('임시저장된 일기가 있어요'),
            content: Text('${latest['content'].toString().substring(0, latest['content'].toString().length > 50 ? 50 : latest['content'].toString().length)}...\n\n이어서 작성하시겠어요?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('새로 시작')),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('이어쓰기')),
            ],
          ),
        );
        if (result == true) {
          contentCtrl.text = latest['content'];
          setState(() {});
        }
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    try {
      if (todayExists == true && todayDiaryId != null) {
        await app.dio.patch('${app.baseUrl}/api/diaries/$todayDiaryId',
          data: {'content': contentCtrl.text}, options: app.authHeaders);
        setState(() => message = '일기 수정 완료!');
      } else {
        final res = await app.dio.post('${app.baseUrl}/api/diaries',
          data: {'content': contentCtrl.text, 'visibility': 'PRIVATE'}, options: app.authHeaders);
        final diaryId = res.data['data']['diaryId'];
        setState(() {
          message = '일기 작성 완료! (id=$diaryId)';
          todayExists = true;
          todayDiaryId = diaryId;
          aiLoading = true;
          aiResult = null;
        });
        _runAiAnalysis(diaryId);
      }
    } catch (e) {
      setState(() => message = app.errMsg(e));
    }
  }

  Future<void> _runAiAnalysis(int diaryId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 800));
      await app.dio.post('${app.baseUrl}/api/dev/ai/simulate/$diaryId');
      for (int i = 0; i < 8; i++) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        final res = await app.dio.get('${app.baseUrl}/api/diaries/$diaryId', options: app.authHeaders);
        final data = res.data['data'] as Map<String, dynamic>;
        if (data['summary'] != null || (data['emotionTags'] as List?)?.isNotEmpty == true) {
          setState(() {
            aiLoading = false;
            aiResult = data;
          });
          return;
        }
      }
      if (mounted) setState(() => aiLoading = false);
    } catch (_) {
      if (mounted) setState(() => aiLoading = false);
    }
  }

  Widget _aiCard() {
    if (aiLoading) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.purple.withOpacity(0.15),
            Colors.pink.withOpacity(0.15),
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple.withOpacity(0.4)),
        ),
        child: Row(children: const [
          SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('AI가 일기를 분석하고 있어요...',
            style: TextStyle(fontWeight: FontWeight.bold))),
        ]),
      );
    }
    if (aiResult == null) return const SizedBox.shrink();
    final r = aiResult!;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.purple.withOpacity(0.18),
          Colors.pink.withOpacity(0.12),
        ]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 18),
            SizedBox(width: 6),
            Text('AI 분석 결과', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 10),
          if (r['summary'] != null) ...[
            const Text('요약', style: TextStyle(fontSize: 11, color: Colors.white70)),
            const SizedBox(height: 2),
            Text(r['summary'], style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
          ],
          if (r['category'] != null) ...[
            _aiChipRow('카테고리', [r['category']], Colors.orange),
            const SizedBox(height: 6),
          ],
          _aiChipRow('감정', r['emotionTags'], Colors.pink),
          _aiChipRow('라이프스타일', r['lifestyleTags'], Colors.teal),
          _aiChipRow('글쓰기 톤', r['toneTags'], Colors.amber),
        ],
      ),
    );
  }

  Widget _aiChipRow(String label, dynamic tags, Color color) {
    final list = tags is List ? tags : const [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: list.map((t) =>
            Chip(
              label: Text(t.toString(), style: const TextStyle(fontSize: 11)),
              backgroundColor: color.withOpacity(0.25),
              side: BorderSide(color: color.withOpacity(0.5)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            )).toList().cast<Widget>()),
        ],
      ),
    );
  }

  Future<void> _saveDraft() async {
    try {
      await app.dio.post('${app.baseUrl}/api/diaries/draft',
        data: {'content': contentCtrl.text}, options: app.authHeaders);
      setState(() => message = '임시저장 완료!');
    } catch (e) {
      setState(() => message = app.errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final charCount = contentCtrl.text.length;
    final isValid = charCount >= 200 && charCount <= 1000;
    final progress = (charCount / 1000).clamp(0.0, 1.0);
    final weekday = ['월','화','수','목','금','토','일'][now.weekday - 1];
    final hasAi = aiLoading || aiResult != null;

    return Scaffold(
      appBar: widget.standaloneAppBar ? AppBar(
        title: const Text('오늘의 일기'),
        actions: [
          if (todayExists == true)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Chip(label: Text('작성됨', style: TextStyle(fontSize: 11))),
            ),
        ],
      ) : null,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── 날짜 헤더 카드 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.15),
                    Colors.deepOrange.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.25)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_calendar, color: Colors.orangeAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('${now.year}년 ${now.month}월 ${now.day}일',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  Text('$weekday요일 · ${todayExists == true ? "오늘 작성한 일기" : "오늘의 기록"}',
                    style: const TextStyle(fontSize: 11, color: Colors.white60)),
                ]),
              ]),
            ),

            // ── 주간 주제 카드 (수요일) ──
            if (weeklyTopic != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.amber.withOpacity(0.15),
                    Colors.orange.withOpacity(0.1),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.35)),
                ),
                child: Row(children: [
                  const Icon(Icons.lightbulb, color: Colors.amber, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    const Text('이번 주의 주제', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(weeklyTopic!, style: const TextStyle(fontSize: 14, color: Colors.amberAccent, fontWeight: FontWeight.w600)),
                  ])),
                ]),
              ),

            // ── 일기 본문 ──
            if (hasAi)
              SizedBox(
                height: 140,
                child: _diaryField(),
              )
            else
              Expanded(child: _diaryField()),

            const SizedBox(height: 10),

            // ── 글자수 progress bar ──
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isValid ? Colors.greenAccent : (charCount < 200 ? Colors.orangeAccent : Colors.redAccent),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Text('$charCount자',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: isValid ? Colors.greenAccent : (charCount < 200 ? Colors.orangeAccent : Colors.redAccent),
                )),
              const SizedBox(width: 4),
              Text(charCount < 200 ? '· 200자 이상 필요' : charCount > 1000 ? '· 1000자 초과' : '· 작성 완료',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const Spacer(),
              const Text('1000자', style: TextStyle(fontSize: 11, color: Colors.white38)),
            ]),

            const SizedBox(height: 12),

            // ── 제출/임시저장 버튼 ──
            Row(children: [
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _saveDraft,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: const Text('임시저장'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: isValid ? _submit : null,
                  icon: Icon(todayExists == true ? Icons.edit : Icons.check_circle, size: 20),
                  label: Text(todayExists == true ? '일기 수정' : '오늘 일기 제출',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[800],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )),
            ]),

            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(children: [
                  Icon(message!.contains('완료') ? Icons.check_circle : Icons.error_outline,
                    size: 14, color: message!.contains('완료') ? Colors.greenAccent : Colors.redAccent),
                  const SizedBox(width: 4),
                  Expanded(child: Text(message!,
                    style: TextStyle(fontSize: 12,
                      color: message!.contains('완료') ? Colors.greenAccent : Colors.redAccent))),
                ]),
              ),

            if (hasAi)
              Expanded(child: SingleChildScrollView(child: _aiCard())),
          ],
        ),
      ),
    );
  }

  Widget _diaryField() => TextField(
    controller: contentCtrl,
    maxLines: null,
    expands: true,
    textAlignVertical: TextAlignVertical.top,
    onChanged: (_) => setState(() {}),
    style: const TextStyle(fontSize: 14.5, height: 1.7),
    decoration: InputDecoration(
      hintText: '오늘 하루를 돌아보며 일기를 써보세요...\n(200~1,000자)',
      hintStyle: TextStyle(color: Colors.grey[600]),
      filled: true,
      fillColor: Colors.grey[900]?.withOpacity(0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey[800]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.orangeAccent, width: 1.5),
      ),
      contentPadding: const EdgeInsets.all(14),
    ),
  );
}

// ── 일기 히스토리 바디 래퍼 ──
class _DiaryHistoryBody extends StatelessWidget {
  const _DiaryHistoryBody();
  @override
  Widget build(BuildContext context) => const DiaryHistoryTab(standaloneAppBar: false);
}

// ── 4.4 일기 히스토리 탭 ──
class DiaryHistoryTab extends StatefulWidget {
  final bool standaloneAppBar;
  const DiaryHistoryTab({super.key, this.standaloneAppBar = true});

  @override
  State<DiaryHistoryTab> createState() => _DiaryHistoryTabState();
}

class _DiaryHistoryTabState extends State<DiaryHistoryTab> {
  final app = AppState();
  List<dynamic> diaries = [];
  String? message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/diaries', options: app.authHeaders);
      setState(() => diaries = res.data['data']['diaries']);
    } catch (e) {
      setState(() => message = app.errMsg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.standaloneAppBar ? AppBar(title: const Text('나의 일기')) : null,
      body: diaries.isEmpty
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.book_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 12),
              Text(message ?? '아직 일기가 없어요', style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              const Text('오늘의 일기를 작성해보세요', style: TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: diaries.length,
              itemBuilder: (context, index) {
                final d = diaries[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    title: Text(d['contentPreview'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Row(children: [
                      Text(d['createdAt']?.toString().substring(0, 10) ?? ''),
                      if (d['summary'] != null) ...[
                        const SizedBox(width: 8),
                        Chip(label: Text(d['category'] ?? '', style: const TextStyle(fontSize: 10))),
                      ],
                    ]),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      try {
                        final res = await app.dio.get(
                          '${app.baseUrl}/api/diaries/${d['diaryId']}', options: app.authHeaders);
                        if (context.mounted) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => DiaryDetailScreen(diary: res.data['data'])));
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(app.errMsg(e))));
                        }
                      }
                    },
                  ),
                );
              },
            ),
          ),
    );
  }
}

// ── 4.4 일기 상세 ──
class DiaryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> diary;
  const DiaryDetailScreen({super.key, required this.diary});

  @override
  Widget build(BuildContext context) {
    final createdAt = diary['createdAt'] as String?;
    final dateStr = createdAt != null && createdAt.length >= 10
      ? createdAt.substring(0, 10) : '';
    final hasAi = diary['summary'] != null || diary['emotionTags'] != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('일기 상세'),
        actions: [
          if (diary['isEditable'] == true)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Chip(label: Text('수정 가능', style: TextStyle(fontSize: 11, color: Colors.greenAccent))),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 날짜 헤더 카드 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.orange.withOpacity(0.15),
                  Colors.deepOrange.withOpacity(0.08),
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.25)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book, color: Colors.orangeAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(dateStr.isNotEmpty ? dateStr.replaceAll('-', '. ') : '나의 일기',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('${(diary['content'] as String?)?.length ?? 0}자',
                    style: const TextStyle(fontSize: 11, color: Colors.white60)),
                ])),
              ]),
            ),

            const SizedBox(height: 16),

            // ── 일기 본문 카드 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900]?.withOpacity(0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: Text(diary['content'] ?? '',
                style: const TextStyle(fontSize: 15, height: 1.8, letterSpacing: 0.2)),
            ),

            const SizedBox(height: 20),

            // ── AI 분석 섹션 ──
            Row(children: [
              const Icon(Icons.auto_awesome, size: 18, color: Colors.purpleAccent),
              const SizedBox(width: 6),
              const Text('AI 분석', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              if (!hasAi)
                Text('분석 중...', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
            const SizedBox(height: 10),

            if (hasAi)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.purple.withOpacity(0.12),
                    Colors.pink.withOpacity(0.08),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (diary['summary'] != null) ...[
                    const Text('요약', style: TextStyle(fontSize: 10, color: Colors.white60)),
                    const SizedBox(height: 4),
                    Text(diary['summary'], style: const TextStyle(fontSize: 13, height: 1.5)),
                    const SizedBox(height: 12),
                  ],
                  if (diary['category'] != null) ...[
                    Row(children: [
                      const Text('카테고리: ', style: TextStyle(fontSize: 11, color: Colors.white60)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(diary['category'], style: const TextStyle(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                  ],
                  _detailTagRow('감정', diary['emotionTags'], Colors.pink),
                  _detailTagRow('라이프스타일', diary['lifestyleTags'], Colors.teal),
                  _detailTagRow('글쓰기 톤', diary['toneTags'], Colors.amber),
                ]),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[900]?.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [
                  const SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
                  ),
                  const SizedBox(height: 10),
                  Text('AI가 일기를 분석하고 있어요',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('잠시 후 다시 확인해주세요',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                ]),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailTagRow(String label, dynamic tags, Color color) {
    final list = tags is List ? tags : const [];
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white60)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, children: list.map((t) {
          final txt = t is Map ? (t['label'] ?? t['name'] ?? '').toString() : t.toString();
          return Chip(
            label: Text(txt, style: const TextStyle(fontSize: 11)),
            backgroundColor: color.withOpacity(0.25),
            side: BorderSide(color: color.withOpacity(0.5)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        }).toList()),
      ]),
    );
  }
}

// ── 임시저장 바디 래퍼 ──
class _DraftBody extends StatelessWidget {
  const _DraftBody();
  @override
  Widget build(BuildContext context) => const DraftTab(standaloneAppBar: false);
}

// ── 임시저장 탭 ──
class DraftTab extends StatefulWidget {
  final bool standaloneAppBar;
  const DraftTab({super.key, this.standaloneAppBar = true});

  @override
  State<DraftTab> createState() => _DraftTabState();
}

class _DraftTabState extends State<DraftTab> {
  final app = AppState();
  List<dynamic> drafts = [];
  String? message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/diaries/drafts', options: app.authHeaders);
      setState(() => drafts = res.data['data']['drafts']);
    } catch (e) {
      setState(() => message = app.errMsg(e));
    }
  }

  Future<void> _deleteDraft(int draftId) async {
    try {
      await app.dio.delete('${app.baseUrl}/api/diaries/draft/$draftId', options: app.authHeaders);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.standaloneAppBar ? AppBar(title: Text('임시저장 (${drafts.length}/3)')) : null,
      body: drafts.isEmpty
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.drafts_outlined, size: 64, color: Colors.white24),
              const SizedBox(height: 12),
              Text(message ?? '임시저장된 일기가 없어요', style: const TextStyle(color: Colors.white54)),
            ],
          ))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: drafts.length,
              itemBuilder: (context, index) {
                final d = drafts[index];
                return Dismissible(
                  key: Key('${d['draftId']}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red, alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white)),
                  onDismissed: (_) => _deleteDraft(d['draftId']),
                  child: Card(
                    child: ListTile(
                      title: Text(d['content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(d['savedAt']?.toString().substring(0, 16) ?? ''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _deleteDraft(d['draftId']),
                          ),
                          const Text('← 밀어서 삭제', style: TextStyle(fontSize: 10, color: Colors.white38)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
    );
  }
}

// ══════════════════════════════════════
// 도메인 5. 매칭 탐색
// ══════════════════════════════════════

// ── 5.1 일기 탐색 탭 ──
class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> with SingleTickerProviderStateMixin {
  final app = AppState();
  late final TabController _tabController;

  // 최신 탭 상태
  List<dynamic> latestDiaries = [];
  int? latestCursor;
  bool latestLoading = false;
  String? latestMessage;

  // 추천 탭 상태
  List<dynamic> recommendations = [];
  bool recoLoading = false;
  String? recoMessage;

  // 필터 (최신 탭에만 적용)
  final Set<String> selectedAgeGroups = {};
  String? selectedSido;
  String? selectedCategory;
  bool keywordFilter = false;

  static const List<String> sidoOptions = [
    '서울', '경기', '인천', '강원', '충북', '충남', '대전', '세종',
    '전북', '전남', '광주', '경북', '경남', '대구', '울산', '부산', '제주',
  ];
  static const List<String> categoryOptions = ['일상', '감성', '성장', '관계', '기타'];
  static const Map<String, String> ageGroupLabels = {
    'TEENS': '10대', 'TWENTIES': '20대', 'THIRTIES': '30대', 'FORTIES': '40대',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadLatest();
    _loadRecommendations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLatest({bool reset = false}) async {
    if (reset) latestCursor = null;
    setState(() => latestLoading = true);
    try {
      final query = <String, dynamic>{'sort': 'latest', 'size': 10};
      if (latestCursor != null) query['cursor'] = latestCursor;
      if (selectedAgeGroups.isNotEmpty) query['ageGroup'] = selectedAgeGroups.join(',');
      if (selectedSido != null) query['sido'] = selectedSido;
      if (selectedCategory != null) query['category'] = selectedCategory;
      if (keywordFilter) query['keywordFilter'] = true;

      final res = await app.dio.get('${app.baseUrl}/api/diaries/explore',
        options: app.authHeaders, queryParameters: query);
      final data = res.data['data'];
      setState(() {
        if (reset || latestCursor == null) {
          latestDiaries = data['diaries'] ?? [];
        } else {
          latestDiaries.addAll(data['diaries'] ?? []);
        }
        latestCursor = data['nextCursor'];
        latestMessage = data['guidanceMessage'];
        latestLoading = false;
      });
    } catch (e) {
      setState(() { latestMessage = app.errMsg(e); latestLoading = false; });
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() => recoLoading = true);
    try {
      final res = await app.dio.get('${app.baseUrl}/api/matching/recommendations',
        options: app.authHeaders);
      final data = res.data['data'];
      setState(() {
        recommendations = (data is Map ? data['recommendations'] : data) ?? [];
        recoMessage = data is Map ? data['guidanceMessage'] : null;
        recoLoading = false;
      });
    } catch (e) {
      setState(() { recoMessage = app.errMsg(e); recoLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일기 탐색'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome, size: 18), text: '추천'),
            Tab(icon: Icon(Icons.schedule, size: 18), text: '최신'),
          ],
        ),
        actions: [
          // 필터는 최신 탭에서만 동작
          if (_tabController.index == 1)
            IconButton(icon: const Icon(Icons.tune), onPressed: _showFilterSheet, tooltip: '필터'),
          IconButton(icon: const Icon(Icons.mail_outline), onPressed: _showReceivedRequests, tooltip: '받은 요청'),
          IconButton(icon: const Icon(Icons.analytics_outlined), onPressed: _showLifestyleReport, tooltip: '라이프스타일'),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRecommendationsTab(),
          _buildLatestTab(),
        ],
      ),
    );
  }

  // ── 추천 탭 (블러 카드) ──
  Widget _buildRecommendationsTab() {
    if (recoLoading) return const Center(child: CircularProgressIndicator());
    if (recommendations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadRecommendations,
        child: ListView(children: [
          const SizedBox(height: 60),
          const Icon(Icons.auto_awesome, size: 64, color: Colors.white24),
          const SizedBox(height: 12),
          Center(child: Text(recoMessage ?? 'AI 추천 결과가 없습니다',
            style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center)),
          const SizedBox(height: 8),
          const Center(child: Text('일기를 더 작성하면 정확한 추천이 가능해요',
            style: TextStyle(color: Colors.white38, fontSize: 12))),
          const SizedBox(height: 24),
          // 디버그/안내 정보
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: const [
                  Icon(Icons.info_outline, size: 14, color: Colors.amber),
                  SizedBox(width: 6),
                  Text('추천이 비어있는 이유?', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 6),
                const Text(
                  '• 누적 일기 3편 미만 (M001)\n'
                  '• AI 분석 동의 미완료 (M004)\n'
                  '• 유사도 0.5 미만 후보 (5.2 비고)\n'
                  '• 일일 추천 한도 10개 초과 (M003)\n'
                  '• 매칭 가능한 다른 사용자 없음',
                  style: TextStyle(fontSize: 11, color: Colors.white60, height: 1.5),
                ),
              ]),
            ),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadRecommendations,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: recommendations.length,
        itemBuilder: (_, i) => _recommendationCard(recommendations[i]),
      ),
    );
  }

  Widget _recommendationCard(Map<String, dynamic> r) {
    final score = r['matchScore'];
    final scorePct = score is num ? (score * 100).toInt() : null;
    final badge = r['similarityBadge'] as String?;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openRecommendationPreview(r),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.lock_outline, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(r['ageGroup'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _badgeColor(badge).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    scorePct != null ? '$badge · $scorePct%' : badge,
                    style: TextStyle(color: _badgeColor(badge), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            // AI 요약 (블러)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: Colors.black.withOpacity(0.25),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Text(
                      (r['previewContent'] ?? r['summary'] ?? 'AI 분석 중...') as String,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
                      ),
                    ),
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.only(bottom: 6),
                    child: const Icon(Icons.lock_outline, size: 14, color: Colors.white70),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            if (r['briefing'] != null || r['aiIntro'] != null)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, size: 12, color: Colors.purpleAccent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(r['briefing'] ?? r['aiIntro'] ?? '',
                    style: const TextStyle(fontSize: 11, color: Colors.purpleAccent))),
                ]),
              ),
            const SizedBox(height: 8),

            // 이상형 매칭 키워드 (matchedKeywords)
            if ((r['matchedKeywords'] as List?)?.isNotEmpty == true) ...[
              Row(children: [
                const Icon(Icons.favorite, size: 11, color: Colors.redAccent),
                const SizedBox(width: 4),
                Text('이상형 매칭: ${(r['matchedKeywords'] as List).join(", ")}',
                  style: const TextStyle(fontSize: 10, color: Colors.redAccent)),
              ]),
              const SizedBox(height: 6),
            ],

            Wrap(spacing: 4, runSpacing: 4, children: [
              ...((r['personalityKeywords'] as List?) ?? []).take(3).map((k) =>
                Chip(label: Text('#$k', style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.purple.withOpacity(0.2))),
              ...((r['emotionTags'] as List?) ?? []).take(2).map((t) =>
                Chip(label: Text(t, style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.pink.withOpacity(0.2))),
              if (r['category'] != null)
                Chip(label: Text(r['category'], style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.orange.withOpacity(0.2)),
            ]),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openRecommendationPreview(r),
                icon: const Icon(Icons.lock_open, size: 14),
                label: const Text('자세히 보기', style: TextStyle(fontSize: 12)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Color _badgeColor(String badge) {
    switch (badge.toUpperCase()) {
      case 'HIGH': return Colors.greenAccent;
      case 'MEDIUM': case 'MID': return Colors.amberAccent;
      case 'LOW': return Colors.blueAccent;
      default: return Colors.white70;
    }
  }

  // ── 최신 탭 (풀 카드) ──
  Widget _buildLatestTab() {
    if (latestLoading && latestDiaries.isEmpty) return const Center(child: CircularProgressIndicator());

    final hasFilters = selectedAgeGroups.isNotEmpty ||
      selectedSido != null || selectedCategory != null || keywordFilter;

    return Column(children: [
      // 활성 필터 칩
      if (hasFilters)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.orange.withOpacity(0.05),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            ...selectedAgeGroups.map((g) => _filterChip(ageGroupLabels[g] ?? g, () {
              setState(() => selectedAgeGroups.remove(g));
              _loadLatest(reset: true);
            })),
            if (selectedSido != null)
              _filterChip(selectedSido!, () {
                setState(() => selectedSido = null);
                _loadLatest(reset: true);
              }),
            if (selectedCategory != null)
              _filterChip(selectedCategory!, () {
                setState(() => selectedCategory = null);
                _loadLatest(reset: true);
              }),
            if (keywordFilter)
              _filterChip('이상형 매칭만', () {
                setState(() => keywordFilter = false);
                _loadLatest(reset: true);
              }),
          ]),
        ),
      Expanded(
        child: latestDiaries.isEmpty
          ? RefreshIndicator(
              onRefresh: () => _loadLatest(reset: true),
              child: ListView(children: [
                const SizedBox(height: 100),
                Center(child: Text(latestMessage ?? '조건에 맞는 일기가 없습니다',
                  style: const TextStyle(color: Colors.white54))),
              ]),
            )
          : RefreshIndicator(
              onRefresh: () => _loadLatest(reset: true),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: latestDiaries.length,
                itemBuilder: (_, i) => _latestCard(latestDiaries[i]),
              ),
            ),
      ),
    ]);
  }

  Widget _filterChip(String label, VoidCallback onRemove) => Chip(
    label: Text(label, style: const TextStyle(fontSize: 11)),
    deleteIcon: const Icon(Icons.close, size: 14),
    onDeleted: onRemove,
    backgroundColor: Colors.orange.withOpacity(0.2),
    side: BorderSide(color: Colors.orange.withOpacity(0.4)),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _latestCard(Map<String, dynamic> d) {
    final badge = d['similarityBadge'] as String?;
    // 카드엔 AI 요약(summary)만 살짝 보이게 노출. 전문은 상세에서.
    final teaser = (d['summary'] ?? d['previewContent'] ?? '') as String;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDiaryDetail(d),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Colors.orange.withOpacity(0.2),
                child: const Icon(Icons.person, size: 16, color: Colors.orangeAccent),
              ),
              const SizedBox(width: 8),
              Text(d['ageGroupLabel'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              if (d['region'] != null) ...[
                const Text(' · ', style: TextStyle(color: Colors.white38)),
                Text(d['region'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _badgeColor(badge).withOpacity(0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.favorite, size: 11, color: _badgeColor(badge)),
                    const SizedBox(width: 3),
                    Text(badge, style: TextStyle(color: _badgeColor(badge), fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                ),
            ]),
            const SizedBox(height: 10),

            // AI 요약 (블러 처리 + 잠금 오버레이)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  color: Colors.black.withOpacity(0.25),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Text(
                      teaser.isEmpty ? 'AI 분석 중...' : teaser,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.35)],
                      ),
                    ),
                    alignment: Alignment.bottomRight,
                    padding: const EdgeInsets.all(6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.lock_outline, size: 12, color: Colors.white70),
                      SizedBox(width: 4),
                      Text('탭하여 자세히 보기',
                        style: TextStyle(fontSize: 10, color: Colors.white70)),
                    ]),
                  ),
                ),
              ]),
            ),

            const SizedBox(height: 10),
            Wrap(spacing: 4, runSpacing: 4, children: [
              ...((d['personalityKeywords'] as List?) ?? []).take(3).map((k) =>
                Chip(label: Text('#$k', style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.purple.withOpacity(0.2))),
              ...((d['moodTags'] as List?) ?? []).take(2).map((t) =>
                Chip(label: Text(t, style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.pink.withOpacity(0.2))),
              if (d['category'] != null)
                Chip(label: Text(d['category'], style: const TextStyle(fontSize: 10)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: Colors.orange.withOpacity(0.2)),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── 필터 바텀시트 ──
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Center(child: Text('필터 설정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(height: 16),
            const Text('연령대 (복수 선택)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: ageGroupLabels.entries.map((e) =>
              FilterChip(
                label: Text(e.value),
                selected: selectedAgeGroups.contains(e.key),
                onSelected: (v) => setLocal(() {
                  if (v) selectedAgeGroups.add(e.key);
                  else selectedAgeGroups.remove(e.key);
                }),
              )).toList()),
            const SizedBox(height: 16),
            const Text('지역', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            DropdownButton<String?>(
              value: selectedSido,
              isExpanded: true,
              hint: const Text('전체'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('전체')),
                ...sidoOptions.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
              ],
              onChanged: (v) => setLocal(() => selectedSido = v),
            ),
            const SizedBox(height: 8),
            const Text('카테고리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            DropdownButton<String?>(
              value: selectedCategory,
              isExpanded: true,
              hint: const Text('전체'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('전체')),
                ...categoryOptions.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
              ],
              onChanged: (v) => setLocal(() => selectedCategory = v),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('이상형 키워드 필터', style: TextStyle(fontSize: 13)),
              subtitle: const Text('내 이상형 키워드와 일치하는 일기만 보기',
                style: TextStyle(fontSize: 11, color: Colors.white54)),
              value: keywordFilter,
              activeColor: Colors.orangeAccent,
              onChanged: (v) => setLocal(() => keywordFilter = v),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () {
                  setLocal(() {
                    selectedAgeGroups.clear();
                    selectedSido = null;
                    selectedCategory = null;
                    keywordFilter = false;
                  });
                },
                child: const Text('초기화'),
              )),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {});
                  _loadLatest(reset: true);
                  final parts = <String>[];
                  if (selectedAgeGroups.isNotEmpty) parts.add('연령: ${selectedAgeGroups.map((g) => ageGroupLabels[g]).join(",")}');
                  if (selectedSido != null) parts.add('지역: $selectedSido');
                  if (selectedCategory != null) parts.add('카테고리: $selectedCategory');
                  if (keywordFilter) parts.add('이상형 매칭');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(parts.isEmpty ? '필터 없이 조회' : '필터 적용: ${parts.join(" · ")}'),
                    duration: const Duration(seconds: 2),
                  ));
                },
                child: const Text('적용'),
              )),
            ]),
          ]),
        );
      }),
    );
  }

  // ── 액션 ──
  void _showDiaryDetail(Map<String, dynamic> d) async {
    try {
      final detailRes = await app.dio.get(
        '${app.baseUrl}/api/diaries/${d['diaryId']}/detail',
        options: app.authHeaders);
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ExploreDetailScreen(
            diaryId: d['diaryId'], preview: detailRes.data['data'])));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
      }
    }
  }

  void _openRecommendationPreview(Map<String, dynamic> r) async {
    final diaryId = r['diaryId'];
    if (diaryId == null) return;
    try {
      final res = await app.dio.get(
        '${app.baseUrl}/api/matching/recommendations/$diaryId/preview',
        options: app.authHeaders);
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ExploreDetailScreen(diaryId: diaryId, preview: res.data['data'])));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
      }
    }
  }

  void _showReceivedRequests() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/matching/requests',
        options: app.authHeaders);
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ReceivedRequestsScreen(requests: res.data['data'] ?? [])));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
      }
    }
  }

  void _showLifestyleReport() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/matching/lifestyle-report',
        options: app.authHeaders);
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => LifestyleReportScreen(data: res.data['data'])));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
      }
    }
  }
}

// ── AI 추천 목록 화면 ──
class AiRecommendationsScreen extends StatelessWidget {
  final dynamic data;
  const AiRecommendationsScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final app = AppState();
    final recommendations = (data is Map && data['recommendations'] != null)
      ? data['recommendations'] as List
      : (data is List ? data : []);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 추천')),
      body: recommendations.isEmpty
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.recommend, size: 64, color: Colors.white24),
              const SizedBox(height: 12),
              Text(data is Map && data['guidanceMessage'] != null
                ? data['guidanceMessage'] : 'AI 추천 결과가 없습니다',
                style: const TextStyle(color: Colors.white54),
                textAlign: TextAlign.center),
            ],
          ))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final r = recommendations[index];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withOpacity(0.2),
                    child: Text('${index + 1}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(r['previewContent'] ?? r['preview'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Row(children: [
                    Text('${r['ageGroupLabel'] ?? r['ageGroup'] ?? ''} · ${r['region'] ?? ''}'),
                    if (r['matchScore'] != null) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('${(r['matchScore'] * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 10)),
                        backgroundColor: Colors.green.withOpacity(0.2)),
                    ],
                  ]),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final diaryId = r['diaryId'];
                    if (diaryId == null) return;
                    try {
                      final res = await app.dio.get(
                        '${app.baseUrl}/api/matching/recommendations/$diaryId/preview',
                        options: app.authHeaders);
                      if (context.mounted) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => ExploreDetailScreen(diaryId: diaryId, preview: res.data['data'])));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
                      }
                    }
                  },
                ),
              );
            },
          ),
    );
  }
}

// ── 받은 매칭 요청 화면 ──
class ReceivedRequestsScreen extends StatefulWidget {
  final List<dynamic> requests;
  const ReceivedRequestsScreen({super.key, required this.requests});

  @override
  State<ReceivedRequestsScreen> createState() => _ReceivedRequestsScreenState();
}

class _ReceivedRequestsScreenState extends State<ReceivedRequestsScreen> {
  final app = AppState();
  late List<dynamic> requests;

  @override
  void initState() {
    super.initState();
    requests = widget.requests;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('받은 요청 (${requests.length})')),
      body: requests.isEmpty
        ? const Center(child: Text('받은 매칭 요청이 없습니다', style: TextStyle(color: Colors.white54)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final r = requests[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text('${r['fromUserNickname'] ?? '익명'} (${r['fromUserAgeGroup'] ?? ''})'),
                  subtitle: Text(r['diaryPreview'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                        onPressed: () => _accept(r['matchingId'], index),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.redAccent),
                        onPressed: () => _reject(index),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  void _accept(int matchingId, int index) async {
    try {
      final res = await app.dio.post(
        '${app.baseUrl}/api/matching/requests/$matchingId/accept',
        options: app.authHeaders);
      setState(() => requests.removeAt(index));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('매칭 성사! 교환일기 방으로 이동합니다.'),
          duration: Duration(seconds: 2)));
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const HomeScreen(initialTab: 2)),
          (_) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
      }
    }
  }

  void _reject(int index) {
    setState(() => requests.removeAt(index));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('요청을 거절했습니다')));
  }
}

// ── 5.2 블라인드 미리보기 + 5.4 선택/넘기기 ──
class ExploreDetailScreen extends StatelessWidget {
  final int diaryId;
  final Map<String, dynamic> preview;
  const ExploreDetailScreen({super.key, required this.diaryId, required this.preview});

  Color _badgeColor(String? badge) {
    switch ((badge ?? '').toUpperCase()) {
      case 'HIGH': return Colors.greenAccent;
      case 'MEDIUM': case 'MID': return Colors.amberAccent;
      case 'LOW': return Colors.blueAccent;
      default: return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState();
    final ageLabel = preview['ageGroupLabel'] ?? preview['ageGroup'] ?? '';
    final badge = preview['similarityBadge'] as String?;
    final score = preview['matchScore'];
    final scorePct = score is num ? (score * 100).toInt() : null;
    final mainText = preview['preview'] ?? preview['content'] ?? preview['summary'] ?? '';
    final keywords = (preview['keywords'] ?? preview['personalityKeywords']) as List? ?? [];
    final moodTags = (preview['moodTags'] ?? preview['tags'] ?? preview['emotionTags']) as List? ?? [];
    final otherDiaries = (preview['otherDiariesPreview'] ?? preview['otherDiaries']) as List? ?? [];

    return Scaffold(
      appBar: AppBar(title: Text('$ageLabel · 일기 미리보기')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 헤더: 작성자 정보 + 유사도 배지 ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.orange.withOpacity(0.12),
                  Colors.pink.withOpacity(0.08),
                ]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.25)),
              ),
              child: Row(children: [
                CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: const Icon(Icons.person, color: Colors.orangeAccent),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(ageLabel.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  if (preview['region'] != null)
                    Text(preview['region'], style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ])),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _badgeColor(badge).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.favorite, size: 12, color: _badgeColor(badge)),
                      const SizedBox(width: 4),
                      Text(scorePct != null ? '$badge · $scorePct%' : badge,
                        style: TextStyle(color: _badgeColor(badge), fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
              ]),
            ),

            const SizedBox(height: 16),

            // ── 본문 ──
            if ((mainText as String).isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey[900]?.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Text(mainText, style: const TextStyle(fontSize: 14.5, height: 1.7)),
              ),

            const SizedBox(height: 16),

            // ── AI 인트로 ──
            if (preview['aiIntro'] != null || preview['briefing'] != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.purple.withOpacity(0.15),
                    Colors.pink.withOpacity(0.08),
                  ]),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(preview['aiIntro'] ?? preview['briefing'],
                    style: const TextStyle(color: Colors.purpleAccent, height: 1.5, fontSize: 13))),
                ]),
              ),

            const SizedBox(height: 16),

            // ── 키워드 / 분위기 / 카테고리 ──
            if (keywords.isNotEmpty) ...[
              const Text('성격 키워드', style: TextStyle(fontSize: 11, color: Colors.white60)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: keywords.map((k) {
                final txt = k is String ? k : (k is Map ? (k['label'] ?? '').toString() : k.toString());
                return Chip(
                  label: Text('#$txt', style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.purple.withOpacity(0.2),
                  side: BorderSide(color: Colors.purple.withOpacity(0.4)),
                  visualDensity: VisualDensity.compact,
                );
              }).toList()),
              const SizedBox(height: 12),
            ],
            if (moodTags.isNotEmpty) ...[
              const Text('분위기', style: TextStyle(fontSize: 11, color: Colors.white60)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: moodTags.map((t) =>
                Chip(
                  label: Text(t.toString(), style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.pink.withOpacity(0.2),
                  side: BorderSide(color: Colors.pink.withOpacity(0.4)),
                  visualDensity: VisualDensity.compact,
                )).toList()),
              const SizedBox(height: 12),
            ],
            if (preview['category'] != null)
              Row(children: [
                const Text('카테고리: ', style: TextStyle(fontSize: 12, color: Colors.white60)),
                Chip(
                  label: Text(preview['category'].toString(), style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.orange.withOpacity(0.25),
                  visualDensity: VisualDensity.compact,
                ),
              ]),

            // ── 작성자의 다른 일기 ──
            if (otherDiaries.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              const Text('이 작성자의 다른 일기', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              ...otherDiaries.map((od) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.article_outlined, size: 18),
                    title: Text((od is Map ? od['contentPreview'] ?? od['preview'] ?? od['summary'] ?? '' : '') as String,
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                    subtitle: od is Map && od['createdAt'] != null
                      ? Text((od['createdAt'] as String).substring(0, 10),
                        style: const TextStyle(fontSize: 10))
                      : null,
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.skip_next),
              label: const Text('다음 일기'),
              onPressed: () async {
                try {
                  await app.dio.post('${app.baseUrl}/api/matching/$diaryId/skip',
                    options: app.authHeaders);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('넘기기 완료 (7일간 재추천 제외)')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.mail_outline),
              label: const Text('교환 신청'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              onPressed: () async {
                try {
                  final res = await app.dio.post('${app.baseUrl}/api/matching/$diaryId/select',
                    options: app.authHeaders);
                  final data = res.data['data'];
                  if (context.mounted) {
                    if (data['isMatched'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('매칭 성사! 교환일기 방으로 이동합니다.'),
                        duration: Duration(seconds: 2)));
                      Navigator.pushAndRemoveUntil(context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (_) => false);
                    } else {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('교환 신청 완료! 상대방 응답을 기다려주세요 (id: ${data['matchingId']})'),
                        duration: const Duration(seconds: 3)));
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
                  }
                }
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 5.3 라이프스타일 리포트 ──
class LifestyleReportScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const LifestyleReportScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final available = data['analysisAvailable'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('나의 라이프 리포트')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: available ? _buildReport() : _buildUnavailable(),
      ),
    );
  }

  Widget _buildUnavailable() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.analytics_outlined, size: 64, color: Colors.white38),
        const SizedBox(height: 16),
        Text(data['guidanceMessage'] ?? '일기를 더 작성해주세요',
          style: const TextStyle(fontSize: 16, color: Colors.white54)),
        const SizedBox(height: 8),
        Text('현재 ${data['currentDiaryCount']}편 / 필요 ${data['requiredDiaryCount']}편',
          style: const TextStyle(color: Colors.white38)),
      ]),
    );
  }

  Widget _buildReport() {
    final emotion = data['emotionGraph'];
    final emotionPct = emotion is num ? (emotion * 100).toInt() : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // 평균 일기 길이
      _statTile(Icons.text_fields, '평균 일기 길이', '${data['avgDiaryLength'] ?? 0}자'),
      // 작성 패턴
      if (data['weekdayPattern'] != null)
        _statTile(Icons.calendar_month, '작성 패턴',
          '평일 ${data['weekdayPattern']['weekday']}편 · 주말 ${data['weekdayPattern']['weekend']}편'),

      // 감정 표현 점수
      if (emotionPct != null) ...[
        const Text('감정 표현 점수', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: emotion / 1.0,
              minHeight: 10,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
            ),
          )),
          const SizedBox(width: 8),
          Text('$emotionPct%', style: const TextStyle(fontSize: 13, color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
      ],

      // 활동 히트맵 (요일×시간대 카운트)
      if (data['activityHeatmap'] != null && (data['activityHeatmap'] as List).isNotEmpty) ...[
        const Text('활동 히트맵', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
        const SizedBox(height: 8),
        _heatmapGrid(data['activityHeatmap'] as List),
        const SizedBox(height: 16),
      ],

      // 자주 쓰는 키워드
      if (data['commonKeywords'] != null && (data['commonKeywords'] as List).isNotEmpty) ...[
        const Text('자주 쓰는 키워드', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: (data['commonKeywords'] as List).map((k) =>
          Chip(label: Text('#$k', style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.purple.withOpacity(0.2))).toList()),
        const SizedBox(height: 16),
      ],

      // 라이프스타일 태그
      if (data['lifestyleTags'] != null && (data['lifestyleTags'] as List).isNotEmpty) ...[
        const Text('라이프스타일 태그', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, children: (data['lifestyleTags'] as List).map((t) =>
          Chip(label: Text(t.toString(), style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.teal.withOpacity(0.2),
            side: const BorderSide(color: Colors.teal))).toList()),
        const SizedBox(height: 16),
      ],

      // AI 한줄 설명
      if (data['aiDescription'] != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.orange.withOpacity(0.15),
              Colors.amber.withOpacity(0.1),
            ]),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.auto_awesome, color: Colors.orangeAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(data['aiDescription'],
              style: const TextStyle(color: Colors.orangeAccent, height: 1.5))),
          ]),
        ),
    ]);
  }

  Widget _statTile(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Icon(icon, size: 16, color: Colors.white54),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
      Text(value, style: const TextStyle(fontSize: 14)),
    ]),
  );

  Widget _heatmapGrid(List heat) {
    // 7일 × 24시간 그리드
    int maxCount = 1;
    for (final h in heat) {
      final c = h is Map ? (h['count'] ?? 0) as int : 0;
      if (c > maxCount) maxCount = c;
    }
    final cells = List.generate(7, (d) => List.filled(24, 0));
    for (final h in heat) {
      if (h is Map) {
        final day = h['day'];
        final hour = h['hour'];
        final count = h['count'] ?? 0;
        if (day is int && hour is int && day >= 0 && day < 7 && hour >= 0 && hour < 24) {
          cells[day][hour] = count is int ? count : 0;
        }
      }
    }
    const dayLabel = ['일','월','화','수','목','금','토'];
    return SizedBox(
      height: 100,
      child: Column(children: List.generate(7, (d) => Expanded(
        child: Row(children: [
          SizedBox(width: 18, child: Text(dayLabel[d], style: const TextStyle(fontSize: 9, color: Colors.white54))),
          Expanded(child: Row(children: List.generate(24, (h) {
            final v = cells[d][h];
            final intensity = v / maxCount;
            return Expanded(child: Container(
              margin: const EdgeInsets.all(0.5),
              decoration: BoxDecoration(
                color: v == 0 ? Colors.white10 : Colors.tealAccent.withOpacity(0.2 + intensity * 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ));
          }))),
        ]),
      ))),
    );
  }
}

// ══════════════════════════════════════
// 개발자 도구 (Dev only)
// ══════════════════════════════════════
class DeveloperToolsScreen extends StatefulWidget {
  const DeveloperToolsScreen({super.key});

  @override
  State<DeveloperToolsScreen> createState() => _DeveloperToolsScreenState();
}

class _DeveloperToolsScreenState extends State<DeveloperToolsScreen> {
  final app = AppState();

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showJson(String title, dynamic data) {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Text(const JsonEncoder.withIndent('  ').convert(data), style: const TextStyle(fontSize: 12)),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
    ));
  }

  void _showAiSimulateDialog() {
    final diaryIdCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('AI 분석 시뮬레이션'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: diaryIdCtrl, decoration: const InputDecoration(labelText: 'diaryId'), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        const Text('AI 서버 없이 가짜 분석 결과를 생성합니다.\n2~3초 후 일기 상세에서 AI 태그를 확인하세요.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          final diaryId = diaryIdCtrl.text.trim();
          if (diaryId.isEmpty) return;
          try {
            final res = await app.dio.post('${app.baseUrl}/api/dev/ai/simulate/$diaryId');
            _showJson('AI 시뮬레이션', res.data);
          } catch (e) { _snack(app.errMsg(e)); }
        }, child: const Text('실행', style: TextStyle(color: Colors.amber))),
      ],
    ));
  }

  void _showRedisGetDialog() {
    final keyCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Redis 키 조회'),
      content: TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'key (예: AI:DIARY:123)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          final key = keyCtrl.text.trim();
          if (key.isEmpty) return;
          try {
            final res = await app.dio.get('${app.baseUrl}/api/dev/redis/get',
              queryParameters: {'key': key});
            _showJson('Redis [$key]', res.data);
          } catch (e) { _snack(app.errMsg(e)); }
        }, child: const Text('조회', style: TextStyle(color: Colors.amber))),
      ],
    ));
  }

  void _showRedisDeleteDialog() {
    final keyCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Redis 키 삭제'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: keyCtrl, decoration: const InputDecoration(labelText: 'key')),
        const SizedBox(height: 8),
        const Text('삭제 후 복구 불가', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          final key = keyCtrl.text.trim();
          if (key.isEmpty) return;
          try {
            final res = await app.dio.delete('${app.baseUrl}/api/dev/redis/delete',
              queryParameters: {'key': key});
            _showJson('삭제 결과', res.data);
          } catch (e) { _snack(app.errMsg(e)); }
        }, child: const Text('삭제', style: TextStyle(color: Colors.redAccent))),
      ],
    ));
  }

  void _showRedisPatternDialog() {
    final patternCtrl = TextEditingController(text: '*');
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Redis 패턴 검색'),
      content: TextField(controller: patternCtrl, decoration: const InputDecoration(labelText: 'pattern (예: AI:DIARY:*)')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          final pattern = patternCtrl.text.trim();
          if (pattern.isEmpty) return;
          try {
            final res = await app.dio.get('${app.baseUrl}/api/dev/redis/keys',
              queryParameters: {'pattern': pattern});
            _showJson('패턴 [$pattern] 결과', res.data);
          } catch (e) { _snack(app.errMsg(e)); }
        }, child: const Text('검색', style: TextStyle(color: Colors.amber))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 개발자 도구'),
        backgroundColor: Colors.amber.withOpacity(0.15),
      ),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text(
                '시연/디버깅용 기능입니다. 실제 사용자에겐 노출되지 않습니다.',
                style: TextStyle(fontSize: 12, color: Colors.amber),
              )),
            ]),
          ),

          // ── AI 파이프라인 ──
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('AI 파이프라인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber))),
          ListTile(
            title: const Text('AI 분석 시뮬레이션'),
            subtitle: const Text('diaryId 입력 → 가짜 AI 결과 생성', style: TextStyle(fontSize: 11)),
            leading: const Icon(Icons.science, color: Colors.amber),
            onTap: () => _showAiSimulateDialog(),
          ),

          // ── Redis 캐시 ──
          const Divider(),
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Redis 캐시', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber))),
          ListTile(
            title: const Text('캐시 요약'),
            subtitle: const Text('전체 캐시 키 수/메모리 현황', style: TextStyle(fontSize: 11)),
            leading: const Icon(Icons.dashboard, color: Colors.amber),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/dev/redis/summary');
                _showJson('Redis 요약', res.data);
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
          ListTile(
            title: const Text('내 캐시 현황'),
            subtitle: const Text('내 userId 기준 캐시 키 목록', style: TextStyle(fontSize: 11)),
            leading: const Icon(Icons.person_search, color: Colors.amber),
            onTap: () async {
              if (app.userId == null) { _snack('로그인 후 이용하세요'); return; }
              try {
                final res = await app.dio.get('${app.baseUrl}/api/dev/redis/user/${app.userId}');
                _showJson('내 캐시 (userId=${app.userId})', res.data);
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
          ListTile(
            title: const Text('키 직접 조회'),
            subtitle: const Text('key 입력 → 값 조회', style: TextStyle(fontSize: 11)),
            leading: const Icon(Icons.search, color: Colors.amber),
            onTap: () => _showRedisGetDialog(),
          ),
          ListTile(
            title: const Text('키 삭제'),
            subtitle: const Text('key 입력 → 캐시 삭제', style: TextStyle(fontSize: 11)),
            leading: const Icon(Icons.delete_outline, color: Colors.amber),
            onTap: () => _showRedisDeleteDialog(),
          ),
          ListTile(
            title: const Text('패턴 검색'),
            subtitle: const Text('pattern 입력 (예: AI:DIARY:*) → 키 목록', style: TextStyle(fontSize: 11)),
            leading: const Icon(Icons.filter_list, color: Colors.amber),
            onTap: () => _showRedisPatternDialog(),
          ),

          // ── 인증 ──
          const Divider(),
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('인증', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber))),
          ListTile(
            title: const Text('토큰 갱신'),
            subtitle: const Text('refreshToken으로 accessToken 재발급', style: TextStyle(fontSize: 11)),
            leading: const Icon(Icons.refresh, color: Colors.amber),
            onTap: () async {
              try {
                final res = await app.dio.post('${app.baseUrl}/api/auth/refresh',
                  data: {'refreshToken': app.refreshToken});
                app.accessToken = res.data['data']['accessToken'];
                app.refreshToken = res.data['data']['refreshToken'];
                _snack('토큰 갱신 성공!');
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),

          // ── 시스템 ──
          const Divider(),
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('시스템', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber))),
          ListTile(
            title: const Text('헬스체크'),
            subtitle: const Text('GET /api/health — 서버 가용성', style: TextStyle(fontSize: 11)),
            leading: const Icon(Icons.health_and_safety, color: Colors.amber),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/health');
                _showJson('헬스체크', res.data);
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
          ListTile(
            title: const Text('앱 버전 확인'),
            subtitle: const Text('GET /api/system/version — 강제/권장 업데이트', style: TextStyle(fontSize: 11)),
            leading: const Icon(Icons.system_update, color: Colors.amber),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/system/version');
                _showJson('앱 버전', res.data);
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════
// 더보기 탭
// ══════════════════════════════════════
class MoreTab extends StatefulWidget {
  const MoreTab({super.key});

  @override
  State<MoreTab> createState() => _MoreTabState();
}

typedef SettingsTab = MoreTab;

class _MoreTabState extends State<MoreTab> {
  final app = AppState();

  void _snack(String msg) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('더보기')),
      body: ListView(
        children: [
          // ── 프로필 ──
          const Padding(padding: EdgeInsets.all(12), child: Text('프로필', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ListTile(
            title: const Text('내 프로필'), leading: const Icon(Icons.person),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/users/me', options: app.authHeaders);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => MyProfileScreen(profile: res.data['data'])));
                }
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
          ListTile(
            title: const Text('AI 프로필 (성격 분석)'), leading: const Icon(Icons.psychology),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/users/me/ai-profile', options: app.authHeaders);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AiProfileScreen(data: res.data['data'])));
                }
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
          ListTile(
            title: const Text('이상형 키워드'), leading: const Icon(Icons.favorite),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/users/me/ideal-type', options: app.authHeaders);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => IdealTypeViewScreen(data: res.data['data'])));
                }
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),

          // ── 알림 ──
          const Divider(),
          const Padding(padding: EdgeInsets.all(12), child: Text('알림', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ListTile(
            title: const Text('알림 목록'), leading: const Icon(Icons.notifications),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/notifications', options: app.authHeaders);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NotificationListScreen(data: res.data['data'])));
                }
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
          ListTile(
            title: const Text('알림 설정'), leading: const Icon(Icons.notifications_active),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/users/me/notification-settings', options: app.authHeaders);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NotificationSettingsScreen(settings: res.data['data'])));
                }
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),

          // ── 신고/차단 ──
          const Divider(),
          const Padding(padding: EdgeInsets.all(12), child: Text('신고/차단', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ListTile(
            title: const Text('차단 목록'), leading: const Icon(Icons.block),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/users/me/block-list', options: app.authHeaders);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => BlockListScreen(data: res.data['data'])));
                }
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
          ListTile(
            title: const Text('사용자 신고 (상대방)'), leading: const Icon(Icons.report),
            onTap: () => _showReportDialog(),
          ),
          ListTile(
            title: const Text('사용자 차단 (상대방)'), leading: const Icon(Icons.person_off),
            onTap: () => _showBlockDialog(),
          ),

          // ── 히스토리 ──
          const Divider(),
          const Padding(padding: EdgeInsets.all(12), child: Text('히스토리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ListTile(
            title: const Text('교환일기 히스토리'), leading: const Icon(Icons.history),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/users/me/history/exchange-rooms', options: app.authHeaders);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ExchangeHistoryScreen(data: res.data['data'])));
                }
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
          ListTile(
            title: const Text('채팅 히스토리'), leading: const Icon(Icons.chat_bubble_outline),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/users/me/history/chat-rooms', options: app.authHeaders);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ChatHistoryScreen(data: res.data['data'])));
                }
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),

          // ── 공지/FAQ ──
          const Divider(),
          const Padding(padding: EdgeInsets.all(12), child: Text('공지/지원', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ListTile(
            title: const Text('공지사항'), leading: const Icon(Icons.campaign),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/notices', options: app.authHeaders);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => NoticeListScreen(data: res.data['data'])));
                }
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
          ListTile(
            title: const Text('FAQ'), leading: const Icon(Icons.help),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/faq', options: app.authHeaders);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => FaqScreen(data: res.data['data'])));
                }
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
          ListTile(
            title: const Text('1:1 문의 접수'), leading: const Icon(Icons.support_agent),
            onTap: () => _showInquiryDialog(),
          ),
          ListTile(
            title: const Text('내 문의 목록'), leading: const Icon(Icons.list_alt),
            onTap: () async {
              try {
                final res = await app.dio.get('${app.baseUrl}/api/support/inquiries', options: app.authHeaders);
                if (mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => InquiryListScreen(data: res.data['data'])));
                }
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),

          // ── 앱 설정 ──
          const Divider(),
          const Padding(padding: EdgeInsets.all(12), child: Text('앱 설정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ListTile(
            title: const Text('설정 관리'), leading: const Icon(Icons.settings),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppSettingsScreen())),
          ),

          // ── 계정 ──
          const Divider(),
          const Padding(padding: EdgeInsets.all(12), child: Text('계정', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          ListTile(
            title: const Text('이의신청'), leading: const Icon(Icons.gavel),
            onTap: () => _showAppealDialog(),
          ),
          ListTile(
            title: const Text('AI 동의 철회'), leading: const Icon(Icons.privacy_tip),
            onTap: () => _showAiConsentRevokeDialog(),
          ),
          ListTile(
            title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
            leading: const Icon(Icons.logout, color: Colors.red),
            onTap: () {
              showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('로그아웃'),
                content: const Text('정말 로그아웃 하시겠어요?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                  TextButton(
                    onPressed: () async {
                      try {
                        await app.dio.post('${app.baseUrl}/api/auth/logout', options: app.authHeaders);
                      } catch (_) {}
                      app.accessToken = null;
                      app.refreshToken = null;
                      if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.pushAndRemoveUntil(context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (_) => false);
                      }
                    },
                    child: const Text('로그아웃', style: TextStyle(color: Colors.red))),
                ],
              ));
            },
          ),
          ListTile(
            title: const Text('계정 복구 (탈퇴 유예 중일 때)'), leading: const Icon(Icons.restore),
            onTap: () async {
              try {
                await app.dio.post('${app.baseUrl}/api/users/me/restore', options: app.authHeaders);
                _snack('계정 복구 완료!');
              } catch (e) { _snack(app.errMsg(e)); }
            },
          ),
          ListTile(
            title: const Text('회원 탈퇴 (30일 유예)', style: TextStyle(color: Colors.red)),
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: () {
              showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('회원 탈퇴'),
                content: const Text('30일 유예 기간 후 영구 삭제됩니다.\n정말 탈퇴하시겠어요?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await app.dio.post('${app.baseUrl}/api/users/me/deactivate',
                          data: {'reason': 'SERVICE_DISSATISFACTION'}, options: app.authHeaders);
                        _snack('탈퇴 처리 완료 (30일 유예)');
                      } catch (e) { _snack(app.errMsg(e)); }
                    },
                    child: const Text('탈퇴', style: TextStyle(color: Colors.red))),
                ],
              ));
            },
          ),

          // ── 개발자 도구 (시연 시 진입 안 함) ──
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.build, size: 18, color: Colors.amber),
              label: const Text('🔧 개발자 도구', style: TextStyle(color: Colors.amber)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.amber.withOpacity(0.4)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const DeveloperToolsScreen())),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final targetCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('사용자 신고'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: targetCtrl, decoration: const InputDecoration(labelText: '대상 userId'), keyboardType: TextInputType.number),
        const SizedBox(height: 8),
        const Text('사유: HARASSMENT', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          final targetId = targetCtrl.text.trim();
          if (targetId.isEmpty) return;
          try {
            final res = await app.dio.post('${app.baseUrl}/api/users/$targetId/report',
              data: {'reason': 'HARASSMENT'}, options: app.authHeaders);
            _snack('신고 접수 완료: ID=${res.data['data']['reportId']}');
          } catch (e) { _snack(app.errMsg(e)); }
        }, child: const Text('신고')),
      ],
    ));
  }

  void _showBlockDialog() {
    final targetCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('사용자 차단'),
      content: TextField(controller: targetCtrl, decoration: const InputDecoration(labelText: '대상 userId'), keyboardType: TextInputType.number),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          final targetId = targetCtrl.text.trim();
          if (targetId.isEmpty) return;
          try {
            await app.dio.post('${app.baseUrl}/api/users/$targetId/block', options: app.authHeaders);
            _snack('차단 완료');
          } catch (e) { _snack(app.errMsg(e)); }
        }, child: const Text('차단', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _showAppealDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('제재 이의신청'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(labelText: '사유 (20~500자)', border: OutlineInputBorder()),
          maxLines: 5,
        ),
        const SizedBox(height: 8),
        const Text('이의신청은 한 번만 가능합니다.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          final reason = reasonCtrl.text.trim();
          if (reason.length < 20) { _snack('20자 이상 입력해주세요'); return; }
          try {
            final res = await app.dio.post('${app.baseUrl}/api/users/me/appeals',
              data: {'reason': reason}, options: app.authHeaders);
            _snack('이의신청 접수 완료: ID=${res.data['data']['appealId']}');
          } catch (e) { _snack(app.errMsg(e)); }
        }, child: const Text('제출')),
      ],
    ));
  }

  void _showAiConsentRevokeDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('AI 동의 철회'),
      content: const Text('AI 분석 동의를 철회하면 성격 분석, 매칭 추천 등 AI 기능을 이용할 수 없게 됩니다.\n\n정말 철회하시겠어요?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          try {
            await app.dio.delete('${app.baseUrl}/api/consent', options: app.authHeaders);
            _snack('AI 동의 철회 완료');
          } catch (e) { _snack(app.errMsg(e)); }
        }, child: const Text('철회', style: TextStyle(color: Colors.red))),
      ],
    ));
  }

  void _showInquiryDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('1:1 문의'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '제목 (5자 이상)')),
        const SizedBox(height: 8),
        TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: '내용 (10자 이상)'), maxLines: 3),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          try {
            final res = await app.dio.post('${app.baseUrl}/api/support/inquiry',
              data: {'category': 'ACCOUNT', 'title': titleCtrl.text, 'content': contentCtrl.text},
              options: app.authHeaders);
            _snack('문의 접수 완료: ID=${res.data['data']['inquiryId']}');
          } catch (e) { _snack(app.errMsg(e)); }
        }, child: const Text('제출')),
      ],
    ));
  }

}

// ══════════════════════════════════════
// 프로필 상세 화면
// ══════════════════════════════════════
class MyProfileScreen extends StatefulWidget {
  final Map<String, dynamic> profile;
  const MyProfileScreen({super.key, required this.profile});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final app = AppState();
  late Map<String, dynamic> profile;

  @override
  void initState() {
    super.initState();
    profile = widget.profile;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('내 프로필')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // 프로필 카드
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  child: Text(
                    (profile['nickname'] ?? '?').toString().substring(0, 1),
                    style: const TextStyle(fontSize: 32, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 12),
                Text(profile['nickname'] ?? '???',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (profile['onboardingCompleted'] == true)
                  const Chip(label: Text('온보딩 완료', style: TextStyle(fontSize: 11, color: Colors.greenAccent))),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // 상세 정보
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              _profileRow(Icons.person, '성별', _genderLabel(profile['gender'])),
              const Divider(height: 1),
              _profileRow(Icons.cake, '생년월일', profile['birthDate'] ?? '-'),
              const Divider(height: 1),
              _profileRow(Icons.location_on, '지역', profile['sido'] ?? '-'),
              const Divider(height: 1),
              _profileRow(Icons.school, '학교', profile['school'] ?? '-'),
              const Divider(height: 1),
              _profileRow(Icons.badge, 'userId', '${profile['userId'] ?? app.userId ?? '-'}'),
            ]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showEditDialog,
              icon: const Icon(Icons.edit),
              label: const Text('프로필 수정'),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, size: 20, color: Colors.white54),
      title: Text(label, style: const TextStyle(fontSize: 13, color: Colors.white54)),
      trailing: Text(value, style: const TextStyle(fontSize: 14)),
    );
  }

  String _genderLabel(String? g) {
    if (g == 'MALE') return '남성';
    if (g == 'FEMALE') return '여성';
    return g ?? '-';
  }

  void _showEditDialog() {
    final nicknameCtrl = TextEditingController(text: profile['nickname']);
    final sidoCtrl = TextEditingController(text: profile['sido']);
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('프로필 수정'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nicknameCtrl, decoration: const InputDecoration(labelText: '닉네임')),
        const SizedBox(height: 8),
        TextField(controller: sidoCtrl, decoration: const InputDecoration(labelText: '시/도')),
        const SizedBox(height: 8),
        const Text('닉네임은 30일에 1회만 변경 가능', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () async {
          Navigator.pop(context);
          try {
            final data = <String, dynamic>{};
            if (nicknameCtrl.text != profile['nickname']) data['nickname'] = nicknameCtrl.text;
            if (sidoCtrl.text != profile['sido']) data['sido'] = sidoCtrl.text;
            if (data.isEmpty) return;
            final res = await app.dio.patch('${app.baseUrl}/api/users/me/profile',
              data: data, options: app.authHeaders);
            setState(() => profile = res.data['data']);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필 수정 완료')));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
          }
        }, child: const Text('저장')),
      ],
    ));
  }
}

// ══════════════════════════════════════
// AI 프로필 화면
// ══════════════════════════════════════
class AiProfileScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const AiProfileScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final diaryCount = data['analyzedDiaryCount'] ?? data['diaryCount'] ?? 0;
    final available = data['available'] != false;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 성격 분석')),
      body: !available
        ? Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.psychology, size: 64, color: Colors.white24),
              const SizedBox(height: 12),
              Text(data['message'] ?? '일기를 3편 이상 작성하면 분석이 시작됩니다',
                style: const TextStyle(color: Colors.white54), textAlign: TextAlign.center),
            ],
          ))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // 분석된 일기 수
              Card(
                color: Colors.orange.withOpacity(0.1),
                child: ListTile(
                  leading: const Icon(Icons.auto_stories, color: Colors.orange),
                  title: Text('분석된 일기: $diaryCount편'),
                ),
              ),
              const SizedBox(height: 16),

              // 성격 키워드 (dominantPersonalityTags 우선, 명세 v12 기준)
              _tagSection('성격 키워드',
                data['dominantPersonalityTags'] ?? data['personalityTags'] ?? data['personalityKeywords'], Colors.purple),
              _tagSection('감정 태그',
                data['dominantEmotionTags'] ?? data['emotionTags'] ?? data['emotionKeywords'], Colors.pink),
              _tagSection('라이프스타일 태그',
                data['dominantLifestyleTags'] ?? data['lifestyleTags'] ?? data['lifestyleKeywords'], Colors.teal),
              _tagSection('관계 성향',
                data['dominantRelationshipTags'] ?? data['relationshipTags'] ?? data['relationshipKeywords'], Colors.blue),
              _tagSection('글쓰기 톤',
                data['dominantToneTags'] ?? data['toneTags'] ?? data['toneKeywords'], Colors.amber),

              // AI 한줄 설명
              if (data['aiDescription'] != null || data['summary'] != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('AI 분석 요약', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(data['aiDescription'] ?? data['summary'] ?? '',
                      style: const TextStyle(height: 1.5)),
                  ]),
                ),
              ],
            ]),
          ),
    );
  }

  Widget _tagSection(String title, dynamic tags, Color color) {
    if (tags == null) return const SizedBox.shrink();
    final tagList = tags is List ? tags : [];
    if (tagList.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: tagList.map((t) {
          final label = t is String ? t : (t is Map ? (t['label'] ?? t['keyword'] ?? '') : '$t');
          final count = t is Map ? t['count'] : null;
          return Chip(
            label: Text(
              count != null ? '$label ($count)' : '$label',
              style: TextStyle(fontSize: 12, color: color),
            ),
            backgroundColor: color.withOpacity(0.15),
            side: BorderSide(color: color.withOpacity(0.3)),
          );
        }).toList()),
      ]),
    );
  }
}

// ══════════════════════════════════════
// 이상형 키워드 조회/수정 화면
// ══════════════════════════════════════
class IdealTypeViewScreen extends StatefulWidget {
  final dynamic data;
  const IdealTypeViewScreen({super.key, required this.data});

  @override
  State<IdealTypeViewScreen> createState() => _IdealTypeViewScreenState();
}

class _IdealTypeViewScreenState extends State<IdealTypeViewScreen> {
  final app = AppState();
  late dynamic data;

  @override
  void initState() {
    super.initState();
    data = widget.data;
  }

  List<dynamic> get keywords {
    if (data is Map && data['keywords'] != null) return data['keywords'];
    if (data is List) return data;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이상형 키워드')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('현재 이상형 키워드', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${keywords.length}/3 선택됨', style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            keywords.isEmpty
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('설정된 키워드가 없습니다', style: TextStyle(color: Colors.white38)),
                ))
              : Wrap(
                  spacing: 10, runSpacing: 10,
                  children: keywords.map((k) {
                    final label = k is String ? k : (k is Map ? (k['label'] ?? k['keyword'] ?? '') : '$k');
                    return Chip(
                      label: Text(label, style: const TextStyle(fontSize: 14)),
                      backgroundColor: Colors.pink.withOpacity(0.15),
                      side: BorderSide(color: Colors.pink.withOpacity(0.3)),
                      avatar: const Icon(Icons.favorite, size: 16, color: Colors.pink),
                    );
                  }).toList(),
                ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showEditScreen,
                icon: const Icon(Icons.edit),
                label: const Text('키워드 수정'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditScreen() async {
    try {
      final keywordRes = await app.dio.get('${app.baseUrl}/api/users/ideal-type/keyword-list');
      final allKeywords = keywordRes.data['data']['keywords'] as List;
      // 현재 선택된 ID 추출
      final selectedIds = <int>{};
      for (final k in keywords) {
        if (k is Map && k['id'] != null) selectedIds.add(k['id']);
      }

      if (mounted) {
        final result = await Navigator.push<Set<int>>(context, MaterialPageRoute(
          builder: (_) => IdealTypeEditScreen(allKeywords: allKeywords, selectedIds: selectedIds)));
        if (result != null) {
          try {
            final res = await app.dio.put('${app.baseUrl}/api/users/me/ideal-type',
              data: {'keywordIds': result.toList()}, options: app.authHeaders);
            setState(() => data = res.data['data']);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('이상형 키워드 수정 완료!')));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
          }
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }
}

class IdealTypeEditScreen extends StatefulWidget {
  final List<dynamic> allKeywords;
  final Set<int> selectedIds;
  const IdealTypeEditScreen({super.key, required this.allKeywords, required this.selectedIds});

  @override
  State<IdealTypeEditScreen> createState() => _IdealTypeEditScreenState();
}

class _IdealTypeEditScreenState extends State<IdealTypeEditScreen> {
  late Set<int> selected;

  @override
  void initState() {
    super.initState();
    selected = Set.from(widget.selectedIds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('이상형 키워드 수정'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, selected),
            child: const Text('저장', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${selected.length}/3 선택됨', style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: widget.allKeywords.map((k) {
              final id = k['id'] as int;
              final isSelected = selected.contains(id);
              return FilterChip(
                label: Text(k['label']),
                selected: isSelected,
                onSelected: (v) {
                  setState(() {
                    if (v && selected.length < 3) selected.add(id);
                    else selected.remove(id);
                  });
                },
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════
// 알림 목록 화면
// ══════════════════════════════════════
class NotificationListScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  const NotificationListScreen({super.key, required this.data});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final app = AppState();
  late Map<String, dynamic> data;

  @override
  void initState() {
    super.initState();
    data = widget.data;
  }

  List<dynamic> get notifications => data['notifications'] ?? [];
  int get unreadCount => data['unreadCount'] ?? 0;

  IconData _iconForType(String? type) {
    switch (type) {
      case 'MATCHING_REQUEST': return Icons.favorite;
      case 'MATCHING_MATCHED': return Icons.celebration;
      case 'EXCHANGE_DIARY': return Icons.swap_horiz;
      case 'EXCHANGE_REMIND': return Icons.alarm;
      case 'EXCHANGE_EXPIRED': return Icons.timer_off;
      case 'CHAT_MESSAGE': return Icons.chat;
      case 'COUPLE_REQUEST': return Icons.favorite_border;
      case 'COUPLE_ACCEPTED': return Icons.favorite;
      case 'AI_ANALYSIS_DONE': return Icons.psychology;
      case 'AI_REPORT_DONE': return Icons.analytics;
      case 'SYSTEM': return Icons.info;
      default: return Icons.notifications;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'MATCHING_REQUEST':
      case 'MATCHING_MATCHED': return Colors.pink;
      case 'EXCHANGE_DIARY':
      case 'EXCHANGE_REMIND': return Colors.orange;
      case 'CHAT_MESSAGE': return Colors.blue;
      case 'COUPLE_REQUEST':
      case 'COUPLE_ACCEPTED': return Colors.red;
      case 'AI_ANALYSIS_DONE':
      case 'AI_REPORT_DONE': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('알림 ($unreadCount 미읽음)'),
        actions: [
          TextButton.icon(
            onPressed: _readAll,
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('전체 읽음'),
          ),
        ],
      ),
      body: notifications.isEmpty
        ? const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none, size: 64, color: Colors.white24),
              SizedBox(height: 12),
              Text('알림이 없습니다', style: TextStyle(color: Colors.white54)),
            ],
          ))
        : RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = notifications[i];
                final isRead = n['readAt'] != null || n['isRead'] == true;
                final type = n['type'] as String?;
                final createdAt = n['createdAt'] as String? ?? '';
                final timeStr = createdAt.length >= 16 ? createdAt.substring(5, 16).replaceAll('T', ' ') : '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _colorForType(type).withOpacity(isRead ? 0.1 : 0.3),
                    child: Icon(_iconForType(type), color: _colorForType(type), size: 20),
                  ),
                  title: Text(n['title'] ?? type ?? '알림',
                    style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 14)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (n['message'] != null || n['body'] != null)
                      Text(n['message'] ?? n['body'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                    Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.white38)),
                  ]),
                  trailing: isRead
                    ? null
                    : Container(
                        width: 8, height: 8,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orange),
                      ),
                  onTap: () => _onTap(n),
                );
              },
            ),
          ),
    );
  }

  Future<void> _reload() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/notifications', options: app.authHeaders);
      setState(() => data = res.data['data']);
    } catch (_) {}
  }

  void _markAsRead(Map<String, dynamic> n) async {
    if (n['readAt'] != null || n['isRead'] == true) return;
    final id = n['notificationId'] ?? n['id'];
    if (id == null) return;
    try {
      await app.dio.patch('${app.baseUrl}/api/notifications/$id/read', options: app.authHeaders);
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  // 알림 탭 시 읽음 처리 + navTarget 딥링크 이동
  void _onTap(Map<String, dynamic> n) async {
    _markAsRead(n);
    final target = n['navTarget'] as String?;
    if (target == null || !mounted) return;
    // /exchange-rooms/123, /chat-rooms/45, /matching/requests, /notices/7 등 처리
    try {
      if (target.startsWith('/exchange-rooms/')) {
        final id = int.tryParse(target.substring('/exchange-rooms/'.length));
        if (id != null) Navigator.push(context, MaterialPageRoute(builder: (_) => ExchangeRoomScreen(roomId: id)));
      } else if (target.startsWith('/chat-rooms/')) {
        final id = int.tryParse(target.substring('/chat-rooms/'.length));
        if (id != null) Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatRoomScreen(chatRoomId: id, partnerName: n['title'] ?? '대화')));
      } else if (target == '/matching/requests') {
        final res = await app.dio.get('${app.baseUrl}/api/matching/requests', options: app.authHeaders);
        if (mounted) Navigator.push(context, MaterialPageRoute(
          builder: (_) => ReceivedRequestsScreen(requests: res.data['data'] ?? [])));
      } else if (target.startsWith('/notices/')) {
        final id = int.tryParse(target.substring('/notices/'.length));
        if (id != null) {
          final res = await app.dio.get('${app.baseUrl}/api/notices/$id', options: app.authHeaders);
          if (mounted) Navigator.push(context, MaterialPageRoute(
            builder: (_) => NoticeDetailScreen(notice: res.data['data'])));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이동 대상: $target')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  void _readAll() async {
    try {
      final res = await app.dio.patch('${app.baseUrl}/api/notifications/read-all', options: app.authHeaders);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${res.data['data']['updatedCount']}건 읽음 처리')));
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }
}

// ══════════════════════════════════════
// 알림 설정 화면
// ══════════════════════════════════════
class NotificationSettingsScreen extends StatefulWidget {
  final dynamic settings;
  const NotificationSettingsScreen({super.key, required this.settings});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final app = AppState();
  late Map<String, bool> toggles;

  static const _categories = [
    {'key': 'matching', 'label': '매칭 알림', 'icon': Icons.favorite},
    {'key': 'exchange', 'label': '교환일기 알림', 'icon': Icons.swap_horiz},
    {'key': 'chat', 'label': '채팅 알림', 'icon': Icons.chat},
    {'key': 'diary', 'label': '일기 알림', 'icon': Icons.auto_stories},
    {'key': 'couple', 'label': '커플 알림', 'icon': Icons.people},
    {'key': 'system', 'label': '시스템 알림', 'icon': Icons.info},
  ];

  @override
  void initState() {
    super.initState();
    toggles = {};
    for (final c in _categories) {
      final key = c['key'] as String;
      if (widget.settings is Map) {
        toggles[key] = widget.settings[key] ?? true;
      } else {
        toggles[key] = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: ListView(
        children: _categories.map((c) {
          final key = c['key'] as String;
          return SwitchListTile(
            secondary: Icon(c['icon'] as IconData, color: Colors.white54),
            title: Text(c['label'] as String),
            value: toggles[key] ?? true,
            onChanged: (v) async {
              setState(() => toggles[key] = v);
              try {
                await app.dio.patch('${app.baseUrl}/api/users/me/notification-settings',
                  data: {key: v}, options: app.authHeaders);
              } catch (e) {
                setState(() => toggles[key] = !v);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
              }
            },
          );
        }).toList(),
      ),
    );
  }
}

// ══════════════════════════════════════
// 차단 목록 화면
// ══════════════════════════════════════
class BlockListScreen extends StatefulWidget {
  final dynamic data;
  const BlockListScreen({super.key, required this.data});

  @override
  State<BlockListScreen> createState() => _BlockListScreenState();
}

class _BlockListScreenState extends State<BlockListScreen> {
  final app = AppState();
  late List<dynamic> blocks;

  @override
  void initState() {
    super.initState();
    if (widget.data is Map && widget.data['blocks'] != null) {
      blocks = List.from(widget.data['blocks']);
    } else if (widget.data is List) {
      blocks = List.from(widget.data);
    } else {
      blocks = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('차단 목록 (${blocks.length})')),
      body: blocks.isEmpty
        ? const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.block, size: 64, color: Colors.white24),
              SizedBox(height: 12),
              Text('차단한 사용자가 없습니다', style: TextStyle(color: Colors.white54)),
            ],
          ))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: blocks.length,
            itemBuilder: (_, i) {
              final b = blocks[i];
              final nickname = b['nickname'] ?? b['targetNickname'] ?? '사용자 ${b['targetUserId'] ?? ''}';
              final blockedAt = b['blockedAt'] ?? b['createdAt'] ?? '';
              final dateStr = blockedAt.toString().length >= 10 ? blockedAt.toString().substring(0, 10) : '';

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_off)),
                  title: Text(nickname),
                  subtitle: Text('차단일: $dateStr'),
                  trailing: TextButton(
                    onPressed: () => _unblock(b, i),
                    child: const Text('해제', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
              );
            },
          ),
    );
  }

  void _unblock(Map<String, dynamic> b, int index) async {
    final targetId = b['targetUserId'] ?? b['userId'];
    if (targetId == null) return;
    try {
      await app.dio.delete('${app.baseUrl}/api/users/$targetId/block', options: app.authHeaders);
      setState(() => blocks.removeAt(index));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('차단 해제 완료')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }
}

// ══════════════════════════════════════
// 교환일기 히스토리 화면
// ══════════════════════════════════════
class ExchangeHistoryScreen extends StatelessWidget {
  final dynamic data;
  const ExchangeHistoryScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final rooms = (data is Map && data['rooms'] != null) ? data['rooms'] as List
      : (data is List ? data : []);

    return Scaffold(
      appBar: AppBar(title: Text('교환일기 히스토리 (${rooms.length})')),
      body: rooms.isEmpty
        ? const Center(child: Text('교환일기 기록이 없습니다', style: TextStyle(color: Colors.white54)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rooms.length,
            itemBuilder: (_, i) {
              final r = rooms[i];
              final status = r['status'] ?? '';
              Color statusColor = Colors.grey;
              if (status == 'COMPLETED') statusColor = Colors.green;
              if (status == 'EXPIRED') statusColor = Colors.red;
              if (status == 'CHAT_CONNECTED') statusColor = Colors.purple;
              if (status == 'ACTIVE') statusColor = Colors.orange;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.menu_book, size: 18),
                      const SizedBox(width: 8),
                      Text(r['partnerNickname'] ?? '???',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(status,
                          style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text('라운드 ${r['roundNumber'] ?? r['roundCount'] ?? '-'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const SizedBox(width: 12),
                      Text('${r['currentTurn'] ?? r['turnCount'] ?? 0}/4 턴',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      const Spacer(),
                      if (r['createdAt'] != null)
                        Text(r['createdAt'].toString().substring(0, 10),
                          style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    ]),
                  ]),
                ),
              );
            },
          ),
    );
  }
}

// ══════════════════════════════════════
// 채팅 히스토리 화면
// ══════════════════════════════════════
class ChatHistoryScreen extends StatelessWidget {
  final dynamic data;
  const ChatHistoryScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final rooms = (data is Map && data['chatRooms'] != null) ? data['chatRooms'] as List
      : (data is Map && data['rooms'] != null) ? data['rooms'] as List
      : (data is List ? data : []);

    return Scaffold(
      appBar: AppBar(title: Text('채팅 히스토리 (${rooms.length})')),
      body: rooms.isEmpty
        ? const Center(child: Text('채팅 기록이 없습니다', style: TextStyle(color: Colors.white54)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: rooms.length,
            itemBuilder: (_, i) {
              final r = rooms[i];
              final status = r['status'] ?? '';
              Color statusColor = Colors.grey;
              if (status == 'ACTIVE') statusColor = Colors.blue;
              if (status == 'COUPLE_CONFIRMED') statusColor = Colors.pink;
              if (status == 'CHAT_LEFT') statusColor = Colors.grey;

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Icon(
                      status == 'COUPLE_CONFIRMED' ? Icons.favorite : Icons.chat,
                      color: statusColor, size: 20),
                  ),
                  title: Text(r['partnerNickname'] ?? '???', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (r['lastMessage'] != null)
                      Text(r['lastMessage'], maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Colors.white54)),
                    Text(status, style: TextStyle(fontSize: 11, color: statusColor)),
                  ]),
                  trailing: r['lastMessageAt'] != null
                    ? Text(r['lastMessageAt'].toString().substring(0, 10),
                        style: const TextStyle(fontSize: 11, color: Colors.white38))
                    : null,
                ),
              );
            },
          ),
    );
  }
}

// ══════════════════════════════════════
// 공지사항 목록 화면
// ══════════════════════════════════════
class NoticeListScreen extends StatefulWidget {
  final dynamic data;
  const NoticeListScreen({super.key, required this.data});

  @override
  State<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends State<NoticeListScreen> {
  final app = AppState();
  List<dynamic> banners = [];
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    try {
      final results = await Future.wait([
        app.dio.get('${app.baseUrl}/api/notices/banners', options: app.authHeaders).catchError((_) => Response(requestOptions: RequestOptions(), data: {'data': {'banners': []}})),
        app.dio.get('${app.baseUrl}/api/notices/unread-count', options: app.authHeaders).catchError((_) => Response(requestOptions: RequestOptions(), data: {'data': {'count': 0}})),
      ]);
      setState(() {
        banners = results[0].data['data']['banners'] ?? results[0].data['data'] ?? [];
        unreadCount = results[1].data['data']['count'] ?? results[1].data['data']['unreadCount'] ?? 0;
      });
    } catch (_) {}
  }

  List<dynamic> get notices {
    if (widget.data is Map && widget.data['notices'] != null) return widget.data['notices'];
    if (widget.data is List) return widget.data;
    return [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('공지사항'),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
              child: Text('$unreadCount', style: const TextStyle(fontSize: 11, color: Colors.white)),
            ),
          ],
        ]),
      ),
      body: Column(children: [
        // 배너 영역
        if (banners.isNotEmpty)
          SizedBox(
            height: 110,
            child: PageView.builder(
              itemCount: banners.length,
              itemBuilder: (_, i) {
                final b = banners[i] as Map<String, dynamic>;
                final imageUrl = b['imageUrl'] as String?;
                final linkUrl = b['linkUrl'] as String?;
                final isPinned = b['pinned'] == true || b['isPinned'] == true;
                return GestureDetector(
                  onTap: linkUrl != null && linkUrl.isNotEmpty
                    ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('링크: $linkUrl')))
                    : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.withOpacity(0.3), Colors.deepOrange.withOpacity(0.2)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(children: [
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Positioned.fill(
                          child: Image.network(imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                        ),
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        Positioned.fill(
                          child: Container(color: Colors.black.withOpacity(0.35)),
                        ),
                      if (isPinned)
                        const Positioned(
                          top: 6, left: 8,
                          child: Icon(Icons.push_pin, size: 14, color: Colors.amber),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          if (b['title'] != null)
                            Text(b['title'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (b['content'] != null) ...[
                            const SizedBox(height: 4),
                            Text(b['content'],
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          ],
                          if (linkUrl != null && linkUrl.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            const Text('자세히 보기 →', style: TextStyle(fontSize: 10, color: Colors.amberAccent)),
                          ],
                        ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        // 공지 목록
        Expanded(
          child: notices.isEmpty
            ? const Center(child: Text('공지사항이 없습니다', style: TextStyle(color: Colors.white54)))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: notices.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final n = notices[i];
                  final isPinned = n['pinned'] == true || n['isPinned'] == true;
                  return ListTile(
                    leading: isPinned
                      ? const Icon(Icons.push_pin, color: Colors.orange, size: 20)
                      : const Icon(Icons.article_outlined, size: 20),
                    title: Text(n['title'] ?? '', style: TextStyle(
                      fontWeight: isPinned ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(n['createdAt']?.toString().substring(0, 10) ?? ''),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => _showDetail(n),
                  );
                },
              ),
        ),
      ]),
    );
  }

  void _showDetail(Map<String, dynamic> notice) async {
    final id = notice['noticeId'] ?? notice['id'];
    if (id == null) return;
    try {
      final res = await app.dio.get('${app.baseUrl}/api/notices/$id', options: app.authHeaders);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => NoticeDetailScreen(notice: res.data['data'])));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }
}

class NoticeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> notice;
  const NoticeDetailScreen({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('공지사항')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (notice['pinned'] == true || notice['isPinned'] == true)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('고정 공지', style: TextStyle(fontSize: 11, color: Colors.orange)),
            ),
          Text(notice['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(notice['createdAt']?.toString().substring(0, 10) ?? '',
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
          const Divider(height: 24),
          Text(notice['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.7)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════
// FAQ 화면
// ══════════════════════════════════════
class FaqScreen extends StatelessWidget {
  final dynamic data;
  const FaqScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final faqs = (data is Map && data['faqs'] != null) ? data['faqs'] as List
      : (data is List ? data : []);

    return Scaffold(
      appBar: AppBar(title: const Text('자주 묻는 질문')),
      body: faqs.isEmpty
        ? const Center(child: Text('FAQ가 없습니다', style: TextStyle(color: Colors.white54)))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: faqs.length,
            itemBuilder: (_, i) {
              final f = faqs[i];
              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ExpansionTile(
                  leading: const Icon(Icons.help_outline, size: 20),
                  title: Text(f['question'] ?? f['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: f['category'] != null
                    ? Text(f['category'], style: const TextStyle(fontSize: 11, color: Colors.white38))
                    : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Text(f['answer'] ?? f['content'] ?? '', style: const TextStyle(height: 1.6, color: Colors.white70)),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }
}

// ══════════════════════════════════════
// 내 문의 목록 화면
// ══════════════════════════════════════
class InquiryListScreen extends StatelessWidget {
  final dynamic data;
  const InquiryListScreen({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final app = AppState();
    final inquiries = (data is Map && data['inquiries'] != null) ? data['inquiries'] as List
      : (data is List ? data : []);

    return Scaffold(
      appBar: AppBar(title: Text('내 문의 (${inquiries.length})')),
      body: inquiries.isEmpty
        ? const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.support_agent, size: 64, color: Colors.white24),
              SizedBox(height: 12),
              Text('문의 내역이 없습니다', style: TextStyle(color: Colors.white54)),
            ],
          ))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: inquiries.length,
            itemBuilder: (_, i) {
              final inq = inquiries[i];
              final status = inq['status'] ?? '';
              final isAnswered = status == 'ANSWERED' || status == 'COMPLETED';

              return Card(
                child: ListTile(
                  leading: Icon(
                    isAnswered ? Icons.check_circle : Icons.hourglass_top,
                    color: isAnswered ? Colors.greenAccent : Colors.amber,
                  ),
                  title: Text(inq['title'] ?? '', style: const TextStyle(fontSize: 14)),
                  subtitle: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: isAnswered ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(isAnswered ? '답변완료' : '대기중',
                        style: TextStyle(fontSize: 10, color: isAnswered ? Colors.greenAccent : Colors.amber)),
                    ),
                    const SizedBox(width: 8),
                    Text(inq['createdAt']?.toString().substring(0, 10) ?? '',
                      style: const TextStyle(fontSize: 11)),
                  ]),
                  trailing: const Icon(Icons.chevron_right, size: 18),
                  onTap: () async {
                    final id = inq['inquiryId'] ?? inq['id'];
                    if (id == null) return;
                    try {
                      final res = await app.dio.get('${app.baseUrl}/api/support/inquiries/$id',
                        options: app.authHeaders);
                      if (context.mounted) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => InquiryDetailScreen(inquiry: res.data['data'])));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
                      }
                    }
                  },
                ),
              );
            },
          ),
    );
  }
}

class InquiryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> inquiry;
  const InquiryDetailScreen({super.key, required this.inquiry});

  @override
  Widget build(BuildContext context) {
    final status = inquiry['status'] ?? '';
    final isAnswered = status == 'ANSWERED' || status == 'COMPLETED';

    return Scaffold(
      appBar: AppBar(title: const Text('문의 상세')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 상태 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAnswered ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isAnswered ? '답변 완료' : '답변 대기중',
              style: TextStyle(color: isAnswered ? Colors.greenAccent : Colors.amber, fontSize: 12)),
          ),
          const SizedBox(height: 12),
          Text(inquiry['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(inquiry['createdAt']?.toString().substring(0, 10) ?? '',
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
          if (inquiry['category'] != null) ...[
            const SizedBox(height: 4),
            Text('카테고리: ${inquiry['category']}', style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ],
          const Divider(height: 24),
          const Text('문의 내용', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
          const SizedBox(height: 8),
          Text(inquiry['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.6)),
          if (inquiry['answer'] != null || inquiry['reply'] != null) ...[
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.2)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('관리자 답변', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent, fontSize: 13)),
                const SizedBox(height: 8),
                Text(inquiry['answer'] ?? inquiry['reply'] ?? '', style: const TextStyle(height: 1.6)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════
// 앱 설정 화면
// ══════════════════════════════════════
class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final app = AppState();
  bool darkMode = true;
  String language = 'ko';
  bool ageFilter = false;

  Future<void> _updateSetting(Map<String, dynamic> data) async {
    try {
      await app.dio.patch('${app.baseUrl}/api/users/me/settings',
        data: data, options: app.authHeaders);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('설정 저장됨')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('앱 설정')),
      body: ListView(children: [
        SwitchListTile(
          secondary: const Icon(Icons.dark_mode),
          title: const Text('다크 모드'),
          value: darkMode,
          onChanged: (v) {
            setState(() => darkMode = v);
            _updateSetting({'darkMode': v});
          },
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.language),
          title: const Text('언어'),
          trailing: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ko', label: Text('한국어')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {language},
            onSelectionChanged: (s) {
              setState(() => language = s.first);
              _updateSetting({'language': s.first});
            },
            style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.filter_alt),
          title: const Text('연령 필터'),
          subtitle: const Text('같은 연령대만 매칭'),
          value: ageFilter,
          onChanged: (v) {
            setState(() => ageFilter = v);
            _updateSetting({'ageFilter': v});
          },
        ),
      ]),
    );
  }
}

// ── 교환일기 바디 래퍼 ──
class _ExchangeBody extends StatelessWidget {
  const _ExchangeBody();
  @override
  Widget build(BuildContext context) => const ExchangeTab(standaloneAppBar: false);
}

// ── 채팅 바디 래퍼 ──
class _ChatBody extends StatelessWidget {
  const _ChatBody();
  @override
  Widget build(BuildContext context) => const ChatTab(standaloneAppBar: false);
}

// ══════════════════════════════════════
// 6. 교환일기 탭
// ══════════════════════════════════════
class ExchangeTab extends StatefulWidget {
  final bool standaloneAppBar;
  const ExchangeTab({super.key, this.standaloneAppBar = true});

  @override
  State<ExchangeTab> createState() => _ExchangeTabState();
}

class _ExchangeTabState extends State<ExchangeTab> {
  final app = AppState();
  List<dynamic> rooms = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await app.dio.get('${app.baseUrl}/api/exchange-rooms', options: app.authHeaders);
      setState(() {
        rooms = res.data['data']['rooms'] ?? [];
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.standaloneAppBar ? AppBar(title: const Text('교환일기')) : null,
      body: loading
        ? const Center(child: CircularProgressIndicator())
        : rooms.isEmpty
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.swap_horiz, size: 64, color: Colors.white24),
                SizedBox(height: 12),
                Text('진행 중인 교환일기가 없어요', style: TextStyle(color: Colors.white54)),
                SizedBox(height: 8),
                Text('탐색 탭에서 매칭을 시작해보세요!', style: TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: rooms.length,
                itemBuilder: (_, i) => _buildRoomCard(rooms[i]),
              ),
            ),
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final status = room['status'] as String;
    final isMyTurn = room['isMyTurn'] == true;
    final turn = room['currentTurn'] ?? 0;
    final partner = room['partnerNickname'] ?? '???';

    Color statusColor = Colors.grey;
    String statusText = status;
    if (status == 'ACTIVE') {
      statusColor = isMyTurn ? Colors.orangeAccent : Colors.blueAccent;
      statusText = isMyTurn ? '내 차례' : '상대 차례';
    } else if (status == 'COMPLETED') {
      statusColor = Colors.greenAccent;
      statusText = '완주! 관계 확장 선택';
    } else if (status == 'EXPIRED') {
      statusColor = Colors.redAccent;
      statusText = '만료됨';
    } else if (status == 'CHAT_CONNECTED') {
      statusColor = Colors.purpleAccent;
      statusText = '채팅 연결됨';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ExchangeRoomScreen(roomId: room['roomId']))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.menu_book, size: 18, color: statusColor),
              const SizedBox(width: 8),
              Text(partner, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(statusText,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: List.generate(4, (i) {
              final done = i < turn;
              return Expanded(child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 3 : 0),
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: done ? statusColor.withOpacity(0.7) : Colors.grey[800],
                ),
              ));
            })),
            const SizedBox(height: 8),
            Row(children: [
              Text('$turn/4 턴', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const Spacer(),
              if (room['deadline'] != null)
                Row(children: [
                  Icon(Icons.schedule, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 3),
                  Text(_formatDeadline(room['deadline']),
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ]),
            ]),
          ]),
        ),
      ),
    );
  }

  String _formatDeadline(String deadline) {
    try {
      final dt = DateTime.parse(deadline);
      final diff = dt.difference(DateTime.now());
      if (diff.isNegative) return '만료';
      if (diff.inHours > 0) return '${diff.inHours}시간 남음';
      return '${diff.inMinutes}분 남음';
    } catch (_) {
      return '';
    }
  }
}

// ── 교환일기 방 상세 화면 ──
class ExchangeRoomScreen extends StatefulWidget {
  final int roomId;
  const ExchangeRoomScreen({super.key, required this.roomId});

  @override
  State<ExchangeRoomScreen> createState() => _ExchangeRoomScreenState();
}

class _ExchangeRoomScreenState extends State<ExchangeRoomScreen> {
  final app = AppState();
  Map<String, dynamic>? room;
  bool loading = true;
  final contentCtrl = TextEditingController();
  Timer? _countdownTimer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _load();
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateRemaining());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    if (!mounted || room == null) return;
    final deadline = room!['deadline'] as String?;
    if (deadline == null) {
      if (_remaining != null) setState(() => _remaining = null);
      return;
    }
    try {
      final dt = DateTime.parse(deadline);
      final diff = dt.difference(DateTime.now());
      setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    } catch (_) {}
  }

  String _formatRemaining(Duration d) {
    if (d.inSeconds <= 0) return '만료됨';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h >= 24) return '${d.inDays}일 ${h % 24}시간';
    if (h > 0) return '$h시간 $m분';
    return '$m분';
  }

  Future<void> _load() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/exchange-rooms/${widget.roomId}', options: app.authHeaders);
      setState(() { room = res.data['data']; loading = false; });
      _updateRemaining();
    } catch (e) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _writeDiary() async {
    final content = contentCtrl.text.trim();
    if (content.length < 200) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('200자 이상 작성해주세요.')));
      return;
    }
    try {
      final res = await app.dio.post('${app.baseUrl}/api/exchange-rooms/${widget.roomId}/diaries',
        data: {'content': content}, options: app.authHeaders);
      final data = res.data['data'];
      contentCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['isCompleted'] == true
            ? '4턴 완주! 관계 확장을 선택해주세요.'
            : '교환일기 작성 완료! (턴 ${data['nextTurn']})')));
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _addReaction(int diaryId, String reaction) async {
    try {
      await app.dio.post('${app.baseUrl}/api/exchange-rooms/${widget.roomId}/diaries/$diaryId/reaction',
        data: {'reaction': reaction}, options: app.authHeaders);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$reaction 리액션 완료!')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _openDiaryRead(int diaryId) async {
    try {
      final res = await app.dio.get(
        '${app.baseUrl}/api/exchange-rooms/${widget.roomId}/diaries/$diaryId',
        options: app.authHeaders);
      final data = res.data['data'] as Map<String, dynamic>;
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.grey[900],
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 14),
              Row(children: [
                Icon(Icons.auto_stories, size: 18, color: Colors.blue[300]),
                const SizedBox(width: 6),
                Text('${data['turnNumber'] ?? ''}번째 일기',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (data['readAt'] != null)
                  Text('읽음 ✓', style: TextStyle(fontSize: 11, color: Colors.green[300])),
              ]),
              const SizedBox(height: 14),
              Text(data['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.7)),
              const SizedBox(height: 16),
              if (data['createdAt'] != null)
                Text('작성: ${(data['createdAt'] as String).substring(0, 16).replaceAll('T', ' ')}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
          ),
        ),
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _createChatRoom() async {
    try {
      final res = await app.dio.post(
        '${app.baseUrl}/api/exchange-rooms/${widget.roomId}/chat',
        options: app.authHeaders);
      final data = res.data['data'] as Map<String, dynamic>;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('채팅방 생성 완료 (id: ${data['chatRoomId']})'),
        duration: const Duration(seconds: 2)));
      Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const HomeScreen(initialTab: 2)),
        (_) => false);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _chooseNextStep(String choice) async {
    try {
      final res = await app.dio.post('${app.baseUrl}/api/exchange-rooms/${widget.roomId}/next-step',
        data: {'choice': choice}, options: app.authHeaders);
      final data = res.data['data'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('결과: ${data['status']}')));
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _viewReport() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/exchange-rooms/${widget.roomId}/report', options: app.authHeaders);
      final data = res.data['data'] as Map<String, dynamic>;
      if (!mounted) return;

      final emotion = data['emotionSimilarity'];
      final emotionPct = emotion is num ? (emotion * 100).toInt() : null;
      final tempA = data['writingTempA'] as String?;
      final tempB = data['writingTempB'] as String?;

      showDialog(context: context, builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: const [
                Icon(Icons.celebration, color: Colors.amber, size: 22),
                SizedBox(width: 8),
                Text('우리의 공통점', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),

              // 공통 키워드
              if (data['commonKeywords'] != null && (data['commonKeywords'] as List).isNotEmpty) ...[
                const Text('공통 키워드', style: TextStyle(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: (data['commonKeywords'] as List).map((k) =>
                  Chip(label: Text('#$k', style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.orange.withOpacity(0.25),
                    side: BorderSide(color: Colors.orange.withOpacity(0.4)))).toList()),
                const SizedBox(height: 16),
              ],

              // 감정 유사도
              if (emotionPct != null) ...[
                const Text('감정 유사도', style: TextStyle(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (emotion / 1.0).toDouble(),
                      minHeight: 10,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Text('$emotionPct%', style: const TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 16),
              ],

              // 라이프스타일 패턴
              if (data['lifestylePatterns'] != null && (data['lifestylePatterns'] as List).isNotEmpty) ...[
                const Text('공통 라이프스타일', style: TextStyle(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: (data['lifestylePatterns'] as List).map((p) =>
                  Chip(label: Text(p.toString(), style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.teal.withOpacity(0.25),
                    side: BorderSide(color: Colors.teal.withOpacity(0.5)))).toList()),
                const SizedBox(height: 16),
              ],

              // 글쓰기 톤 비교
              if (tempA != null || tempB != null) ...[
                const Text('글쓰기 온도', style: TextStyle(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: _tempCard('나', tempA, Colors.orangeAccent)),
                  const SizedBox(width: 8),
                  Expanded(child: _tempCard('상대', tempB, Colors.blueAccent)),
                ]),
                const SizedBox(height: 16),
              ],

              // AI 한줄 설명
              if (data['aiDescription'] != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Colors.purple.withOpacity(0.15),
                      Colors.pink.withOpacity(0.1),
                    ]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(data['aiDescription'],
                      style: const TextStyle(color: Colors.purpleAccent, height: 1.5, fontSize: 13))),
                  ]),
                ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
              ),
            ]),
          ),
        ),
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Widget _tempCard(String who, String? temp, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.4)),
    ),
    child: Column(children: [
      Text(who, style: TextStyle(fontSize: 10, color: color)),
      const SizedBox(height: 4),
      Text(temp ?? '-', style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold)),
    ]),
  );

  Future<void> _checkNextStepStatus() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/exchange-rooms/${widget.roomId}/next-step/status',
        options: app.authHeaders);
      final data = res.data['data'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('내 선택: ${data['myChoice'] ?? '미선택'} | 상대: ${data['partnerChose'] == true ? '완료' : '대기중'} | 상태: ${data['status']}')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    if (room == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('방 정보 로드 실패')));

    final diaries = (room!['diaries'] as List?) ?? [];
    final status = room!['status'] as String;
    final isMyTurn = room!['isMyTurn'] == true;
    final partner = room!['partner'];

    final totalTurns = (room!['totalTurns'] ?? 4) as int;
    final currentTurn = (room!['currentTurn'] ?? 0) as int;

    return Scaffold(
      appBar: AppBar(
        title: Text('${partner['nickname']}님과의 교환일기'),
        actions: [
          if (status == 'COMPLETED' || status == 'CHAT_CONNECTED' || status == 'ARCHIVED')
            IconButton(icon: const Icon(Icons.analytics), onPressed: _viewReport, tooltip: '리포트'),
          if (status == 'COMPLETED')
            IconButton(icon: const Icon(Icons.info_outline), onPressed: _checkNextStepStatus, tooltip: '선택 상태'),
        ],
      ),
      body: Column(children: [
        // ── 데드라인 카운트다운 (내 차례 + 데드라인 있을 때) ──
        if (status == 'ACTIVE' && isMyTurn && _remaining != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _remaining!.inHours < 12
                ? Colors.red.withOpacity(0.15)
                : _remaining!.inHours < 24
                  ? Colors.orange.withOpacity(0.15)
                  : Colors.blue.withOpacity(0.10),
              border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(children: [
              Icon(Icons.timer_outlined, size: 16,
                color: _remaining!.inHours < 12 ? Colors.redAccent : _remaining!.inHours < 24 ? Colors.orangeAccent : Colors.blueAccent),
              const SizedBox(width: 6),
              Text('남은 시간: ',
                style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              Text(_formatRemaining(_remaining!),
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: _remaining!.inHours < 12 ? Colors.redAccent : _remaining!.inHours < 24 ? Colors.orangeAccent : Colors.blueAccent,
                )),
              const Spacer(),
              if (_remaining!.inHours < 24)
                Text('내 차례 만료 임박', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
          ),

        // ── 턴 진행 프로그레스 ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            border: Border(bottom: BorderSide(color: Colors.grey[800]!)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.menu_book, size: 18, color: Colors.orange[300]),
              const SizedBox(width: 6),
              Text('라운드 ${room!['roundNumber']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'COMPLETED'
                    ? Colors.green.withOpacity(0.2)
                    : isMyTurn ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status == 'COMPLETED' ? '완주!' : isMyTurn ? '내 차례' : '상대 차례',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold,
                    color: status == 'COMPLETED' ? Colors.greenAccent : isMyTurn ? Colors.orangeAccent : Colors.blueAccent,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: List.generate(totalTurns, (i) {
              final turnNum = i + 1;
              final done = turnNum <= diaries.length;
              final isCurrent = turnNum == currentTurn && status == 'ACTIVE';
              return Expanded(child: Container(
                margin: EdgeInsets.only(right: i < totalTurns - 1 ? 4 : 0),
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: done ? Colors.orange[400]
                    : isCurrent ? Colors.orange.withOpacity(0.4)
                    : Colors.grey[700],
                ),
              ));
            })),
            const SizedBox(height: 6),
            Text('$currentTurn / $totalTurns 턴 진행됨',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
        ),

        // ── 일기 목록 (일기장 스타일) ──
        Expanded(child: diaries.isEmpty
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories, size: 56, color: Colors.grey[700]),
                const SizedBox(height: 12),
                Text('아직 작성된 일기가 없습니다', style: TextStyle(color: Colors.grey[600])),
                if (status == 'ACTIVE' && isMyTurn) ...[
                  const SizedBox(height: 8),
                  Text('첫 번째 일기를 작성해보세요!', style: TextStyle(color: Colors.orange[300], fontSize: 13)),
                ],
              ],
            ))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: diaries.length,
                separatorBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(children: [
                    Expanded(child: Divider(color: Colors.grey[800], thickness: 0.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.swap_vert, size: 14, color: Colors.grey[700]),
                    ),
                    Expanded(child: Divider(color: Colors.grey[800], thickness: 0.5)),
                  ]),
                ),
                itemBuilder: (_, i) {
                  final d = diaries[i];
                  final isMe = d['authorId'] == app.userId;
                  final writerName = isMe ? '나의 일기' : '${partner['nickname']}의 일기';
                  final turnNum = d['turnNumber'] ?? (i + 1);
                  final createdAt = d['createdAt'] as String? ?? '';
                  final dateStr = createdAt.length >= 10 ? createdAt.substring(5, 10).replaceAll('-', '/') : '';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.grey[850] ?? const Color(0xFF1E1E1E),
                      border: Border.all(
                        color: isMe ? Colors.orange.withOpacity(0.25) : Colors.blue.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: !isMe && d['diaryId'] != null
                      ? () => _openDiaryRead(d['diaryId'] as int)
                      : null,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.orange.withOpacity(0.08) : Colors.blue.withOpacity(0.06),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: Row(children: [
                          Icon(isMe ? Icons.edit_note : Icons.auto_stories,
                            size: 16, color: isMe ? Colors.orange[300] : Colors.blue[300]),
                          const SizedBox(width: 6),
                          Text(writerName, style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: isMe ? Colors.orange[300] : Colors.blue[300],
                          )),
                          const Spacer(),
                          Text('$turnNum번째', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          if (dateStr.isNotEmpty) ...[
                            Text(' · $dateStr', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                          ],
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Text(d['content'] ?? '',
                          style: const TextStyle(fontSize: 14.5, height: 1.7, letterSpacing: 0.1)),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                        child: Row(children: [
                          if (d['reaction'] != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(_reactionEmoji(d['reaction']),
                                style: const TextStyle(fontSize: 16)),
                            ),
                          const Spacer(),
                          if (!isMe && d['reaction'] == null)
                            Row(children: ['HEART', 'HAPPY', 'SAD', 'FIRE'].map((r) =>
                              GestureDetector(
                                onTap: () => _addReaction(d['diaryId'], r),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(_reactionEmoji(r), style: const TextStyle(fontSize: 20)),
                                ),
                              ),
                            ).toList()),
                        ]),
                      ),
                    ]),
                    ),
                  );
                },
              ),
            )),

        // ── 작성 버튼 (내 차례일 때) ──
        if (status == 'ACTIVE' && isMyTurn)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: () => _showWriteSheet(context),
              icon: const Icon(Icons.edit),
              label: Text('${currentTurn}번째 일기 쓰기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ),

        // ── 상대 차례 안내 ──
        if (status == 'ACTIVE' && !isMyTurn)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.06),
              border: Border(top: BorderSide(color: Colors.grey[800]!)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.hourglass_top, size: 16, color: Colors.blue[300]),
              const SizedBox(width: 6),
              Text('${partner['nickname']}님이 일기를 작성중이에요',
                style: TextStyle(color: Colors.blue[300], fontSize: 13)),
            ]),
          ),

        // ── 채팅방 생성 (양측 CHAT 선택 후) ──
        if (status == 'CHAT_CONNECTED' && room!['chatRoomCreated'] != true)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: Border(top: BorderSide(color: Colors.blue.withOpacity(0.3)))),
            child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _createChatRoom,
              icon: const Icon(Icons.chat_bubble),
              label: const Text('채팅방 입장'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
          ),

        // ── 관계 확장 선택 (COMPLETED 상태) ──
        if (status == 'COMPLETED' && room!['nextStepRequired'] == true)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.06),
              border: Border(top: BorderSide(color: Colors.green.withOpacity(0.2)))),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.celebration, size: 18, color: Colors.greenAccent),
                const SizedBox(width: 6),
                const Text('교환일기 완주!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              ]),
              const SizedBox(height: 4),
              Text('다음 단계를 선택해주세요', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => _chooseNextStep('CHAT'),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('채팅 시작'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _chooseNextStep('CONTINUE'),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('교환 계속'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
            ]),
          ),
      ]),
    );
  }

  void _showWriteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: StatefulBuilder(builder: (ctx, setSheetState) {
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 14),
            Row(children: [
              Icon(Icons.edit_note, color: Colors.orange[300], size: 20),
              const SizedBox(width: 6),
              Text('${room!['currentTurn']}번째 교환일기', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 8,
              autofocus: true,
              style: const TextStyle(fontSize: 15, height: 1.6),
              decoration: InputDecoration(
                hintText: '오늘 하루를 돌아보며 솔직하게 적어보세요...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.orange[400]!),
                ),
              ),
              onChanged: (_) => setSheetState(() {}),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('${contentCtrl.text.length}자',
                style: TextStyle(fontSize: 12, color: contentCtrl.text.length >= 200 ? Colors.green[400] : Colors.grey[500])),
              Text(' / 200~1,000자', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const Spacer(),
            ]),
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: contentCtrl.text.trim().length >= 200 ? () {
                Navigator.pop(ctx);
                _writeDiary();
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                disabledBackgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('일기 제출', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            )),
          ]);
        }),
      ),
    );
  }

  String _reactionEmoji(String reaction) {
    switch (reaction) {
      case 'HEART': return '❤️';
      case 'SAD': return '😢';
      case 'HAPPY': return '😊';
      case 'FIRE': return '🔥';
      default: return reaction;
    }
  }
}

// ══════════════════════════════════════
// 7~8. 채팅 + 커플 탭
// ══════════════════════════════════════
class ChatTab extends StatefulWidget {
  final bool standaloneAppBar;
  const ChatTab({super.key, this.standaloneAppBar = true});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final app = AppState();
  List<dynamic> chatRooms = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await app.dio.get('${app.baseUrl}/api/chat-rooms', options: app.authHeaders);
      setState(() {
        chatRooms = res.data['data']['chatRooms'] ?? [];
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.standaloneAppBar ? AppBar(title: const Text('채팅')) : null,
      body: loading
        ? const Center(child: CircularProgressIndicator())
        : chatRooms.isEmpty
          ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.white24),
                SizedBox(height: 12),
                Text('채팅방이 없어요', style: TextStyle(color: Colors.white54)),
                SizedBox(height: 8),
                Text('교환일기 완료 후 채팅이 시작됩니다', style: TextStyle(color: Colors.white38, fontSize: 13)),
              ],
            ))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                itemCount: chatRooms.length,
                itemBuilder: (_, i) => _buildChatRoomCard(chatRooms[i]),
              ),
            ),
    );
  }

  Widget _buildChatRoomCard(Map<String, dynamic> room) {
    final status = room['status'] as String;
    Color statusColor = Colors.blueAccent;
    if (status == 'COUPLE_CONFIRMED') statusColor = Colors.pinkAccent;
    if (status == 'CHAT_LEFT') statusColor = Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(status == 'COUPLE_CONFIRMED' ? Icons.favorite : Icons.chat, color: statusColor, size: 20),
        ),
        title: Text(room['partnerNickname'] ?? '???', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(room['lastMessage'] ?? '대화를 시작해보세요', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (room['lastMessageAt'] != null)
            Text(_formatTime(room['lastMessageAt']), style: const TextStyle(fontSize: 11, color: Colors.white38)),
          if ((room['unreadCount'] ?? 0) > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(10)),
              child: Text('${room['unreadCount']}', style: const TextStyle(fontSize: 11, color: Colors.black)),
            ),
          ],
        ]),
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ChatRoomScreen(chatRoomId: room['chatRoomId'], partnerName: room['partnerNickname'] ?? '???'))),
      ),
    );
  }

  String _formatTime(String time) {
    try {
      final dt = DateTime.parse(time);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}

// ── 채팅방 상세 화면 ──
class ChatRoomScreen extends StatefulWidget {
  final int chatRoomId;
  final String partnerName;
  const ChatRoomScreen({super.key, required this.chatRoomId, required this.partnerName});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final app = AppState();
  final msgCtrl = TextEditingController();
  final scrollCtrl = ScrollController();
  List<dynamic> messages = [];
  bool loading = true;
  bool hasMore = false;
  bool sending = false;
  StompClient? _stomp;
  bool _stompConnected = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectStomp();
  }

  @override
  void dispose() {
    _stomp?.deactivate();
    super.dispose();
  }

  void _connectStomp() {
    final wsUrl = '${app.baseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://')}/ws/chat';
    _stomp = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (frame) {
          if (!mounted) return;
          setState(() => _stompConnected = true);
          _stomp!.subscribe(
            destination: '/topic/chat/${widget.chatRoomId}',
            callback: _onStompMessage,
          );
        },
        onDisconnect: (_) {
          if (mounted) setState(() => _stompConnected = false);
        },
        onWebSocketError: (e) => debugPrint('[STOMP] error: $e'),
        onStompError: (frame) => debugPrint('[STOMP] error frame: ${frame.body}'),
        stompConnectHeaders: {'Authorization': 'Bearer ${app.accessToken}'},
        webSocketConnectHeaders: {'Authorization': 'Bearer ${app.accessToken}'},
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _stomp!.activate();
  }

  void _onStompMessage(StompFrame frame) {
    if (frame.body == null || !mounted) return;
    try {
      final msg = jsonDecode(frame.body!);
      final seqId = msg['sequenceId'] ?? msg['messageId'];
      final dup = messages.any((m) => (m['sequenceId'] ?? m['messageId']) == seqId);
      if (!dup) {
        setState(() => messages.add(msg));
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('[STOMP] parse error: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _loadMessages({int? before}) async {
    try {
      final params = <String, dynamic>{'size': 30};
      if (before != null) params['before'] = before;
      final res = await app.dio.get('${app.baseUrl}/api/chat-rooms/${widget.chatRoomId}/messages',
        queryParameters: params, options: app.authHeaders);
      final data = res.data['data'];
      setState(() {
        if (before != null) {
          messages.insertAll(0, data['messages'] ?? []);
        } else {
          messages = List.from(data['messages'] ?? []);
        }
        hasMore = data['hasMore'] == true;
        loading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _send() async {
    final content = msgCtrl.text.trim();
    if (content.isEmpty || sending) return;
    setState(() => sending = true);

    try {
      await app.dio.post('${app.baseUrl}/api/chat-rooms/${widget.chatRoomId}/messages',
        data: {'content': content, 'type': 'TEXT'}, options: app.authHeaders);
      msgCtrl.clear();
      // STOMP 미연결 시에만 REST로 강제 갱신 (정상 시 subscription으로 자동 수신)
      if (!_stompConnected) await _loadMessages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
    setState(() => sending = false);
  }

  int? _calcAge(String? birthDate) {
    if (birthDate == null || birthDate.length < 10) return null;
    try {
      final dob = DateTime.parse(birthDate);
      final now = DateTime.now();
      int age = now.year - dob.year;
      if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
      return age;
    } catch (_) { return null; }
  }

  Future<void> _showPartnerProfile() async {
    try {
      final res = await app.dio.get('${app.baseUrl}/api/chat-rooms/${widget.chatRoomId}/profile',
        options: app.authHeaders);
      final p = res.data['data'] as Map<String, dynamic>;
      if (!mounted) return;

      final age = _calcAge(p['birthDate'] as String?);
      final gender = p['gender'] as String?;
      final genderLabel = gender == 'MALE' ? '남성' : gender == 'FEMALE' ? '여성' : null;
      final sido = p['sido'] as String?;
      final tags = (p['personalityTags'] ?? p['personalityKeywords']) as List? ?? [];
      final partnerUserId = p['userId'] as int?;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),

            // 닉네임 + 아바타
            Row(children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.orange.withOpacity(0.2),
                child: const Icon(Icons.person, size: 28, color: Colors.orangeAccent),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(p['nickname'] ?? '익명',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, children: [
                  if (age != null)
                    Text('만 $age세', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  if (genderLabel != null)
                    Text('· $genderLabel', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  if (sido != null)
                    Text('· $sido', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ]),
              ])),
            ]),

            const SizedBox(height: 20),
            Divider(color: Colors.grey[800], height: 1),
            const SizedBox(height: 16),

            // AI 키워드
            const Row(children: [
              Icon(Icons.auto_awesome, size: 14, color: Colors.purpleAccent),
              SizedBox(width: 6),
              Text('성격 키워드', style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            if (tags.isEmpty)
              Text('분석된 키워드가 없습니다',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]))
            else
              Wrap(spacing: 6, runSpacing: 6, children: tags.map<Widget>((t) {
                final txt = t is String ? t : (t is Map ? (t['label'] ?? '').toString() : t.toString());
                return Chip(
                  label: Text('#$txt', style: const TextStyle(fontSize: 12)),
                  backgroundColor: Colors.purple.withOpacity(0.2),
                  side: BorderSide(color: Colors.purple.withOpacity(0.4)),
                  visualDensity: VisualDensity.compact,
                );
              }).toList()),

            const SizedBox(height: 20),
            Divider(color: Colors.grey[800], height: 1),
            const SizedBox(height: 12),

            // 액션
            Column(children: [
              if (partnerUserId != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag_outlined, color: Colors.orangeAccent),
                  title: const Text('신고하기', style: TextStyle(fontSize: 14)),
                  onTap: () { Navigator.pop(ctx); _reportPartner(partnerUserId); },
                ),
              if (partnerUserId != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_off_outlined, color: Colors.redAccent),
                  title: const Text('차단하기', style: TextStyle(fontSize: 14)),
                  onTap: () { Navigator.pop(ctx); _blockPartner(partnerUserId); },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.exit_to_app, color: Colors.redAccent),
                title: const Text('채팅방 나가기', style: TextStyle(fontSize: 14, color: Colors.redAccent)),
                onTap: () { Navigator.pop(ctx); _leaveChatRoom(); },
              ),
            ]),
          ]),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _reportPartner(int userId) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('신고하기'),
      content: const Text('이 사용자를 신고하시겠어요?\n(사유: HARASSMENT)'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('신고', style: TextStyle(color: Colors.redAccent))),
      ],
    ));
    if (confirmed != true) return;
    try {
      await app.dio.post('${app.baseUrl}/api/users/$userId/report',
        data: {'reason': 'HARASSMENT'}, options: app.authHeaders);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _blockPartner(int userId) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('차단하기'),
      content: const Text('차단하면 매칭/교환/채팅이 모두 종료됩니다.\n정말 차단하시겠어요?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('차단', style: TextStyle(color: Colors.redAccent))),
      ],
    ));
    if (confirmed != true) return;
    try {
      await app.dio.post('${app.baseUrl}/api/users/$userId/block', options: app.authHeaders);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('차단했습니다.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _sendCoupleRequest() async {
    try {
      final res = await app.dio.post('${app.baseUrl}/api/chat-rooms/${widget.chatRoomId}/couple-request',
        options: app.authHeaders);
      final data = res.data['data'];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('커플 요청 전송! (만료: ${data['expiresAt']})')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _acceptCouple() async {
    try {
      await app.dio.post('${app.baseUrl}/api/chat-rooms/${widget.chatRoomId}/couple-accept',
        options: app.authHeaders);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('커플이 되었습니다!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _rejectCouple() async {
    try {
      await app.dio.post('${app.baseUrl}/api/chat-rooms/${widget.chatRoomId}/couple-reject',
        options: app.authHeaders);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('커플 요청을 거절했습니다.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  Future<void> _leaveChatRoom() async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('채팅방 나가기'),
      content: const Text('나가면 다시 돌아올 수 없습니다. 정말 나가시겠어요?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(context, true),
          child: const Text('나가기', style: TextStyle(color: Colors.red))),
      ],
    ));
    if (confirmed != true) return;

    try {
      await app.dio.post('${app.baseUrl}/api/chat-rooms/${widget.chatRoomId}/leave', options: app.authHeaders);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('채팅방을 나갔습니다.')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(app.errMsg(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Text(widget.partnerName),
          const SizedBox(width: 8),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _stompConnected ? Colors.greenAccent : Colors.redAccent,
            ),
          ),
          const SizedBox(width: 4),
          Text(_stompConnected ? '실시간' : '오프라인',
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.person), onPressed: _showPartnerProfile, tooltip: '프로필'),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'couple_request') _sendCoupleRequest();
              if (v == 'couple_accept') _acceptCouple();
              if (v == 'couple_reject') _rejectCouple();
              if (v == 'leave') _leaveChatRoom();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'couple_request', child: Text('커플 요청')),
              const PopupMenuItem(value: 'couple_accept', child: Text('커플 수락')),
              const PopupMenuItem(value: 'couple_reject', child: Text('커플 거절')),
              const PopupMenuItem(value: 'leave', child: Text('나가기', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: loading
            ? const Center(child: CircularProgressIndicator())
            : messages.isEmpty
              ? const Center(child: Text('대화를 시작해보세요!', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  controller: scrollCtrl,
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe = msg['senderId'] == app.userId;
                    final isSystem = msg['type'] == 'SYSTEM';

                    if (isSystem) {
                      return Center(child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(msg['content'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ));
                    }

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.fromLTRB(isMe ? 64 : 8, 2, isMe ? 8 : 64, 2),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.orange.withOpacity(0.3) : Colors.grey[800],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(msg['content'] ?? '', style: const TextStyle(fontSize: 14)),
                          const SizedBox(height: 2),
                          Text(
                            msg['createdAt'] != null ? _formatMsgTime(msg['createdAt']) : '',
                            style: const TextStyle(fontSize: 10, color: Colors.white38),
                          ),
                          if (msg['isFlagged'] == true)
                            const Text('! 외부연락처 감지', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                        ]),
                      ),
                    );
                  },
                ),
        ),

        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey[900], border: Border(top: BorderSide(color: Colors.grey[800]!))),
            child: Row(children: [
              Expanded(child: TextField(
                controller: msgCtrl,
                decoration: const InputDecoration(
                  hintText: '메시지를 입력하세요',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: (_) => _send(),
              )),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send, color: sending ? Colors.grey : Colors.orangeAccent),
                onPressed: sending ? null : _send,
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  String _formatMsgTime(String time) {
    try {
      final dt = DateTime.parse(time);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}
