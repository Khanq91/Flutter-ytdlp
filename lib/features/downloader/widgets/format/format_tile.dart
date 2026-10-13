import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';
import '../../models/format_option.dart';

class FormatTile extends StatelessWidget {
  final FormatOption format;
  final bool isSelected;
  final VoidCallback onTap;

  const FormatTile({
    super.key,
    required this.format,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? c.primary.withValues(alpha: 0.12)
                  : c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? c.primary.withValues(alpha: 0.5)
                    : c.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      isSelected ? c.primary : c.textTertiary,
                  width: isSelected ? 0 : 1.5,
                ),
                gradient: isSelected ? c.primaryGradient : null,
              ),
              child:
                  isSelected
                      ? Icon(
                        Icons.check_rounded,
                        color: c.onPlayer,
                        size: 13,
                      )
                      : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format.displayLabel,
                    style: TextStyle(
                      color:
                          isSelected
                              ? c.textPrimary
                              : c.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (format.filesize != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      format.formattedFilesize,
                      style: TextStyle(
                        color: c.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? c.primary.withValues(alpha: 0.2)
                        : c.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                format.ext.toUpperCase(),
                style: TextStyle(
                  color:
                      isSelected
                          ? c.primaryLight
                          : c.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
