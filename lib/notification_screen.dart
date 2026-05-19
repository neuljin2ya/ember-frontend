import 'package:flutter/material.dart';
import 'api_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await ApiService.getNotifications();
      final list = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
      setState(() {
        _notifications = list;
        _unreadCount = list.where((n) => n['isRead'] == false).length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllRead() async {
    for (final n in _notifications) {
      if (n['isRead'] == false) {
        await ApiService.markNotificationRead(
          n['notificationId'] ?? n['id'] ?? 0,
        );
      }
    }
    setState(() {
      for (final n in _notifications) {
        n['isRead'] = true;
      }
      _unreadCount = 0;
    });
  }

  String _timeAgo(String? createdAt) {
    if (createdAt == null) return '';
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  Map<String, int> _targetForNotification(Map<String, dynamic> notification) {
    final type = notification['type']?.toString().toUpperCase() ?? '';
    final message =
        '${notification['body'] ?? ''} ${notification['message'] ?? ''}';

    if (type.contains('CHAT') || message.contains('채팅')) {
      return {'index': 1, 'friendsTab': 1};
    }
    if (type.contains('MATCH') ||
        message.contains('선택') ||
        message.contains('신청') ||
        message.contains('관심')) {
      return {'index': 1, 'friendsTab': 2};
    }
    if (type.contains('EXCHANGE') || message.contains('교환일기')) {
      return {'index': 1, 'friendsTab': 0};
    }
    return {'index': 0, 'friendsTab': 0};
  }

  void _openNotificationTarget(Map<String, dynamic> notification) {
    final target = _targetForNotification(notification);
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (route) => false,
      arguments: target,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '알림',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFE37474)),
            )
          : Column(
              children: [
                // 새 알림 + 모두 읽기
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '새 알림',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_unreadCount개',
                            style: const TextStyle(
                              color: Color(0xFFFF7E64),
                              fontSize: 12,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: _markAllRead,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0x4CCACACA),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: const Text(
                            '모두 읽기',
                            style: TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 10,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 알림 목록
                Expanded(
                  child: _notifications.isEmpty
                      ? const Center(
                          child: Text(
                            '알림이 없어요',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _notifications.length,
                          separatorBuilder: (_, __) => const Divider(
                            height: 1,
                            color: Color(0xFFE5E5E5),
                          ),
                          itemBuilder: (context, index) {
                            final n = _notifications[index];
                            final isUnread = n['isRead'] == false;
                            return GestureDetector(
                              // onTap 부분 수정
                              onTap: () async {
                                if (isUnread) {
                                  await ApiService.markNotificationRead(
                                    n['notificationId'] ?? n['id'] ?? 0,
                                  );
                                  setState(() {
                                    n['isRead'] = true;
                                    _unreadCount = _unreadCount > 0
                                        ? _unreadCount - 1
                                        : 0;
                                  });
                                }
                                if (context.mounted) {
                                  _openNotificationTarget(n);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                color: isUnread
                                    ? const Color(0x19FB7154)
                                    : Colors.white,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 아이콘
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFEFE7),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.notifications_outlined,
                                        color: Color(0xFFE37474),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // 내용
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n['body'] ?? n['message'] ?? '',
                                            style: const TextStyle(
                                              color: Color(0xFF111827),
                                              fontSize: 12,
                                              fontFamily: 'Pretendard',
                                              fontWeight: FontWeight.w400,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Text(
                                                _timeAgo(n['createdAt']),
                                                style: const TextStyle(
                                                  color: Color(0xFF616161),
                                                  fontSize: 10,
                                                  fontFamily: 'Pretendard',
                                                ),
                                              ),
                                              if (isUnread) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFFFF7E64,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
