import 'package:flutter/material.dart';

class TopNavBar extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  const TopNavBar({
    super.key,
    this.onBack,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (onBack != null)
            IconButton(
              icon: const Icon(Icons.chevron_left,
                  size: 28, color: Color(0xFF391713)),
              onPressed: onBack,
            )
          else
            const SizedBox(width: 48),
          IconButton(
            icon: const Icon(Icons.close, size: 24, color: Color(0xFF391713)),
            onPressed: onClose ?? () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}