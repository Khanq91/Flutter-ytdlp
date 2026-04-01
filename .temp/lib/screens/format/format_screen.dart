// lib/screens/format/format_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/format_option.dart';
import '../../models/video_info.dart';
import '../../providers/download_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/primary_button.dart';

class FormatScreen extends ConsumerStatefulWidget {
  final VideoInfo videoInfo;

  const FormatScreen({super.key, required this.videoInfo});

  @override
  ConsumerState<FormatScreen> createState() => _FormatScreenState();
}

class _FormatScreenState extends ConsumerState<FormatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// Format đang được chọn
  FormatOption? _selectedFormat;

  /// true = Audio, false = Video
  bool _isAudioTab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Chọn mặc định: audio tốt nhất
    _selectedFormat = widget.videoInfo.bestAudioFormat ??
        (widget.videoInfo.formats.isNotEmpty
            ? widget.videoInfo.formats.first
            : null);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _isAudioTab = _tabController.index == 0;
          // Khi chuyển tab, chọn mặc định của tab đó
          _selectedFormat = _isAudioTab
              ? widget.videoInfo.bestAudioFormat
              : _bestVideoFormat;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<FormatOption> get _audioFormats => widget.videoInfo.audioFormats
    ..sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));

  List<FormatOption> get _videoFormats {
    // Nhóm theo chiều cao, lấy format tốt nhất mỗi độ phân giải
    final formats = widget.videoInfo.videoFormats;
    final Map<int?, FormatOption> byHeight = {};
    for (final f in formats) {
      final h = f.height ?? 0;
      if (!byHeight.containsKey(h) ||
          (byHeight[h]!.filesize ?? 0) < (f.filesize ?? 0)) {
        byHeight[h] = f;
      }
    }
    final result = byHeight.values.toList()
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
    return result;
  }

  FormatOption? get _bestVideoFormat {
    final vf = _videoFormats;
    return vf.isNotEmpty ? vf.first : null;
  }

  void _startDownload() {
    if (_selectedFormat == null) return;

    final notifier = ref.read(downloadProvider.notifier);

    if (widget.videoInfo.type == VideoType.playlist) {
      notifier.enqueuePlaylist(
        playlistInfo: widget.videoInfo,
        format: _selectedFormat!,
      );
    } else {
      notifier.enqueue(
        info: widget.videoInfo,
        format: _selectedFormat!,
      );
    }

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.download,
      (route) => route.settings.name == AppRoutes.analyze,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: AppShell(
        appBar: AppBar(
          title: const Text('Chọn định dạng'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Thumbnail + title preview
                    _VideoPreviewCard(info: widget.videoInfo),
                    const SizedBox(height: 20),

                    // Tab: Audio / Video
                    _FormatTabBar(controller: _tabController),
                    const SizedBox(height: 12),

                    // Format list
                    TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Audio tab
                        _FormatList(
                          formats: _audioFormats,
                          selected: _selectedFormat,
                          onSelect: (f) => setState(() => _selectedFormat = f),
                          emptyLabel: 'Không có định dạng audio',
                        ),
                        // Video tab
                        _FormatList(
                          formats: _videoFormats,
                          selected: _selectedFormat,
                          onSelect: (f) => setState(() => _selectedFormat = f),
                          emptyLabel: 'Không có định dạng video',
                        ),
                      ],
                    ),
                    const SizedBox(height: 100), // space for bottom button
                  ],
                ),
              ),
            ),

            // Bottom button
            _BottomDownloadBar(
              selectedFormat: _selectedFormat,
              isPlaylist: widget.videoInfo.type == VideoType.playlist,
              playlistCount: widget.videoInfo.playlistCount,
              onDownload: _selectedFormat != null ? _startDownload : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Video Preview ──────────────────────────────────────────

class _VideoPreviewCard extends StatelessWidget {
  final VideoInfo info;

  const _VideoPreviewCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Thumbnail nhỏ
          if (info.thumbnail != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: info.thumbnail!,
                width: 80,
                height: 52,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 80,
                  height: 52,
                  color: AppColors.surfaceElevated,
                  child: const Icon(Icons.broken_image_rounded,
                      color: AppColors.textTertiary, size: 20),
                ),
              ),
            ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.platform.displayName,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab Bar ────────────────────────────────────────────────

class _FormatTabBar extends StatelessWidget {
  final TabController controller;

  const _FormatTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textTertiary,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note_rounded, size: 16),
                SizedBox(width: 6),
                Text('Audio'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_rounded, size: 16),
                SizedBox(width: 6),
                Text('Video'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Format List ────────────────────────────────────────────

class _FormatList extends StatelessWidget {
  final List<FormatOption> formats;
  final FormatOption? selected;
  final ValueChanged<FormatOption> onSelect;
  final String emptyLabel;

  const _FormatList({
    required this.formats,
    required this.selected,
    required this.onSelect,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (formats.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            emptyLabel,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      children: formats.map((f) {
        final isSelected = selected?.formatId == f.formatId;
        return _FormatTile(
          format: f,
          isSelected: isSelected,
          onTap: () => onSelect(f),
        );
      }).toList(),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final FormatOption format;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatTile({
    required this.format,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withOpacity(0.5)
                : AppColors.border,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            // Radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  width: isSelected ? 0 : 1.5,
                ),
                gradient: isSelected ? AppColors.primaryGradient : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 13)
                  : null,
            ),
            const SizedBox(width: 12),

            // Format info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    format.displayLabel,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (format.filesize != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      format.formattedFilesize,
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Ext badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                format.ext.toUpperCase(),
                style: TextStyle(
                  color:
                      isSelected ? AppColors.primaryLight : AppColors.textTertiary,
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

// ── Bottom Download Bar ────────────────────────────────────

class _BottomDownloadBar extends StatelessWidget {
  final FormatOption? selectedFormat;
  final bool isPlaylist;
  final int? playlistCount;
  final VoidCallback? onDownload;

  const _BottomDownloadBar({
    required this.selectedFormat,
    required this.isPlaylist,
    required this.playlistCount,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        border: const Border(
          top: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedFormat != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 5),
                Text(
                  isPlaylist
                      ? '${playlistCount ?? "?"} video · ${selectedFormat!.ext.toUpperCase()}'
                      : '${selectedFormat!.displayLabel} · ${selectedFormat!.formattedFilesize}',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          PrimaryButton(
            label: isPlaylist ? 'Tải playlist' : 'Bắt đầu tải',
            icon: Icons.download_rounded,
            onPressed: onDownload,
          ),
        ],
      ),
    );
  }
}
