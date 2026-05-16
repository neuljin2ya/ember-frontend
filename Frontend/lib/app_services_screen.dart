import 'dart:convert';

import 'package:flutter/material.dart';

import 'api_service.dart';

class AppServicesScreen extends StatefulWidget {
  const AppServicesScreen({super.key});

  @override
  State<AppServicesScreen> createState() => _AppServicesScreenState();
}

class _AppServicesScreenState extends State<AppServicesScreen> {
  final _inquiryController = TextEditingController();
  bool _darkMode = false;
  bool _matchingPush = true;
  bool _chatPush = true;

  @override
  void dispose() {
    _inquiryController.dispose();
    super.dispose();
  }

  Future<void> _submitInquiry() async {
    final content = _inquiryController.text.trim();
    if (content.length < 10) {
      _showMessage('문의 내용은 10자 이상 입력해주세요');
      return;
    }
    final success = await ApiService.submitInquiry(content);
    if (!mounted) return;
    if (success) _inquiryController.clear();
    _showMessage(success ? '문의가 접수됐어요' : '문의 접수에 실패했어요');
  }

  Future<void> _saveSettings() async {
    final success = await ApiService.updateSettings({
      'darkMode': _darkMode,
      'language': 'ko',
    });
    if (!mounted) return;
    _showMessage(success ? '설정을 저장했어요' : '설정을 저장할 수 없어요');
  }

  Future<void> _saveNotificationSettings() async {
    final success = await ApiService.updateNotificationSettings({
      'matching': _matchingPush,
      'chat': _chatPush,
    });
    if (!mounted) return;
    _showMessage(success ? '알림 설정을 저장했어요' : '알림 설정을 저장할 수 없어요');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _pretty(dynamic value) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Color(0xFF391713)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '서비스',
          style: TextStyle(
            color: Color(0xFF391713),
            fontSize: 18,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          _AsyncSection(
            title: '오늘의 일기',
            loader: () async {
              final topic = await ApiService.getWeeklyTopic();
              final today = await ApiService.getTodayDiaryStatus();
              final drafts = await ApiService.getDrafts();
              return {
                'weeklyTopic': topic['data'],
                'today': today,
                'drafts': drafts,
              };
            },
            formatter: _pretty,
          ),
          _AsyncSection(
            title: '내 AI 분석',
            loader: () async {
              final ai = await ApiService.getMyAiProfile();
              final lifestyle = await ApiService.getLifestyleReport();
              return {'aiProfile': ai, 'lifestyleReport': lifestyle['data']};
            },
            formatter: _pretty,
          ),
          _AsyncSection(
            title: '공지 / FAQ',
            loader: () async {
              final notices = await ApiService.getNotices();
              final banners = await ApiService.getNoticeBanners();
              final unread = await ApiService.getNoticeUnreadCount();
              final faq = await ApiService.getFaq();
              return {
                'notices': notices['data'] ?? notices,
                'banners': banners['data'] ?? banners,
                'unreadCount': unread['data'] ?? unread,
                'faq': faq['data'] ?? faq,
              };
            },
            formatter: _pretty,
          ),
          _AsyncSection(
            title: '히스토리 / 차단',
            loader: () async {
              final exchange = await ApiService.getExchangeRoomHistory();
              final chat = await ApiService.getChatRoomHistory();
              final block = await ApiService.getBlockList();
              return {
                'exchangeRooms': exchange['data'] ?? exchange,
                'chatRooms': chat['data'] ?? chat,
                'blockList': block['data'] ?? block,
              };
            },
            formatter: _pretty,
          ),
          _AsyncSection(
            title: '문의 내역',
            loader: () async {
              final inquiries = await ApiService.getSupportInquiries();
              return inquiries['data'] ?? inquiries;
            },
            formatter: _pretty,
          ),
          _AsyncSection(
            title: '앱 상태',
            loader: () async {
              final version = await ApiService.getSystemVersion();
              final health = await ApiService.getHealth();
              return {
                'version': version['data'] ?? version,
                'health': health['data'] ?? health,
              };
            },
            formatter: _pretty,
          ),
          _SettingsSection(
            darkMode: _darkMode,
            matchingPush: _matchingPush,
            chatPush: _chatPush,
            onDarkModeChanged: (value) => setState(() => _darkMode = value),
            onMatchingChanged: (value) => setState(() => _matchingPush = value),
            onChatChanged: (value) => setState(() => _chatPush = value),
            onSaveSettings: _saveSettings,
            onSaveNotificationSettings: _saveNotificationSettings,
          ),
          _InquirySection(
            controller: _inquiryController,
            onSubmit: _submitInquiry,
          ),
        ],
      ),
    );
  }
}

class _AsyncSection extends StatelessWidget {
  final String title;
  final Future<dynamic> Function() loader;
  final String Function(dynamic value) formatter;

  const _AsyncSection({
    required this.title,
    required this.loader,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    return _ServiceCard(
      title: title,
      child: FutureBuilder<dynamic>(
        future: loader(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFE37474)),
              ),
            );
          }
          if (snapshot.hasError) {
            return Text(
              '불러오지 못했어요\n${snapshot.error}',
              style: const TextStyle(
                color: Color(0xFFE37474),
                fontSize: 12,
                fontFamily: 'Pretendard',
              ),
            );
          }
          return SelectableText(
            formatter(snapshot.data),
            style: const TextStyle(
              color: Color(0xFF391713),
              fontSize: 12,
              height: 1.45,
              fontFamily: 'Pretendard',
            ),
          );
        },
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final bool darkMode;
  final bool matchingPush;
  final bool chatPush;
  final ValueChanged<bool> onDarkModeChanged;
  final ValueChanged<bool> onMatchingChanged;
  final ValueChanged<bool> onChatChanged;
  final VoidCallback onSaveSettings;
  final VoidCallback onSaveNotificationSettings;

  const _SettingsSection({
    required this.darkMode,
    required this.matchingPush,
    required this.chatPush,
    required this.onDarkModeChanged,
    required this.onMatchingChanged,
    required this.onChatChanged,
    required this.onSaveSettings,
    required this.onSaveNotificationSettings,
  });

  @override
  Widget build(BuildContext context) {
    return _ServiceCard(
      title: '설정',
      child: Column(
        children: [
          _ToggleRow(
            label: '다크모드',
            value: darkMode,
            onChanged: onDarkModeChanged,
          ),
          _PrimaryAction(label: '앱 설정 저장', onTap: onSaveSettings),
          const SizedBox(height: 12),
          _ToggleRow(
            label: '매칭 알림',
            value: matchingPush,
            onChanged: onMatchingChanged,
          ),
          _ToggleRow(label: '채팅 알림', value: chatPush, onChanged: onChatChanged),
          _PrimaryAction(label: '알림 설정 저장', onTap: onSaveNotificationSettings),
        ],
      ),
    );
  }
}

class _InquirySection extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _InquirySection({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return _ServiceCard(
      title: '1:1 문의',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: '문의 내용을 입력해주세요',
              filled: true,
              fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _PrimaryAction(label: '문의 보내기', onTap: onSubmit),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ServiceCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF391713),
              fontSize: 16,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF391713),
            fontSize: 14,
            fontFamily: 'Pretendard',
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: const Color(0xFFE37474),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE37474),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
