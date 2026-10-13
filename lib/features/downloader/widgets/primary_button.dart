// lib/widgets/primary_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';

/// Nút chính với gradient tím, bo tròn, hỗ trợ loading state.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final enabled = onPressed != null && !isLoading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient:
                enabled
                    ? c.primaryGradient
                    : c.disabledGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow:
                enabled
                    ? [
                      BoxShadow(
                        color: c.primary.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                    : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(14),
              splashColor: c.onPlayer.withValues(alpha: 0.1),
              child: Center(
                child:
                    isLoading
                        ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.onPlayer,
                          ),
                        )
                        : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: c.onPlayer, size: 18),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                color: c.onPlayer,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
