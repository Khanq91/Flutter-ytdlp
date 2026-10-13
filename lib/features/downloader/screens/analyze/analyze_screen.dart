// lib/features/downloader/screens/analyze/analyze_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/app_router.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';
import 'package:flutter_ytdlp/widgets/glass_container.dart';
import '../../models/video_info.dart';
import '../../providers/analyze_provider.dart';
import '../../providers/download_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/platform_chip.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/primary_icon_button.dart';
import 'package:flutter_ytdlp/core/app_strings.dart';

class AnalyzeScreen extends ConsumerStatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  ConsumerState<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends ConsumerState<AnalyzeScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    _controller.text = data!.text!;
    ref.read(analyzeProvider.notifier).onUrlChanged(data.text!);
  }

  void _clear() {
    _controller.clear();
    ref.read(analyzeProvider.notifier).reset();
    _focusNode.requestFocus();
  }

  Future<void> _analyze() async {
    _focusNode.unfocus();
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    final isOnline = results.any((r) => r != ConnectivityResult.none);
    if (!isOnline) {
      _showSnack('Không có kết nối mạng');
      return;
    }
    await ref.read(analyzeProvider.notifier).analyze();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: context.appColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  /// Hiển thị bottom sheet chọn thư mục lưu nhanh
  Future<void> _showFolderPickerSheet() async {
    final base = await ref.read(downloadExternalBasePathProvider.future);
    if (!mounted) return;

    final outputDir = ref.read(downloadOutputDirectoryProvider.notifier);
    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => _FolderPickerSheet(
            basePath: base,
            currentPath: ref.read(downloadOutputDirectoryProvider).value ?? '',
            onSelect: (path) async {
              await outputDir.setPath(path);
              if (mounted) {
                // Show the folder the service actually kept (setPath keeps the
                // previous one when the chosen folder cannot be created).
                _showSnack(
                  'Đã chọn: ${ref.read(downloadOutputDirectoryProvider).value}',
                );
              }
            },
            onCustomPick: () async {
              final path = await outputDir.pickDirectory();
              if (path != null && mounted) _showSnack('Đã chọn: $path');
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final analyzeState = ref.watch(analyzeProvider);
    final outputDir = ref.watch(downloadOutputDirectoryProvider);
    final serviceReady = outputDir.hasValue;
    // Initial load (or a reload after "Thử lại") — the only time the button
    // should spin. A failed init must not leave it stuck on "Đang khởi động".
    final initializing = outputDir.isLoading;
    final initFailed = outputDir.hasError && !initializing;
    final canAnalyze =
        serviceReady &&
        analyzeState.currentUrl.isNotEmpty &&
        !analyzeState.isLoading;

    return GradientBackground(
      child: AppShell(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Back button row ──────────────────────────
                Row(
                  children: [
                    // 36dp visual inside the default 48dp tap target.
                    IconButton(
                      tooltip: AppStrings.back,
                      onPressed:
                          () =>
                              Navigator.of(context, rootNavigator: true).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: c.surfaceElevated,
                        fixedSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Header ──────────────────────────────────
                _Header(
                  outputPath: outputDir.value,
                  onPickFolder: serviceReady ? _showFolderPickerSheet : null,
                ),
                const SizedBox(height: 28),

                // ── URL Input ────────────────────────────────
                _UrlInputCard(
                  controller: _controller,
                  focusNode: _focusNode,
                  platform: analyzeState.detectedPlatform,
                  isUrlEmpty: analyzeState.currentUrl.isEmpty,
                  onChanged:
                      (url) =>
                          ref.read(analyzeProvider.notifier).onUrlChanged(url),
                  onPaste: _paste,
                  onClear: _clear,
                  onSubmit: canAnalyze ? _analyze : null,
                ),
                const SizedBox(height: 16),

                // ── Analyze Button ───────────────────────────
                PrimaryButton(
                  label: initializing ? 'Đang khởi động...' : 'Phân tích',
                  icon: Icons.search_rounded,
                  isLoading: analyzeState.isLoading || initializing,
                  onPressed: canAnalyze ? _analyze : null,
                ),
                if (initFailed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _ErrorCard(
                      message: AppStrings.initFailed,
                      onRetry:
                          () => ref.invalidate(downloadOutputDirectoryProvider),
                    ),
                  ),

                // ── Result Area ──────────────────────────────
                if (analyzeState.hasResult) ...[
                  const SizedBox(height: 24),
                  _ResultCard(info: analyzeState.videoInfo!),
                ],

                if (analyzeState.hasError) ...[
                  const SizedBox(height: 16),
                  _ErrorCard(message: analyzeState.errorMessage!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Folder Picker Sheet ─────────────────────────────────────────────────────

class _FolderPickerSheet extends StatelessWidget {
  final String basePath;
  final String currentPath;
  final Future<void> Function(String path) onSelect;
  final VoidCallback onCustomPick;

  const _FolderPickerSheet({
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

            // Title
            Text(
              'Chọn thư mục lưu',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'File tải về sẽ được lưu vào thư mục này',
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
                    vertical: 13,
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
                        child: Icon(opt.icon, color: opt.color, size: 20),
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

            // const SizedBox(height: 4),

            // Custom pick option
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onCustomPick();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border, width: 0.8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c.textTertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.folder_open_rounded,
                        color: c.textSecondary,
                        size: 20,
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
                            'Duyệt và chọn thư mục tùy chỉnh',
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

// ── Header ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  /// Null while the output directory is still loading.
  final String? outputPath;
  final VoidCallback? onPickFolder;

  const _Header({required this.outputPath, required this.onPickFolder});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback:
              (bounds) => c.primaryGradient.createShader(bounds),
          child: Row(
            children: [
              const Text(
                'from ',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w100,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const Text(
                'Muzicz',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        Text(
          'Dán link từ YouTube, TikTok, Instagram,... và hơn thế nữa',
          style: TextStyle(fontSize: 14, color: c.textSecondary),
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            PrimaryIconButton(
              icon: Icons.folder_open_rounded,
              semanticLabel: AppStrings.pickSaveFolder,
              onPressed: onPickFolder,
            ),

            const SizedBox(width: 6),

            Expanded(
              child: GestureDetector(
                onTap:
                    outputPath != null
                        ? () => _showFullPath(context, outputPath!)
                        : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        outputPath != null
                            ? 'Lưu: $outputPath'
                            : 'Đang tải thư mục...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: c.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

void _showFullPath(BuildContext context, String path) {
  showDialog(
    context: context,
    builder:
        (_) => AlertDialog(
          title: const Text('Thư mục lưu'),
          content: SelectableText(path),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
  );
}

// ── URL Input Card ─────────────────────────────────────────

class _UrlInputCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String platform;
  final bool isUrlEmpty;
  final ValueChanged<String> onChanged;
  final VoidCallback onPaste;
  final VoidCallback onClear;

  /// Keyboard "Go" action — same gate as the Phân tích button.
  final VoidCallback? onSubmit;

  const _UrlInputCard({
    required this.controller,
    required this.focusNode,
    required this.platform,
    required this.isUrlEmpty,
    required this.onChanged,
    required this.onPaste,
    required this.onClear,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Dán link video vào đây...',
                    hintStyle: TextStyle(
                      color: c.textTertiary,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  ),
                  maxLines: 2,
                  minLines: 1,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => onSubmit?.call(),
                  autocorrect: false,
                ),
              ),
              _ActionIconButton(
                onTap: isUrlEmpty ? onPaste : onClear,
                icon:
                    isUrlEmpty
                        ? Icons.content_paste_rounded
                        : Icons.close_rounded,
                tooltip: isUrlEmpty ? 'Dán' : 'Xóa',
              ),
            ],
          ),

          if (platform.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Nhận diện: ',
                  style: TextStyle(fontSize: 12, color: c.textTertiary),
                ),
                PlatformChip(platform: platform),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final String tooltip;

  const _ActionIconButton({
    required this.onTap,
    required this.icon,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // 36dp visual centred in a 48dp hit area.
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.surfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: c.textSecondary, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Result Card ────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final VideoInfo info;

  const _ResultCard({required this.info});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.thumbnail != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: info.thumbnail!,
                  fit: BoxFit.cover,
                  placeholder:
                      (_, __) => Container(
                        color: c.surfaceElevated,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: c.primary,
                          ),
                        ),
                      ),
                  errorWidget:
                      (_, __, ___) => Container(
                        color: c.surfaceElevated,
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: c.textTertiary,
                          size: 36,
                        ),
                      ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          Text(
            info.title,
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              PlatformChip(platform: info.platform.displayName),
              const SizedBox(width: 8),
              _MetaBadge(
                icon:
                    info.type == VideoType.playlist
                        ? Icons.playlist_play_rounded
                        : Icons.play_arrow_rounded,
                label:
                    info.type == VideoType.playlist
                        ? '${info.playlistCount ?? "?"} video'
                        : 'Video',
              ),
              if (info.duration != null && info.type == VideoType.video) ...[
                const SizedBox(width: 8),
                _MetaBadge(
                  icon: Icons.access_time_rounded,
                  label: info.formattedDuration,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          Divider(height: 1, color: c.divider),
          const SizedBox(height: 14),

          Consumer(
            builder:
                (context, ref, _) => PrimaryButton(
                  label: 'Chọn định dạng',
                  icon: Icons.tune_rounded,
                  onPressed: () {
                    if (info.type == VideoType.playlist) {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.playlistPicker,
                        arguments: info,
                      );
                    } else {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.format,
                        arguments: FormatScreenArgs(videoInfo: info),
                      );
                    }
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: c.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error Card ─────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorCard({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: c.error.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: c.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: c.error,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 6),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: c.error,
                minimumSize: const Size(48, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Text(
                AppStrings.retry,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
