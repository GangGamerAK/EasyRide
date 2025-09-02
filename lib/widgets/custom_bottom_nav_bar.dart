import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

class CustomBottomNavBar extends StatelessWidget {
  final VoidCallback onChat;
  final VoidCallback onSetRoute;
  final VoidCallback onProfile;
  final int selectedIndex;

  const CustomBottomNavBar({
    Key? key,
    required this.onChat,
    required this.onSetRoute,
    required this.onProfile,
    this.selectedIndex = 1, // default to center
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: ColorUtils.matteBlack,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(
            icon: Icons.chat_bubble_outline,
            onTap: onChat,
            isSelected: selectedIndex == 0,
            size: 54,
            iconSize: 28,
          ),
          _buildNavButton(
            icon: Icons.alt_route,
            onTap: onSetRoute,
            isSelected: selectedIndex == 1,
            size: 68, // Center button is larger
            iconSize: 36,
          ),
          _buildNavButton(
            icon: Icons.person_outline,
            onTap: onProfile,
            isSelected: selectedIndex == 2,
            size: 54,
            iconSize: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isSelected,
    required double size,
    required double iconSize,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isSelected ? ColorUtils.softWhite : ColorUtils.matteBlack,
          shape: BoxShape.circle,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
          border: Border.all(
            color: isSelected ? ColorUtils.matteBlack : ColorUtils.softWhite,
            width: 2,
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: iconSize,
            color: isSelected ? ColorUtils.matteBlack : ColorUtils.softWhite,
          ),
        ),
      ),
    );
  }
} 