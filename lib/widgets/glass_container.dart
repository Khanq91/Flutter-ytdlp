import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';

class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 12.0,
    this.opacity = 0.12,
    this.borderRadius = 16.0,
    this.padding,
    this.border = true,
    this.color,
  });

  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool border;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (color ?? c.glassBg).withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border:
                border ? Border.all(color: c.glassBorder, width: 0.5) : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
