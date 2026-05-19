import 'package:flutter/material.dart';
import 'profile_image_picker.dart';
import 'city_search_field.dart';
import 'keyword_selector.dart';
import 'top_nav_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'diary_screen.dart';
import 'api_service.dart';

class CreateProfile extends StatefulWidget {
  final String realName;
  const CreateProfile({super.key, required this.realName});

  @override
  State<CreateProfile> createState() => _CreateProfileState();
}

class _CreateProfileState extends State<CreateProfile> {
  final _pageController = PageController();
  final _locationController = TextEditingController();
  final _occupationController = TextEditingController();
  final _realNameController = TextEditingController();
  List<int> _keywords = [];
  int _currentPage = 0;
  String _selectedGender = 'MALE';
  DateTime? _selectedBirthDate;

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _prevPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    if (picked != null) {
      setState(() => _selectedBirthDate = picked);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _locationController.dispose();
    _occupationController.dispose();
    _realNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardHeight = MediaQuery.of(context).size.height * 0.65;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _currentPage == 2
          ? Colors.white
          : const Color(0xFFE9E9E9),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  // ── 1페이지 ──
                  Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 32),
                              const Text(
                                'Your Name',
                                style: TextStyle(
                                  color: Color(0xFF391713),
                                  fontSize: 20,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _realNameController,
                                style: const TextStyle(fontSize: 15, fontFamily: 'Pretendard'),
                                decoration: InputDecoration(
                                  hintText: '실명을 입력해주세요',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF8F8888),
                                    fontSize: 15,
                                    fontFamily: 'Pretendard',
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F8F8),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Where do you live?',
                                style: TextStyle(
                                  color: Color(0xFF391713),
                                  fontSize: 20,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              CitySearchField(controller: _locationController),
                              const SizedBox(height: 20),
                              const Text(
                                'What do you do?',
                                style: TextStyle(
                                  color: Color(0xFF391713),
                                  fontSize: 20,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _occupationController,
                                style: const TextStyle(
                                    fontSize: 15, fontFamily: 'Pretendard'),
                                decoration: InputDecoration(
                                  hintText: 'Enter your occupation',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF8F8888),
                                    fontSize: 15,
                                    fontFamily: 'Pretendard',
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8F8F8),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              // 성별 선택
                              const Text(
                                'Gender',
                                style: TextStyle(
                                  color: Color(0xFF391713),
                                  fontSize: 20,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedGender = 'MALE'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _selectedGender == 'MALE'
                                              ? const Color(0xFFE37474)
                                              : const Color(0xFFF8F8F8),
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: Text(
                                          '남성',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _selectedGender == 'MALE'
                                                ? Colors.white
                                                : const Color(0xFF8F8888),
                                            fontSize: 15,
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _selectedGender = 'FEMALE'),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _selectedGender == 'FEMALE'
                                              ? const Color(0xFFE37474)
                                              : const Color(0xFFF8F8F8),
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        child: Text(
                                          '여성',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: _selectedGender == 'FEMALE'
                                                ? Colors.white
                                                : const Color(0xFF8F8888),
                                            fontSize: 15,
                                            fontFamily: 'Pretendard',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              // 생일 선택
                              const Text(
                                'Birth Date',
                                style: TextStyle(
                                  color: Color(0xFF391713),
                                  fontSize: 20,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: _pickBirthDate,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8F8F8),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Text(
                                    _selectedBirthDate != null
                                        ? '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}'
                                        : '생년월일을 선택해주세요',
                                    style: TextStyle(
                                      color: _selectedBirthDate != null
                                          ? const Color(0xFF391713)
                                          : const Color(0xFF8F8888),
                                      fontSize: 15,
                                      fontFamily: 'Pretendard',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                      _WhiteCard(
                        height: cardHeight,
                        middle: Column(
                          children: [
                            ProfileImagePicker(onImageChanged: (file) {}),
                            const SizedBox(height: 12),
                            const Text(
                              '자신의 프로필 작성하기',
                              style: TextStyle(
                                color: Color(0xFFE37474),
                                fontSize: 22,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '자신을 소개하여 주세요!',
                              style: TextStyle(
                                color: Color(0xFF391713),
                                fontSize: 13,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        dots: _dots(active: 0),
                        button: _nextButton(onTap: () async {
                          if (_selectedBirthDate == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('생년월일을 선택해주세요')),
                            );
                            return;
                          }
                          try {
                            final nicknameData = await ApiService.generateNickname();
                            final nickname = nicknameData['data']?['nickname'] ?? 'user';
                            final location = _locationController.text.trim();
                            final locationParts = location.split(' ');
                            String sido = '';
                            String sigungu = '';

                            if (locationParts.length == 1) {
                              // "서울특별시" → sido: 서울특별시, sigungu: 서울특별시
                              sido = locationParts[0];
                              sigungu = locationParts[0];
                            } else if (locationParts.length >= 2) {
                              // "경상남도 김해시" → sido: 경상남도, sigungu: 김해시
                              // "제주특별자치도 제주시" → sido: 제주특별자치도, sigungu: 제주시
                              sido = locationParts[0];
                              sigungu = locationParts.sublist(1).join(' ');
                            }final birthDate =
                                '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}';

                            await ApiService.postProfile(
                              nickname: nickname,
                              realName: _realNameController.text.trim(),
                              gender: _selectedGender,
                              birthDate: birthDate,
                              sido: sido,
                              sigungu: sigungu,
                            );
                            _nextPage();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('오류: $e')),
                              );
                            }
                          }
                        }),
                      ),
                    ],
                  ),

                  // ── 2페이지 ──
                  Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 32),
                              const Text(
                                '이상형 키워드',
                                style: TextStyle(
                                  color: Color(0xFF391713),
                                  fontSize: 20,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),
                              KeywordSelector(
                                onChanged: (keywords) {
                                  setState(() => _keywords = keywords);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      _WhiteCard(
                        height: cardHeight,
                        middle: Column(
                          children: [
                            SvgPicture.asset(
                              'assets/images/card_icon.svg',
                              width: 60,
                              colorFilter: const ColorFilter.mode(
                                Color(0xFFE37474),
                                BlendMode.srcIn,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '이상형 키워드 작성하기',
                              style: TextStyle(
                                color: Color(0xFFE37474),
                                fontSize: 22,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '마음에 드는 이상형 키워드를 눌러보세요.\n선택한 키워드가 나만의 이상형으로 완성됩니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF391713),
                                fontSize: 13,
                                fontFamily: 'Pretendard',
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                        dots: _dots(active: 1),
                        button: _nextButton(onTap: () async {
                          final token = await ApiService.getAccessToken();
                          print('현재 토큰: $token');
                          try {
                            await ApiService.postIdealTypeKeywords(_keywords);
                            _nextPage();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('오류: $e')),
                              );
                            }
                          }
                        }),
                      ),
                    ],
                  ),

                  // ── 3페이지: 프로필 완성 ──
                  Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 32),
                          child: Column(
                            children: const [
                              Text(
                                '프로필 완성!',
                                style: TextStyle(
                                  color: Color(0xFFE37474),
                                  fontSize: 24,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                '당신의 프로필이 완성되었습니다.\n이제 당신을 조금 더 알아갈 준비가 되었어요.\n\n오늘 하루는 어땠나요?\n기분 좋았던 순간도, 조금 지쳤던 시간도\n있는 그대로 적어주세요.\n\n당신의 일기는 단순한 기록이 아니라\n누군가와 마음을 나누는 시작이 됩니다.\n솔직한 하루가 모여\n서로를 더 잘 이해하는 연결로 이어질 거예요.\n\n이제 오늘의 이야기를 남겨볼까요?\n교환할 일기를 작성하고,\n당신의 하루를 누군가와 나눠보세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF391713),
                                  fontSize: 15,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w500,
                                  height: 1.67,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: Column(
                          children: [
                            _dots(active: 2),
                            const SizedBox(height: 16),
                            _nextButton(
                              onTap: () => Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (_) => const DiaryScreen()),
                                    (route) => false,
                              ),
                              label: 'Get Started',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dots({required int active}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(
            width: 20,
            height: 4,
            decoration: BoxDecoration(
              color: i == active
                  ? const Color(0xFFE37474)
                  : const Color(0xFFE9E9E9),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }),
    );
  }

  Widget _nextButton({required VoidCallback onTap, String label = 'Next'}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE37474),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: const Color(0xFFE95322)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontFamily: 'Pretendard',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final double height;
  final Widget middle;
  final Widget dots;
  final Widget button;

  const _WhiteCard({
    required this.height,
    required this.middle,
    required this.dots,
    required this.button,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(
        color: Color(0xFFF8F8F8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(),
          middle,
          Column(
            children: [
              dots,
              const SizedBox(height: 16),
              button,
              const SizedBox(height: 20),
            ],
          ),
        ],
      ),
    );
  }
}