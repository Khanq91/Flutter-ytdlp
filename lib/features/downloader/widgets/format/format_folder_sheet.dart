import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';

class _FolderOption {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final String path;

  const _FolderOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.path,
  });
}

// ── Format Folder Sheet ────────────────────────────────────

class FormatFolderSheet extends StatelessWidget {
  final String basePath;
  final String currentPath;
  final void Function(String) onSelect;
  final VoidCallback onCustomPick;

  const FormatFolderSheet({
    super.key,
    required this.basePath,
    required this.currentPath,
    required this.onSelect,
    required this.onCustomPick,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final options = [
      _FolderOption(
        icon: Icons.music_note_rounded,
        label: 'Music',
        sublabel: 'Music/',
        color: c.primary,
        path: '$basePath/Music',
      ),
      _FolderOption(
        icon: Icons.download_rounded,
        label: 'MuziczModule',
        sublabel: 'Download/MuziczModule/',
        color: c.success,
        path: '$basePath/Download/MuziczModule',
      ),
      _FolderOption(
        icon: Icons.video_library_rounded,
        label: 'Videos',
        sublabel: 'Movies/',
        color: c.warning,
        path: '$basePath/Movies',
      ),
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Lưu vào thư mục',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Chọn nơi lưu file sau khi tải',
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Quick options
            ...options.map((opt) {
              final isSelected = currentPath == opt.path;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onSelect(opt.path);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? opt.color.withValues(alpha: 0.1)
                            : c.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected
                              ? opt.color.withValues(alpha: 0.4)
                              : c.border,
                      width: isSelected ? 1.2 : 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: opt.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(opt.icon, color: opt.color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt.label,
                              style: TextStyle(
                                color:
                                    isSelected
                                        ? c.textPrimary
                                        : c.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              opt.sublabel,
                              style: TextStyle(
                                color: c.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: c.primary,
                          size: 18,
                        ),
                    ],
                  ),
                ),
              );
            }),

            // Custom pick option
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onCustomPick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c.textTertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.folder_open_rounded,
                        color: c.textSecondary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chọn đường dẫn',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Duyệt thư mục tùy chỉnh',
                            style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: c.textTertiary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
