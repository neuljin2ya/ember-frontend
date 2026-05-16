import 'package:flutter/material.dart';
import 'keyword_selector.dart';
import 'city_search_field.dart';
import 'api_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  bool _isProfileExpanded = false;
  bool _isIdealExpanded = false;
  bool _isCustomerExpanded = false;

  final _nameController = TextEditingController(text: '김이름');
  final _locationController = TextEditingController(text: '서울시 서초구');
  final _ageController = TextEditingController(text: '23');
  final _jobController = TextEditingController(text: '학생');
  List<int> _keywords = [];
  final _inquiryController = TextEditingController();

  void _showSavedSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Center(
          child: Text(
            '저장 되었습니다',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF391713),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await ApiService.getMyProfile();
      setState(() {
        _nameController.text = data['nickname'] ?? '';
        _locationController.text = [
          data['sido'],
          data['sigungu'],
        ].whereType<String>().join(' ');
        _jobController.text = data['school'] ?? '';
      });

      final idealData = await ApiService.getMyIdealType();
      setState(() {
        _keywords = List<int>.from(idealData['keywords'] ?? []);
      });
    } catch (e) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _ageController.dispose();
    _jobController.dispose();
    _inquiryController.dispose();
    super.dispose();
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
          '계정 정보',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Profile 섹션
          _SectionHeader(
            label: 'Profile',
            icon: Icons.person_outline,
            isExpanded: _isProfileExpanded,
            onTap: () =>
                setState(() => _isProfileExpanded = !_isProfileExpanded),
          ),
          if (_isProfileExpanded) ...[
            const Divider(color: Color(0xFFE37474), height: 1),
            const SizedBox(height: 16),
            _EditField(
              label: '이름',
              controller: _nameController,
              onConfirm: () async {
                await ApiService.updateProfile(nickname: _nameController.text);
                _showSavedSnackbar();
              },
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '사는 지역',
                  style: TextStyle(
                    color: Color(0xFF391713),
                    fontSize: 14,
                    fontFamily: 'Pretendard',
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: CitySearchField(controller: _locationController),
                    ),
                    const SizedBox(width: 8),
                    _ConfirmButton(
                      onTap: () async {
                        final parts = _locationController.text.trim().split(
                          ' ',
                        );
                        await ApiService.updateProfile(
                          sido: parts.isNotEmpty ? parts.first : '',
                          sigungu: parts.length > 1
                              ? parts.sublist(1).join(' ')
                              : '',
                        );
                        _showSavedSnackbar();
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _EditField(
              label: '나이',
              controller: _ageController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            _EditField(
              label: '직업',
              controller: _jobController,
              onConfirm: () async {
                await ApiService.updateProfile(school: _jobController.text);
                _showSavedSnackbar();
              },
            ),
            const SizedBox(height: 20),
          ],

          const Divider(color: Color(0xFFE5E5E5), height: 1),

          // IdealType 섹션
          _SectionHeader(
            label: 'IdealType',
            icon: Icons.favorite_border,
            isExpanded: _isIdealExpanded,
            onTap: () => setState(() => _isIdealExpanded = !_isIdealExpanded),
          ),
          if (_isIdealExpanded) ...[
            const Divider(color: Color(0xFFE37474), height: 1),
            const SizedBox(height: 16),
            KeywordSelector(
              onChanged: (keywords) {
                setState(() => _keywords = keywords);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  await ApiService.updateIdealType(_keywords);
                  _showSavedSnackbar();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE37474),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '저장',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          const Divider(color: Color(0xFFE5E5E5), height: 1),

          // Customer service 섹션
          _SectionHeader(
            label: 'Customer service',
            icon: Icons.headset_mic_outlined,
            isExpanded: _isCustomerExpanded,
            onTap: () =>
                setState(() => _isCustomerExpanded = !_isCustomerExpanded),
          ),
          if (_isCustomerExpanded) ...[
            const Divider(color: Color(0xFFE37474), height: 1),
            const SizedBox(height: 16),
            TextField(
              controller: _inquiryController,
              maxLines: 5,
              style: const TextStyle(fontSize: 14, fontFamily: 'Pretendard'),
              decoration: InputDecoration(
                hintText: '문의 내용을 입력해주세요.',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color(0xFFF8F8F8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  if (_inquiryController.text.trim().isEmpty) return;
                  await ApiService.submitInquiry(
                    _inquiryController.text.trim(),
                  );
                  _inquiryController.clear();
                  _showSavedSnackbar();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE37474),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '문의 보내기',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'Pretendard',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          const Divider(color: Color(0xFFE5E5E5), height: 1),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.label,
    required this.icon,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFE37474), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF391713),
                  fontSize: 20,
                  fontFamily: 'Pretendard',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: const Color(0xFF9CA3AF),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final VoidCallback? onConfirm;

  const _EditField({
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF391713),
            fontSize: 14,
            fontFamily: 'Pretendard',
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: keyboardType,
                style: const TextStyle(
                  color: Color(0xFF391713),
                  fontSize: 15,
                  fontFamily: 'Pretendard',
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE37474)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _ConfirmButton(onTap: onConfirm ?? () {}),
          ],
        ),
      ],
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ConfirmButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF9CA3AF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          '확인',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
