import 'package:flutter/material.dart';

class VerificationBadge extends StatelessWidget {
  final bool isVerified;
  final double size;
  final bool showText;

  const VerificationBadge({
    super.key,
    required this.isVerified,
    this.size = 16,
    this.showText = false,
  });

  @override
  Widget build(BuildContext context) {
    if (showText) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isVerified ? Colors.green : Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          isVerified ? 'Verified' : 'Pending',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isVerified ? Colors.green : Colors.orange,
        shape: BoxShape.circle,
      ),
      child: Icon(
        isVerified ? Icons.verified : Icons.pending,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
} 