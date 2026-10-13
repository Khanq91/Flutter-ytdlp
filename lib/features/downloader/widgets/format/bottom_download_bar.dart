import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';
import '../../models/format_option.dart';
import '../primary_button.dart';
import 'playlist_preset.dart';

class BottomDownloadBar extends StatelessWidget {
  final FormatOption? selectedFormat;
  final PlaylistPreset? selectedPreset;
  final bool isPlaylist;
  final int? playlistCount;
  final String currentPath;
  final VoidCallback onPickFolder;
  final bool isSubmitting;
  final VoidCallback? onDownload;

  const BottomDownloadBar({
    super.key,
    required this.selectedFormat,
    required this.selectedPreset,
    required this.isPlaylist,
    required this.playlistCount,
    required this.currentPath,
    required this.onPickFolder,
    required this.isSubmitting,
    required this.onDownload,
  });

  String get _infoText {
    if (isPlaylist && selectedPreset != null) {
      return '${playlistCount ?? "?"} video · ${selectedPreset!.label} · ${selectedPreset!.ext.toUpperCase()}';
    }
    if (!isPlaylist && selectedFormat != null) {
      return switch (selectedFormat!.formatId) {
        '__extract_audio__' =>
          'Tải video → tách audio M4A (file MP4 sẽ bị xóa)',
        '__muxed_video__' => 'Giữ nguyên video MP4',
        _ =>
          '${selectedFormat!.displayLabel} · ${selectedFormat!.formattedFilesize}',
      };
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: c.divider, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Folder path row
          GestureDetector(
            onTap: onPickFolder,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border, width: 0.6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_rounded,
                    size: 14,
                    color: c.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentPath,
                      style: TextStyle(
                        color: c.textTertiary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.edit_rounded,
                    size: 13,
                    color: c.textTertiary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          if (_infoText.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: c.textTertiary,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    _infoText,
                    style: TextStyle(
                      color: c.textTertiary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          PrimaryButton(
            label: isPlaylist ? 'Tải playlist' : 'Bắt đầu tải',
            icon: Icons.download_rounded,
            isLoading: isSubmitting,
            onPressed: onDownload,
          ),
        ],
      ),
    );
  }
}
