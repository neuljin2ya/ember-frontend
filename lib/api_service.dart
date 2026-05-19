import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://ember-app.duckdns.org';
  static const Duration requestTimeout = Duration(seconds: 20);

  static String? _normalizeSido(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    const aliases = {
      '서울시': '서울특별시',
      '부산시': '부산광역시',
      '대구시': '대구광역시',
      '인천시': '인천광역시',
      '광주시': '광주광역시',
      '대전시': '대전광역시',
      '울산시': '울산광역시',
      '세종시': '세종특별자치시',
      '제주도': '제주특별자치도',
    };
    return aliases[trimmed] ?? trimmed;
  }

  static const Set<String> _sidoNames = {
    '서울특별시',
    '부산광역시',
    '대구광역시',
    '인천광역시',
    '광주광역시',
    '대전광역시',
    '울산광역시',
    '세종특별자치시',
    '경기도',
    '강원도',
    '충청북도',
    '충청남도',
    '전라북도',
    '전라남도',
    '경상북도',
    '경상남도',
    '제주특별자치도',
  };

  static String? _normalizeSigungu(String? value, String? sido) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (sido != null && trimmed == sido) return null;
    if (_sidoNames.contains(trimmed)) return null;
    return trimmed;
  }

  static Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.body.isEmpty) {
      return {
        'code': response.statusCode.toString(),
        'message': 'EMPTY_RESPONSE',
        'data': null,
      };
    }
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  static Map<String, dynamic> _payload(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return response;
  }

  static String _findStringDeep(dynamic value, List<String> keys) {
    if (value is Map) {
      for (final key in keys) {
        final direct = value[key];
        if (direct != null && direct.toString().trim().isNotEmpty) {
          return direct.toString();
        }
      }
      for (final child in value.values) {
        final found = _findStringDeep(child, keys);
        if (found.isNotEmpty) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findStringDeep(child, keys);
        if (found.isNotEmpty) return found;
      }
    }
    return '';
  }

  // ────────────────────────────────────────────
  // 토큰 관리
  // ────────────────────────────────────────────

  static Future<void> saveToken(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', accessToken);
    await prefs.setString('refreshToken', refreshToken);
  }

  static Future<void> saveUserId(dynamic userId) async {
    final parsed = userId is int
        ? userId
        : int.tryParse(userId?.toString() ?? '');
    if (parsed == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', parsed);
  }

  static Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
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
    await prefs.remove('userId');
    await prefs.remove('localProfileImagePath');
  }

  static Future<void> saveLocalProfileImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('localProfileImagePath', path);
  }

  static Future<String?> getLocalProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('localProfileImagePath');
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

  static Future<Map<String, String>> _requiredAuthHeaders() async {
    var token = await getAccessToken();
    if (token == null || token.isEmpty) {
      final refreshed = await refreshAccessToken();
      if (refreshed) token = await getAccessToken();
    }
    if (token == null || token.isEmpty) {
      throw Exception('로그인 정보가 없어요. 다시 로그인해주세요.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
  // ────────────────────────────────────────────
  // 토큰 갱신
  // ────────────────────────────────────────────

  static Future<bool> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    final response = await http
        .post(
          Uri.parse('$baseUrl/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(requestTimeout);

    if (response.statusCode == 200) {
      final data = _payload(_decodeMap(response));
      await saveToken(data['accessToken'] ?? '', data['refreshToken'] ?? '');
      await saveUserId(data['userId']);
      return true;
    }
    return false;
  }

  // ────────────────────────────────────────────
  // Dev 로그인 (테스트용)
  // ────────────────────────────────────────────

  static Future<Map<String, dynamic>> devRegister() async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/dev/register'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(requestTimeout);

    final data = _decodeMap(response);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final tokenData = _payload(data);
      final accessToken = tokenData['accessToken'] ?? '';
      final refreshToken = tokenData['refreshToken'] ?? '';
      await saveToken(accessToken, refreshToken);
      await saveUserId(tokenData['userId']);
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
      'accessToken': kakaoAccessToken,
      if (email.isNotEmpty) 'email': email,
    };

    print('보내는 body: $requestBody');

    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/social'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(requestTimeout);
    } on SocketException catch (e) {
      throw Exception('서버에 연결할 수 없어요. 네트워크 또는 서버 상태를 확인해주세요. (${e.message})');
    } on HttpException catch (e) {
      throw Exception('서버 응답을 받을 수 없어요. (${e.message})');
    } on FormatException catch (e) {
      throw Exception('서버 응답 형식이 올바르지 않아요. (${e.message})');
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('서버 응답이 지연되고 있어요. 잠시 후 다시 시도해주세요.');
      }
      rethrow;
    }

    print('statusCode: ${response.statusCode}');
    print('responseBody: ${response.body}');

    final data = _decodeMap(response);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? '소셜 로그인에 실패했어요.');
    }

    final tokenData = _payload(data);
    final accessToken = _findStringDeep(tokenData, [
      'accessToken',
      'access_token',
      'access',
    ]);
    final refreshToken = _findStringDeep(tokenData, [
      'refreshToken',
      'refresh_token',
      'refresh',
    ]);
    if (accessToken.isEmpty || refreshToken.isEmpty) {
      return data;
    }
    await saveToken(accessToken, refreshToken);
    await saveUserId(tokenData['userId']);

    return data;
  }

  static Future<Map<String, dynamic>> restoreAccount(
    String restoreToken,
  ) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/auth/restore'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'restoreToken': restoreToken}),
        )
        .timeout(requestTimeout);

    final data = _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? '계정을 복구할 수 없어요.');
    }

    final tokenData = _payload(data);
    final accessToken = _findStringDeep(tokenData, [
      'accessToken',
      'access_token',
      'access',
    ]);
    final refreshToken = _findStringDeep(tokenData, [
      'refreshToken',
      'refresh_token',
      'refresh',
    ]);

    if (accessToken.isEmpty || refreshToken.isEmpty) {
      throw Exception('복구 후 로그인 토큰을 받을 수 없어요. 다시 로그인해주세요.');
    }

    await saveToken(accessToken, refreshToken);
    await saveUserId(
      tokenData['userId'] ?? _findStringDeep(tokenData, ['userId', 'id']),
    );
    return data;
  }

  // ────────────────────────────────────────────
  // 약관 동의
  // ────────────────────────────────────────────

  static Future<bool> postConsent(String consentType) async {
    final headers = await _requiredAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/consent'),
      headers: headers,
      body: jsonEncode({'consentType': consentType}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) return true;
    final data = _decodeMap(response);
    throw Exception(data['message'] ?? '약관 동의 저장에 실패했어요.');
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
    final headers = await _requiredAuthHeaders();

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

    return _decodeMap(response);
  }
  // ────────────────────────────────────────────
  // 이상형 키워드 목록 조회
  // ────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getIdealTypeKeywordOptions() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/ideal-type/keyword-list'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = _payload(_decodeMap(response));
      final keywords = data['keywords'] ?? data['keywordList'] ?? [];
      return (keywords as List)
          .map((keyword) {
            if (keyword is Map) {
              final id = keyword['id'] is int
                  ? keyword['id'] as int
                  : int.tryParse(keyword['id']?.toString() ?? '');
              final label =
                  keyword['label'] ?? keyword['text'] ?? keyword['name'];
              if (id != null && label != null && label.toString().isNotEmpty) {
                return {'id': id, 'label': label.toString()};
              }
            }
            return null;
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    return [];
  }

  static Future<List<String>> getIdealTypeKeywords() async {
    final keywords = await getIdealTypeKeywordOptions();
    return keywords.map((keyword) => keyword['label'].toString()).toList();
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

    return _decodeMap(response);
  }
  // ────────────────────────────────────────────
  // 이상형 키워드 설정
  // ────────────────────────────────────────────

  static Future<bool> postIdealTypeKeywords(List<int> keywords) async {
    final headers = await _requiredAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/ideal-type/keywords'),
      headers: headers,
      body: jsonEncode({'keywordIds': keywords}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) return true;
    throw Exception(
      response.body.isEmpty
          ? '이상형 키워드 저장 실패 (${response.statusCode})'
          : _decodeMap(response)['message'] ?? '이상형 키워드 저장 실패',
    );
  }

  // ────────────────────────────────────────────
  // 일기 작성
  // ────────────────────────────────────────────

  static Future<Map<String, dynamic>> postDiary({
    required String content,
    String visibility = 'PRIVATE',
    int? topicId,
  }) async {
    final body = {
      'content': content,
      'visibility': visibility,
      if (topicId != null) 'topicId': topicId,
    };

    Future<http.Response> send() async {
      final headers = await _requiredAuthHeaders();
      return http.post(
        Uri.parse('$baseUrl/api/diaries'),
        headers: headers,
        body: jsonEncode(body),
      );
    }

    var response = await send();
    var decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : _decodeMap(response);

    if (response.statusCode == 401 && decoded['code'] == 'A002') {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await send();
        decoded = response.body.isEmpty
            ? <String, dynamic>{}
            : _decodeMap(response);
      }
    }

    print('일기 status: ${response.statusCode}');
    print('일기 body: ${response.body}');

    if (response.body.isEmpty) {
      throw Exception('일기 저장 실패 (${response.statusCode})');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final code = decoded['code']?.toString();
      if (code == 'A003' || code == 'A006' || code == 'A007') {
        await clearTokens();
        throw Exception('계정 정보를 찾을 수 없어요. 다시 로그인해주세요.');
      }
      throw Exception(
        decoded['message'] ?? '일기 저장 실패 (${response.statusCode})',
      );
    }
    return decoded;
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
    final data = _payload(_decodeMap(response));
    final localImagePath = await getLocalProfileImagePath();
    if (localImagePath != null && localImagePath.isNotEmpty) {
      data['localProfileImagePath'] = localImagePath;
    }
    return data;
  }

  static Future<Map<String, dynamic>> getMyIdealType() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/me/ideal-type'),
      headers: headers,
    );
    return _payload(_decodeMap(response));
  }

  static Future<bool> updateProfile({
    String? nickname,
    String? realName,
    String? sido,
    String? sigungu,
    String? school,
  }) async {
    final headers = await _authHeaders();
    final normalizedSido = _normalizeSido(sido);
    final normalizedSigungu = _normalizeSigungu(sigungu, normalizedSido);
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (realName != null) body['realName'] = realName;
    if (normalizedSido != null) body['sido'] = normalizedSido;
    if (sigungu != null) body['sigungu'] = normalizedSigungu ?? '';
    if (school != null) body['school'] = school;

    final response = await http.patch(
      Uri.parse('$baseUrl/api/users/me/profile'),
      headers: headers,
      body: jsonEncode(body),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getRecommendations() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/matching/recommendations'),
      headers: headers,
    );
    print('추천 status: ${response.statusCode}');
    print('추천 body: ${response.body}');
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getRecommendationPreview(
    int diaryId,
  ) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/matching/recommendations/$diaryId/preview'),
      headers: headers,
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getMyDiaries() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/diaries'),
      headers: headers,
    );
    print('내 일기 status: ${response.statusCode}');
    print('내 일기 body: ${response.body}');
    return _decodeMap(response);
  }

  static Future<bool> updateIdealType(List<int> keywords) async {
    final headers = await _authHeaders();
    final response = await http.put(
      Uri.parse('$baseUrl/api/users/me/ideal-type'),
      headers: headers,
      body: jsonEncode({'keywordIds': keywords}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getExchangeRooms() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/exchange-rooms'),
      headers: headers,
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getChatMessages(int roomId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/messages'),
      headers: headers,
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> sendChatMessage(
    int roomId,
    String content,
  ) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/messages'),
      headers: headers,
      body: jsonEncode({'content': content, 'type': 'TEXT'}),
    );
    return _decodeMap(response);
  }

  static Future<bool> leaveChatRoom(int roomId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/leave'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getNotifications() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/notifications'),
      headers: headers,
    );
    return _payload(_decodeMap(response));
  }

  static Future<bool> postExchangeDiary({
    required int roomId,
    required String content,
    String? date,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/diaries'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> endExchangeRoom(int roomId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/next-step'),
      headers: headers,
      body: jsonEncode({'choice': 'CONTINUE'}),
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
    return _payload(_decodeMap(response));
  }

  static Future<bool> submitInquiry(
    String content, {
    String category = 'ACCOUNT',
    String title = '앱 문의',
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/support/inquiry'),
      headers: headers,
      body: jsonEncode({
        'category': category,
        'title': title,
        'content': content,
      }),
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
    final deviceType = Platform.isAndroid ? 'AOS' : 'IOS';
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/me/fcm-token'),
      headers: headers,
      body: jsonEncode({'fcmToken': token, 'deviceType': deviceType}),
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
      Uri.parse(
        '$baseUrl/api/exchange-rooms/$roomId/diaries/$diaryId/reaction',
      ),
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
    return _decodeMap(response);
  }

  static Future<bool> acceptMatching(int matchingId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/matching/requests/$matchingId/accept'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> acceptMatchingResponse(
    int matchingId,
  ) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/matching/requests/$matchingId/accept'),
      headers: headers,
    );
    return _decodeMap(response);
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

  static Future<Map<String, dynamic>> getWeeklyTopic() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/diaries/weekly-topic'),
      headers: {'Content-Type': 'application/json'},
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getTodayDiary() async {
    final headers = await _requiredAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/diaries/today'),
      headers: headers,
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getDrafts() async {
    final headers = await _requiredAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/diaries/drafts'),
      headers: headers,
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> createDraft({
    required String content,
    int? topicId,
  }) async {
    final headers = await _requiredAuthHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/diaries/draft'),
      headers: headers,
      body: jsonEncode({
        'content': content,
        if (topicId != null) 'topicId': topicId,
      }),
    );
    return _decodeMap(response);
  }

  static Future<bool> deleteDraft(int draftId) async {
    final headers = await _requiredAuthHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/api/diaries/draft/$draftId'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<Map<String, dynamic>> checkAppVersion({
    required String currentVersion,
  }) async {
    final platform = Platform.isIOS ? 'IOS' : 'AOS';
    final uri = Uri.parse('$baseUrl/api/system/version').replace(
      queryParameters: {'platform': platform, 'currentVersion': currentVersion},
    );
    final response = await http.get(uri);
    return _decodeMap(response);
  }

  // ────────────────────────────────────────────
  // 일기 탐색
  // ────────────────────────────────────────────

  static Future<Map<String, dynamic>> exploreDiaries({
    String? cursor,
    bool isRecent = true,
    String? sido,
    String? sigungu,
    String? ageGroup,
    bool keywordFilter = false,
  }) async {
    final headers = await _authHeaders();
    final normalizedSido = _normalizeSido(sido);
    final normalizedSigungu = _normalizeSigungu(sigungu, normalizedSido);
    final params = <String, String>{
      'sort': isRecent ? 'latest' : 'recommended',
      if (cursor != null) 'cursor': cursor,
      if (normalizedSido != null) 'sido': normalizedSido,
      if (normalizedSigungu != null) 'sigungu': normalizedSigungu,
      if (ageGroup != null) 'ageGroup': ageGroup,
      'keywordFilter': keywordFilter.toString(),
    };
    final uri = Uri.parse(
      '$baseUrl/api/diaries/explore',
    ).replace(queryParameters: params);
    final response = await http.get(uri, headers: headers);
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getDiaryDetail(int diaryId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/diaries/$diaryId/detail'),
      headers: headers,
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getDiary(int diaryId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/diaries/$diaryId'),
      headers: headers,
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getMyAiProfile() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/me/ai-profile'),
      headers: headers,
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getLifestyleReport() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/matching/lifestyle-report'),
      headers: headers,
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getTutorialPages() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/tutorials/pages'),
      headers: headers,
    );
    return _decodeMap(response);
  }

  static Future<bool> completeTutorial() async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/tutorial/complete'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getExchangeRoomDetail(int roomId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId'),
      headers: headers,
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getChatProfile(int roomId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/profile'),
      headers: headers,
    );
    return _payload(_decodeMap(response));
  }

  static Future<bool> postCoupleRequest(int roomId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/couple-request'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> acceptCouple(int roomId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/couple-accept'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> rejectCouple(int roomId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/couple-reject'),
      headers: headers,
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getNotices() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/notices'),
      headers: headers,
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getFaq() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/faq'),
      headers: headers,
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getExchangeRoomHistory() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/me/history/exchange-rooms'),
      headers: headers,
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getChatRoomHistory() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/me/history/chat-rooms'),
      headers: headers,
    );
    return _decodeMap(response);
  }

  static Future<bool> updateSettings(Map<String, dynamic> settings) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/api/users/me/settings'),
      headers: headers,
      body: jsonEncode(settings),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> updateNotificationSettings(
    Map<String, dynamic> settings,
  ) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/api/users/me/notification-settings'),
      headers: headers,
      body: jsonEncode(settings),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }
  // ────────────────────────────────────────────
  // 로그아웃
  // ────────────────────────────────────────────

  static Future<void> logout() async {
    final headers = await _authHeaders();
    await http.post(Uri.parse('$baseUrl/api/auth/logout'), headers: headers);
    await clearTokens();
  }

  // ────────────────────────────────────────────
  // 회원 탈퇴
  // ────────────────────────────────────────────
  static Future<Map<String, dynamic>> getReceivedRequests() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/api/matching/requests'),
      headers: headers,
    );
    return _decodeMap(response);
  }

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
