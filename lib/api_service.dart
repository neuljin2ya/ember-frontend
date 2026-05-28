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
    final body = response.body.trimLeft();
    if (body.startsWith('<!DOCTYPE html') ||
        body.startsWith('<html') ||
        body.startsWith('<HTML')) {
      final preview = body
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'<[^>]*>'), ' ')
          .trim();
      return {
        'code': response.statusCode.toString(),
        'message':
            '서버가 JSON이 아닌 HTML 응답을 보냈어요. 서버 상태나 API 주소를 확인해주세요. (${response.statusCode})',
        'data': null,
        'rawPreview': preview.length > 180
            ? '${preview.substring(0, 180)}...'
            : preview,
      };
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return {
        'code': response.statusCode.toString(),
        'message': '서버 응답이 객체 형식이 아니에요.',
        'data': decoded,
      };
    } on FormatException {
      final preview = response.body.length > 180
          ? '${response.body.substring(0, 180)}...'
          : response.body;
      return {
        'code': response.statusCode.toString(),
        'message': '서버 응답을 해석할 수 없어요. (${response.statusCode})',
        'data': null,
        'rawPreview': preview,
      };
    }
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
    var token = await getAccessToken();
    if (token == null || token.isEmpty) {
      final refreshed = await refreshAccessToken();
      if (refreshed) token = await getAccessToken();
    }
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

  static bool _isAccessTokenExpired(
    http.Response response,
    Map<String, dynamic> decoded,
  ) {
    return response.statusCode == 401 &&
        (decoded['code']?.toString() == 'A002' || decoded['code']?.toString() == '401');
  }

  static Future<http.Response> _sendWithAuthRetry(
    Future<http.Response> Function(Map<String, String> headers) request, {
    bool requireAuth = false,
  }) async {
    Future<Map<String, String>> headers() =>
        requireAuth ? _requiredAuthHeaders() : _authHeaders();

    var response = await request(await headers()).timeout(requestTimeout);
    var decoded = _decodeMap(response);

    if (_isAccessTokenExpired(response, decoded)) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        response = await request(
          await _requiredAuthHeaders(),
        ).timeout(requestTimeout);
        decoded = _decodeMap(response);
      } else {
        await clearTokens();
      }
    }

    final code = decoded['code']?.toString();
    if (response.statusCode == 401 &&
        (code == 'A003' || code == 'A006' || code == 'A007')) {
      await clearTokens();
    }

    return response;
  }

  static Future<http.Response> _getWithAuth(
    Uri uri, {
    bool requireAuth = false,
  }) {
    return _sendWithAuthRetry(
      (headers) => http.get(uri, headers: headers),
      requireAuth: requireAuth,
    );
  }

  static Future<http.Response> _postWithAuth(
    Uri uri, {
    Object? body,
    bool requireAuth = false,
  }) {
    return _sendWithAuthRetry(
      (headers) => http.post(uri, headers: headers, body: body),
      requireAuth: requireAuth,
    );
  }

  static Future<http.Response> _patchWithAuth(
    Uri uri, {
    Object? body,
    bool requireAuth = false,
  }) {
    return _sendWithAuthRetry(
      (headers) => http.patch(uri, headers: headers, body: body),
      requireAuth: requireAuth,
    );
  }

  static Future<http.Response> _putWithAuth(
    Uri uri, {
    Object? body,
    bool requireAuth = false,
  }) {
    return _sendWithAuthRetry(
      (headers) => http.put(uri, headers: headers, body: body),
      requireAuth: requireAuth,
    );
  }

  static Future<http.Response> _deleteWithAuth(
    Uri uri, {
    bool requireAuth = false,
  }) {
    return _sendWithAuthRetry(
      (headers) => http.delete(uri, headers: headers),
      requireAuth: requireAuth,
    );
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
      final preview = data['rawPreview']?.toString();
      throw Exception(
        [
          data['message'] ?? '소셜 로그인에 실패했어요.',
          if (preview != null && preview.isNotEmpty) '응답 일부: $preview',
        ].join('\n'),
      );
    }

    final tokenData = _payload(data);
    if (data['data'] == null && data['rawPreview'] != null) {
      throw Exception(
        '${data['message']}\n응답 일부: ${data['rawPreview']}\n잠시 후 다시 시도하거나 서버 로그를 확인해주세요.',
      );
    }
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
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/consent'),
      body: jsonEncode({'consentType': consentType}),
      requireAuth: true,
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
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/users/profile'),
      body: jsonEncode({
        'nickname': nickname,
        'realName': realName,
        'gender': gender,
        'birthDate': birthDate,
        'sido': sido,
        'sigungu': sigungu,
      }),
      requireAuth: true,
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
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/users/ideal-type/keyword-list'),
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
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/users/nickname/generate'),
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
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/users/ideal-type/keywords'),
      body: jsonEncode({'keywordIds': keywords}),
      requireAuth: true,
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

    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/diaries'),
      body: jsonEncode(body),
      requireAuth: true,
    );
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : _decodeMap(response);

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

  static Future<Map<String, dynamic>> updateDiary({
    required int diaryId,
    required String content,
  }) async {
    final response = await _patchWithAuth(
      Uri.parse('$baseUrl/api/diaries/$diaryId'),
      body: jsonEncode({'content': content}),
      requireAuth: true,
    );
    final data = _decodeMap(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data['message'] ?? '일기를 수정할 수 없어요.');
    }
    return data;
  }

  static Future<bool> selectMatching(int diaryId) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/matching/$diaryId/select'),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _getWithAuth(Uri.parse('$baseUrl/api/users/me'));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('인증 만료');
    }
    final data = _payload(_decodeMap(response));
    final localImagePath = await getLocalProfileImagePath();
    if (localImagePath != null && localImagePath.isNotEmpty) {
      data['localProfileImagePath'] = localImagePath;
    }
    return data;
  }

  static Future<Map<String, dynamic>> getMyIdealType() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/users/me/ideal-type'),
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
    final normalizedSido = _normalizeSido(sido);
    final normalizedSigungu = _normalizeSigungu(sigungu, normalizedSido);
    final body = <String, dynamic>{};
    if (nickname != null) body['nickname'] = nickname;
    if (realName != null) body['realName'] = realName;
    if (normalizedSido != null) body['sido'] = normalizedSido;
    if (sigungu != null) body['sigungu'] = normalizedSigungu ?? '';
    if (school != null) body['school'] = school;

    final response = await _patchWithAuth(
      Uri.parse('$baseUrl/api/users/me/profile'),
      body: jsonEncode(body),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getRecommendations() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/matching/recommendations'),
    );
    print('추천 status: ${response.statusCode}');
    print('추천 body: ${response.body}');
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getRecommendationPreview(
    int diaryId,
  ) async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/matching/recommendations/$diaryId/preview'),
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getMyDiaries() async {
    final response = await _getWithAuth(Uri.parse('$baseUrl/api/diaries'));
    print('내 일기 status: ${response.statusCode}');
    print('내 일기 body: ${response.body}');
    return _decodeMap(response);
  }

  static Future<bool> updateIdealType(List<int> keywords) async {
    final response = await _putWithAuth(
      Uri.parse('$baseUrl/api/users/me/ideal-type'),
      body: jsonEncode({'keywordIds': keywords}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getExchangeRooms() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/exchange-rooms'),
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getChatMessages(int roomId) async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/messages'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> sendChatMessage(
    int roomId,
    String content,
  ) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/messages'),
      body: jsonEncode({'content': content, 'type': 'TEXT'}),
    );
    return _decodeMap(response);
  }

  static Future<bool> leaveChatRoom(int roomId) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/leave'),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getNotifications() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/notifications'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<bool> postExchangeDiary({
    required int roomId,
    required String content,
    String? date,
  }) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/diaries'),
      body: jsonEncode({'content': content}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> endExchangeRoom(int roomId) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/next-step'),
      body: jsonEncode({'choice': 'CONTINUE'}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getExchangeDiaryDetail({
    required int roomId,
    required int diaryId,
  }) async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/diaries/$diaryId'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<bool> submitInquiry(
    String content, {
    String category = 'ACCOUNT',
    String title = '앱 내 문의사항',
  }) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/support/inquiry'),
      body: jsonEncode({
        'category': category,
        'title': title,
        'content': content,
      }),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // 4턴 완료 후 관계 확장
  static Future<Map<String, dynamic>> postNextStep(int roomId, String choice) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/next-step'),
      body: jsonEncode({'choice': choice}), // 'CHAT' or 'CONTINUE'
    );
    return _payload(_decodeMap(response));
  }

  // FCM 토큰 등록
  static Future<bool> registerFcmToken(String token) async {
    final deviceType = Platform.isAndroid ? 'AOS' : 'IOS';
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/users/me/fcm-token'),
      body: jsonEncode({'fcmToken': token, 'deviceType': deviceType}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // 신고
  static Future<bool> reportUser(int targetUserId, String reason) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/users/$targetUserId/report'),
      body: jsonEncode({'reason': reason}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // 차단
  static Future<bool> blockUser(int targetUserId) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/users/$targetUserId/block'),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> postExchangeDiaryReaction({
    required int roomId,
    required int diaryId,
    required String reaction,
  }) async {
    final response = await _postWithAuth(
      Uri.parse(
        '$baseUrl/api/exchange-rooms/$roomId/diaries/$diaryId/reaction',
      ),
      body: jsonEncode({'reaction': reaction}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getChatRooms() async {
    final response = await _getWithAuth(Uri.parse('$baseUrl/api/chat-rooms'));
    return _decodeMap(response);
  }

  static Future<bool> acceptMatching(int matchingId) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/matching/requests/$matchingId/accept'),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> acceptMatchingResponse(
    int matchingId,
  ) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/matching/requests/$matchingId/accept'),
    );
    return _decodeMap(response);
  }

  static Future<bool> markNotificationRead(int id) async {
    final response = await _patchWithAuth(
      Uri.parse('$baseUrl/api/notifications/$id/read'),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> markAllNotificationsRead() async {
    final response = await _patchWithAuth(
      Uri.parse('$baseUrl/api/notifications/read-all'),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> skipMatching(int diaryId) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/matching/$diaryId/skip'),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getWeeklyTopic() async {
    final response = await http
        .get(
          Uri.parse('$baseUrl/api/diaries/weekly-topic'),
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(requestTimeout);
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getTodayDiary() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/diaries/today'),
      requireAuth: true,
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getDrafts() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/diaries/drafts'),
      requireAuth: true,
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> createDraft({
    required String content,
    int? topicId,
  }) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/diaries/draft'),
      body: jsonEncode({
        'content': content,
        if (topicId != null) 'topicId': topicId,
      }),
      requireAuth: true,
    );
    return _decodeMap(response);
  }

  static Future<bool> deleteDraft(int draftId) async {
    final response = await _deleteWithAuth(
      Uri.parse('$baseUrl/api/diaries/draft/$draftId'),
      requireAuth: true,
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
    final response = await http.get(uri).timeout(requestTimeout);
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
    final response = await _getWithAuth(uri);
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getDiaryDetail(int diaryId) async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/diaries/$diaryId/detail'),
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getDiary(int diaryId) async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/diaries/$diaryId'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getMyAiProfile() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/users/me/ai-profile'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getLifestyleReport() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/matching/lifestyle-report'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getTutorialPages() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/tutorials/pages'),
    );
    return _decodeMap(response);
  }

  static Future<bool> completeTutorial() async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/users/tutorial/complete'),
    );
    final decoded = _decodeMap(response);
    final data = decoded['data'];
    if (data is Map && data['success'] == false) return false;
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getExchangeRoomDetail(int roomId) async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getNextStepStatus(int roomId) async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/next-step/status'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getExchangeRoomReport(int roomId) async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/exchange-rooms/$roomId/report'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getChatProfile(int roomId) async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/profile'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<bool> postCoupleRequest(int roomId) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/couple-request'),
    );
    if (response.statusCode >= 400) {
      final data = _decodeMap(response);
      throw Exception(data['message'] ?? '커플 요청 실패');
    }
    return true;
  }

  static Future<Map<String, dynamic>> getCoupleStatus(int roomId) async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/couple-status'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<bool> acceptCouple(int roomId) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/couple-accept'),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> rejectCouple(int roomId) async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/chat-rooms/$roomId/couple-reject'),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<Map<String, dynamic>> getNotices() async {
    final response = await _getWithAuth(Uri.parse('$baseUrl/api/notices'));
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getNoticeDetail(int id) async {
    final response = await _getWithAuth(Uri.parse('$baseUrl/api/notices/$id'));
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getFaq() async {
    final response = await _getWithAuth(Uri.parse('$baseUrl/api/faq'));
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getSupportInquiries() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/support/inquiries'),
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getSupportInquiryDetail(int id) async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/support/inquiries/$id'),
    );
    return _payload(_decodeMap(response));
  }

  static Future<Map<String, dynamic>> getBlockList({
    String? cursor,
    int size = 20,
  }) async {
    final uri = Uri.parse('$baseUrl/api/users/me/block-list').replace(
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'size': size.toString(),
      },
    );
    final response = await _getWithAuth(uri);
    return _decodeMap(response);
  }

  static Future<bool> unblockUser(int targetUserId) async {
    final response = await _deleteWithAuth(
      Uri.parse('$baseUrl/api/users/$targetUserId/block'),
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  static Future<Map<String, dynamic>> getExchangeRoomHistory() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/users/me/history/exchange-rooms'),
    );
    return _decodeMap(response);
  }

  static Future<Map<String, dynamic>> getChatRoomHistory() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/users/me/history/chat-rooms'),
    );
    return _decodeMap(response);
  }

  static Future<bool> updateSettings(Map<String, dynamic> settings) async {
    final response = await _patchWithAuth(
      Uri.parse('$baseUrl/api/users/me/settings'),
      body: jsonEncode(settings),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  static Future<bool> updateNotificationSettings(
    Map<String, dynamic> settings,
  ) async {
    final response = await _patchWithAuth(
      Uri.parse('$baseUrl/api/users/me/notification-settings'),
      body: jsonEncode(settings),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }
  // ────────────────────────────────────────────
  // 로그아웃
  // ────────────────────────────────────────────

  static Future<void> logout() async {
    await _postWithAuth(Uri.parse('$baseUrl/api/auth/logout'));
    await clearTokens();
  }

  // ────────────────────────────────────────────
  // 회원 탈퇴
  // ────────────────────────────────────────────
  static Future<Map<String, dynamic>> getReceivedRequests() async {
    final response = await _getWithAuth(
      Uri.parse('$baseUrl/api/matching/requests'),
    );
    return _decodeMap(response);
  }

  static Future<bool> deactivate() async {
    final response = await _postWithAuth(
      Uri.parse('$baseUrl/api/users/me/deactivate'),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      await clearTokens();
      return true;
    }
    return false;
  }
}
