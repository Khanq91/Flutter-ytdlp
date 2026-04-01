// lib/widgets/primary_icon_button.dart

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class PrimaryIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double size;

  const PrimaryIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: enabled
                ? AppColors.primaryGradient
                : const LinearGradient(
              colors: [Color(0xFF444444), Color(0xFF333333)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: enabled
                ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.white.withOpacity(0.1),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}