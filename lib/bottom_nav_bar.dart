import 'package:flutter/material.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE37474),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  Icons.home,
                  color: currentIndex == 0 ? Colors.white : Colors.white70,
                ),
                onPressed: () => onTap(0),
              ),
              IconButton(
                icon: Icon(
                  Icons.favorite_border,
                  color: currentIndex == 1 ? Colors.white : Colors.white70,
                ),
                onPressed: () => onTap(1),
              ),
              IconButton(
                icon: Icon(
                  Icons.headset_mic_outlined,
                  color: currentIndex == 2 ? Colors.white : Colors.white70,
                ),
                onPressed: () => onTap(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
