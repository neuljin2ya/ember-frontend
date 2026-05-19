import 'package:flutter/material.dart';

const List<Map<String, dynamic>> keywordList = [
  {'id': 1, 'label': '안정적인 사람'},
  {'id': 2, 'label': '긍정적인 사람'},
  {'id': 3, 'label': '따뜻한 사람'},
  {'id': 4, 'label': '공감적인 사람'},
  {'id': 5, 'label': '다정한 사람'},
  {'id': 6, 'label': '솔직한 사람'},
  {'id': 7, 'label': '성실한 사람'},
  {'id': 8, 'label': '도전적인 사람'},
  {'id': 9, 'label': '자유로운 사람'},
  {'id': 10, 'label': '깊이 있는 사람'},
];

class KeywordSelector extends StatefulWidget {
  final ValueChanged<List<int>>? onChanged;

  const KeywordSelector({super.key, this.onChanged});

  @override
  State<KeywordSelector> createState() => _KeywordSelectorState();
}

class _KeywordSelectorState extends State<KeywordSelector> {
  final List<Map<String, dynamic>> _selected = [];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  List<Map<String, dynamic>> get _available =>
      keywordList.where((k) => !_selected.any((s) => s['id'] == k['id'])).toList();

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
    if (mounted) setState(() {});
  }

  void _select(Map<String, dynamic> keyword) {
    if (_selected.length >= 3) return;
    setState(() => _selected.add(keyword));
    _removeDropdown();
    widget.onChanged?.call(_selected.map((k) => k['id'] as int).toList());
  }

  void _remove(Map<String, dynamic> keyword) {
    setState(() => _selected.removeWhere((k) => k['id'] == keyword['id']));
    widget.onChanged?.call(_selected.map((k) => k['id'] as int).toList());
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
                                keyword['label'],
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
          if (_selected.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selected.map((keyword) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD8DDE3)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0C17191C), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        keyword['label'],
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
                        child: const Icon(Icons.close, size: 14, color: Color(0xFF4C5C6B)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],

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