import 'package:flutter/material.dart';
import 'splash_screen.dart';
import 'social_login.dart';
import 'main_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';
import 'firebase_options.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  KakaoSdk.init(nativeAppKey: 'b411ab336a0428cb29968ac6a558f58e');

  runApp(const MyApp());

  initFcmToken();
}

Future<void> initFcmToken() async {
  try {
    await FirebaseMessaging.instance.requestPermission();

    final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    print('APNS token: $apnsToken');

    if (apnsToken == null) {
      print('APNS token 아직 준비 안 됨');
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    print('FCM token: $token');

    if (token != null) {
      await ApiService.registerFcmToken(token);
    }
  } catch (e) {
    print('FCM error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Ember',
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const SplashScreen(),
      routes: {
        '/socialLogin': (context) => const SocialLogin(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}