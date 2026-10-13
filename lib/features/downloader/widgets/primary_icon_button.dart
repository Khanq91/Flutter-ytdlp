// lib/widgets/primary_icon_button.dart

import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';

class PrimaryIconButton extends StatelessWidget {
  final IconData icon;

  /// Icon-only button: TalkBack needs a name (also shown as tooltip).
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double size;

  const PrimaryIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.isLoading = false,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final enabled = onPressed != null && !isLoading;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: enabled ? 1.0 : 0.5,
          child: GestureDetector(
            onTap: enabled ? onPressed : null,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient:
                    enabled
                        ? c.primaryGradient
                        : c.disabledGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow:
                    enabled
                        ? [
                          BoxShadow(
                            color: c.primary.withValues(alpha: 0.35),
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
                  splashColor: c.onPlayer.withValues(alpha: 0.1),
                  child: Center(
                    child:
                        isLoading
                            ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: c.onPlayer,
                              ),
                            )
                            : Icon(icon, color: c.onPlayer, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
