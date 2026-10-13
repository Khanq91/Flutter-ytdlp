import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';
import 'synthetic_formats.dart';

class _MuxedOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _MuxedOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? c.primary.withValues(alpha: 0.2)
                        : c.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? c.primary : c.textTertiary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color:
                          isSelected
                              ? c.textPrimary
                              : c.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: c.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
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
          ],
        ),
      ),
    );
  }
}

class ExtractAudioTile extends StatelessWidget {
  final String? selectedFormatId;
  final VoidCallback onSelectAudio;
  final VoidCallback onSelectVideo;

  const ExtractAudioTile({
    super.key,
    required this.selectedFormatId,
    required this.onSelectAudio,
    required this.onSelectVideo,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: c.primary.withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: c.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Video này chỉ có định dạng muxed (video+audio). Chọn định dạng bạn muốn lưu.',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        _MuxedOptionTile(
          icon: Icons.audio_file_rounded,
          title: 'Chỉ Audio (M4A)',
          subtitle: 'Tải video → tách lấy âm thanh · không mất chất lượng',
          isSelected: selectedFormatId == kExtractAudioFormatId,
          onTap: onSelectAudio,
        ),
      ],
    );
  }
}
