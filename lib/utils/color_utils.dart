import 'package:flutter/material.dart';

class ColorUtils {
  static Color getPercentageColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    if (percentage >= 40) return Colors.yellow.shade700;
    if (percentage >= 20) return Colors.red.shade400;
    return Colors.red;
  }

  // Universal theme colors
  static const Color matteBlack = Color(0xFF181818); // deep matte black
  static const Color softWhite = Color(0xFFF8F8F8); // soft white
} 