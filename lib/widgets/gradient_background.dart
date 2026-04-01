// lib/widgets/gradient_background.dart

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Nền gradient toàn màn hình theo AppColors.backgroundGradient
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: child,
    );
  }
}