// lib/widgets/platform_chip.dart

import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';

/// Chip nhỏ hiển thị tên platform (YouTube, TikTok, v.v.)
/// Xuất hiện dưới TextField ngay khi detect được URL.
class PlatformChip extends StatelessWidget {
  final String platform;

  const PlatformChip({super.key, required this.platform});

  @override
  Widget build(BuildContext context) {
    if (platform.isEmpty) return const SizedBox.shrink();

    final c = context.appColors;
    final color = _colorForPlatform(platform, c);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForPlatform(platform), size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              platform,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForPlatform(String platform, AppColorsData c) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return const Color(0xFFFF3B30);
      case 'tiktok':
        return c.isDark ? const Color(0xFF69C9D0) : const Color(0xFF147D85);
      case 'instagram':
        return const Color(0xFFE1306C);
      case 'facebook':
        return const Color(0xFF1877F2);
      case 'twitter / x':
        return c.textPrimary;
      case 'vimeo':
        return c.isDark ? const Color(0xFF1AB7EA) : const Color(0xFF087A9E);
      default:
        return c.primary;
    }
  }

  IconData _iconForPlatform(String platform) {
    switch (platform.toLowerCase()) {
      case 'youtube':
        return Icons.play_circle_fill_rounded;
      case 'tiktok':
        return Icons.music_note_rounded;
      case 'instagram':
        return Icons.camera_alt_rounded;
      case 'facebook':
        return Icons.facebook_rounded;
      case 'twitter / x':
        return Icons.alternate_email_rounded;
      case 'vimeo':
        return Icons.videocam_rounded;
      default:
        return Icons.language_rounded;
    }
  }
}
