import 'package:flutter/material.dart';

const List<String> keywordList = [
  '안정적인 사람',
  '긍정적인 사람',
  '따뜻한 사람',
  '공감적인 사람',
  '다정한 사람',
  '솔직한 사람',
  '성실한 사람',
  '도전적인 사람',
  '자유로운 사람',
  '깊이 있는 사람',
];

class KeywordSelector extends StatefulWidget {
  final ValueChanged<List<String>>? onChanged;

  const KeywordSelector({super.key, this.onChanged});

  @override
  State<KeywordSelector> createState() => _KeywordSelectorState();
}

class _KeywordSelectorState extends State<KeywordSelector> {
  final List<String> _selected = [];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<String> get _available =>
      keywordList.where((k) => !_selected.contains(k)).toList();

  void _toggleDropdown() {
    if (_overlayEntry != null) {
      _removeDropdown();
    } else {
      _showDropdown();
    }
  }

  void _showDropdown() {
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {});
  }

  void _removeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {});
  }

  void _select(String keyword) {
    if (_selected.length >= 3) return;
    setState(() => _selected.add(keyword));
    _removeDropdown();
    widget.onChanged?.call(_selected);
  }

  void _remove(String keyword) {
    setState(() => _selected.remove(keyword));
    widget.onChanged?.call(_selected);
  }

  OverlayEntry _buildOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (_) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _available.map((keyword) {
                  return Column(
                    children: [
                      InkWell(
                        onTap: () => _select(keyword),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Text(
                                keyword,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF391713),
                                  fontFamily: 'Pretendard',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (keyword != _available.last)
                        const Divider(height: 1, color: Color(0xFFE5E5E5)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 선택된 태그들 - Wrap으로 잘림 방지
          if (_selected.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selected.map((keyword) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD8DDE3)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C17191C),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        keyword,
                        style: const TextStyle(
                          color: Color(0xFF4C5C6B),
                          fontSize: 14,
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _remove(keyword),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Color(0xFF4C5C6B),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

          // 드롭다운 버튼
          GestureDetector(
            onTap: _selected.length < 3 ? _toggleDropdown : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selected.length >= 3
                        ? '최대 3개까지 선택할 수 있어요'
                        : '키워드를 선택하세요 (최대 3개)',
                    style: const TextStyle(
                      color: Color(0xFF8F8888),
                      fontSize: 14,
                      fontFamily: 'Pretendard',
                    ),
                  ),
                  Icon(
                    _overlayEntry != null
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF8F8888),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}