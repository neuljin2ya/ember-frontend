import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';
import 'package:stomp_dart_client/stomp_frame.dart';
import 'package:stomp_dart_client/stomp_handler.dart';
import 'api_service.dart';

class WebSocketService {
  static WebSocketService? _instance;
  StompClient? _client;
  bool _isConnected = false;

  static WebSocketService get instance {
    _instance ??= WebSocketService._();
    return _instance!;
  }
  WebSocketService._();

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    final token = await ApiService.getAccessToken();
    if (token == null || token.isEmpty) return;

    _client = StompClient(
      config: StompConfig(
        url: 'wss://ember-app.duckdns.org/ws/chat',
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: (frame) {
          _isConnected = true;
        },
        onDisconnect: (_) => _isConnected = false,
        onWebSocketError: (_) => _isConnected = false,
        onStompError: (_) => _isConnected = false,
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _client!.activate();
  }

  StompUnsubscribe? subscribe(
    int roomId,
    void Function(Map<String, dynamic>) onMessage,
  ) {
    if (_client == null || !_isConnected) return null;
    return _client!.subscribe(
      destination: '/topic/chat/$roomId',
      callback: (frame) {
        if (frame.body != null) onMessage(jsonDecode(frame.body!));
      },
    );
  }

  void send(int roomId, String content) {
    if (_client == null || !_isConnected) return;
    _client!.send(
      destination: '/app/chat/$roomId',
      body: jsonEncode({'content': content, 'type': 'TEXT'}),
    );
  }

  StompUnsubscribe? subscribeErrors(
    int roomId,
    int userId,
    void Function(Map<String, dynamic>) onError,
  ) {
    if (_client == null || !_isConnected) return null;
    return _client!.subscribe(
      destination: '/topic/chat/$roomId/errors/$userId',
      callback: (frame) {
        if (frame.body != null) onError(jsonDecode(frame.body!));
      },
    );
  }

  void sendRead(int roomId) {
    if (_client == null || !_isConnected) return;
    _client!.send(destination: '/app/chat/$roomId/read', body: '');
  }

  StompUnsubscribe? subscribeExchange(
    int roomId,
    void Function(Map<String, dynamic>) onEvent,
  ) {
    if (_client == null || !_isConnected) return null;
    return _client!.subscribe(
      destination: '/topic/exchange/$roomId',
      callback: (frame) {
        if (frame.body != null) onEvent(jsonDecode(frame.body!));
      },
    );
  }

  void disconnect() {
    _client?.deactivate();
    _isConnected = false;
  }
}
