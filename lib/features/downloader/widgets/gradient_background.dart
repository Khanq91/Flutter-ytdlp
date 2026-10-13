// lib/widgets/gradient_background.dart

import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';

/// Nền gradient toàn màn hình theo backgroundGradient của theme hiện tại
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      decoration: BoxDecoration(
        gradient: c.backgroundGradient,
      ),
      child: child,
    );
  }
}