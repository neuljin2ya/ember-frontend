import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://ember-app.duckdns.org';

  // ────────────────────────────────────────────
  // 토큰 관리
  // ────────────────────────────────────────────

  static Future<void> saveToken(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refreshToken');
  }

  static Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
  }

  // ────────────────────────────────────────────
  // 공통 헤더
  // ────────────────────────────────────────────
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
  // ────────────────────────────────────────────
  // 토큰 갱신
  // ────────────────────────────────────────────

  static Future<bool> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveToken(data['accessToken'], data['refreshToken']);
      return true;
    }
    return false;
  }

  // ────────────────────────────────────────────
  // Dev 로그인 (테스트용)
  // ────────────────────────────────────────────

  static Future<Map<String, dynamic>> devRegister() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/dev/register'),
      headers: {'Content-Type': 'application/json'},
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final accessToken = data['accessToken'] ?? '';
      final refreshToken = data['refreshToken'] ?? ''; // null이면 빈 문자열로
      await saveToken(accessToken, refreshToken);
    }
    return data;
  }

  // ────────────────────────────────────────────
  // 카카오 로그인
  // ────────────────────────────────────────────

  static Future<Map<String, dynamic>> kakaoLogin(
      String kakaoAccessToken,
      String email,
      ) async {
    final requestBody = {
      'provider': 'KAKAO',
      'socialToken': kakaoAccessToken,
      'email': email,
    };

    print('보내는 body: $requestBody');

    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/social'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    print('statusCode: ${response.statusCode}');
    print('responseBody: ${response.body}');

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      await saveToken(
        data['accessToken'] ?? '',
        data['refreshToken'] ?? '',
      );
    }

    return data;
  }

  // ────────────────────────────────────────────
  // 약관 동의
  // ────────────────────────────────────────────

  static Future<bool> postConsent(String consentType) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/consent'),
      headers: headers,
      body: jsonEncode({
        'consentType': consentType,
        'validType': true,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // ────────────────────────────────────────────
  // 프로필 등록
  // ────────────────────────────────────────────

  static Future<Map<String, dynamic>> postProfile({
    required String nickname,
    required String realName,
    required String gender,
    required String birthDate,
    required String sido,
    required String sigungu,
  }) async {
    final headers = await _authHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/api/users/profile'),
      headers: headers,
      body: jsonEncode({
        'nickname': nickname,
        'realName': realName,
        'gender': gender,
        'birthDate': birthDate,
        'sido': sido,
        'sigungu': sigungu,
      }),
    );

    print('프로필 status: ${response.statusCode}');
    print('프로필 body: ${response.body}');

    if (response.body.isEmpty) {
      return {
        'code': response.statusCode.toString(),
        'message': 'EMPTY_RESPONSE',
        'data': null,
      };
    }

    return jsonDecode(response.body);
  }
  // ────────────────────────────────────────────
  // 이상형 키워드 목록 조회
  // ────────────────────────────────────────────

  static Future<List<String>> getIdealTypeKeywords() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/ideal-type/keyword-list'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['keywords'] ?? []);
    }
    return [];
  }
  static Future<Map<String, dynamic>> generateNickname() async {
    final headers = await _authHeaders();

    final response = await http.post(
      Uri.parse('$baseUrl/api/users/nickname/generate'),
      headers: headers,
    );

    print('닉네임 status: ${response.statusCode}');
    print('닉네임 body: ${response.body}');

    if (response.body.isEmpty) {
      return {};
    }

    if (response.body.isEmpty) {
      return {};
    }

    return jsonDecode(response.body);
  }
  // ────────────────────────────────────────────
  // 이상형 키워드 설정
  // ────────────────────────────────────────────

  static Future<bool> postIdealTypeKeywords(List<String> keywords) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/ideal-type/keywords'),
      headers: headers,
      body: jsonEncode({'keywords': keywords}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // ────────────────────────────────────────────
  // 일기 작성
  // ────────────────────────────────────────────

  static Future<Map<String, dynamic>> postDiary({
    required String content,
    String visibility = 'PRIVATE',
    int? topicId,
  }) async {
    final headers = await _authHeaders();

    final body = {
      'content': content,
      'visibility': visibility,
      if (topicId != null) 'topicId': topicId,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/api/diaries'),
      headers: headers,
      body: jsonEncode(body),
    );

    print('일기 status: ${response.statusCode}');
    print('일기 body: ${response.body}');

    if (response.body.isEmpty) {
      return {
        'code': response.statusCode.toString(),
        'message': 'EMPTY_RESPONSE',
        'data': null,
      };
    }

    return jsonDecode(response.body);
  }

  static Future<bool> selectMatching(int diaryId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/matching/$diaryId/select'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getMyProfile() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/me'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getMyIdealType() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/me/ideal-type'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<bool> updateProfile({
    String? nickname,
    String? region,
    String? job,
  }) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (region != null) body['region'] = region;
    if (job != null) body['job'] = job;

    final response = await http.patch(
      Uri.parse('$baseUrl/api/users/me/profile'),
      headers: headers,
      body: jsonEncode(body),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> updateIdealType(List<String> keywords) async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/users/me/ideal-type'),
      headers: headers,
      body: jsonEncode({'keywords': keywords}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }
  static Future<Map<String, dynamic>> getExchangeRooms() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/exchange-rooms'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }
  static Future<Map<String, dynamic>> getChatMessages(int roomId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/messages'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<bool> sendChatMessage(int roomId, String content) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/messages'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }
  static Future<Map<String, dynamic>> getNotifications() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/notifications'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<bool> postExchangeDiary({
    required int roomId,
    required String content,
    required String date,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/diaries'),
      headers: headers,
      body: jsonEncode({'content': content, 'date': date}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getExchangeDiaryDetail({
    required int roomId,
    required int diaryId,
  }) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/diaries/$diaryId'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<bool> submitInquiry(String content) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/support/inquiry'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // 4턴 완료 후 관계 확장
  static Future<bool> postNextStep(int roomId, String choice) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/next-step'),
      headers: headers,
      body: jsonEncode({'choice': choice}), // 'CHAT' or 'CONTINUE'
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

// FCM 토큰 등록
  static Future<bool> registerFcmToken(String token) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/me/fcm-token'),
      headers: headers,
      body: jsonEncode({'fcmToken': token}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

// 신고
  static Future<bool> reportUser(int targetUserId, String reason) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/$targetUserId/report'),
      headers: headers,
      body: jsonEncode({'reason': reason}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

// 차단
  static Future<bool> blockUser(int targetUserId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/$targetUserId/block'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> postExchangeDiaryReaction({
    required int roomId,
    required int diaryId,
    required String reaction,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/diaries/$diaryId/reaction'),
      headers: headers,
      body: jsonEncode({'reaction': reaction}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getChatRooms() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/chat-rooms'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<bool> acceptMatching(int matchingId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/matching/requests/$matchingId/accept'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> markNotificationRead(int id) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/api/notifications/$id/read'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }
  static Future<bool> skipMatching(int diaryId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/matching/$diaryId/skip'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }
  // ────────────────────────────────────────────
  // 일기 탐색
  // ────────────────────────────────────────────

  static Future<Map<String, dynamic>> exploreDiaries({String? cursor, bool isRecent = true}) async {
    final headers = await _authHeaders();
    final params = <String, String>{
      'sort': isRecent ? 'RECENT' : 'POPULAR',
      if (cursor != null) 'cursor': cursor,
    };
    final uri = Uri.parse('$baseUrl/api/diaries/explore').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getDiaryDetail(int diaryId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/diaries/$diaryId/detail'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }
  // ────────────────────────────────────────────
  // 로그아웃
  // ────────────────────────────────────────────

  static Future<void> logout() async {
    final headers = await _authHeaders();
    await http.post(
      Uri.parse('$baseUrl/api/auth/logout'),
      headers: headers,
    );
    await clearTokens();
  }

  // ────────────────────────────────────────────
  // 회원 탈퇴
  // ────────────────────────────────────────────

  static Future<bool> deactivate() async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/me/deactivate'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      await clearTokens();
      return true;
    }
    return false;
  }
}
