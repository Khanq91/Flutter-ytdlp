// lib/screens/analyze/analyze_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/video_info.dart';
import '../../providers/analyze_provider.dart';
import '../../providers/network_provider.dart';
import '../../services/network_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/platform_chip.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/primary_icon_button.dart';

class AnalyzeScreen extends ConsumerStatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  ConsumerState<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends ConsumerState<AnalyzeScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _serviceReady = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initServices();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initServices() async {
    try {
      await StorageService.instance.init();
      if (mounted) setState(() => _serviceReady = true);
    } catch (e) {
      if (mounted) setState(() => _initError = 'Khởi động thất bại: $e');
    }
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _controller.text = data!.text!;
      ref.read(analyzeProvider.notifier).onUrlChanged(data.text!);
    }
  }

  void _clear() {
    _controller.clear();
    ref.read(analyzeProvider.notifier).reset();
    _focusNode.requestFocus();
  }

  Future<void> _analyze() async {
    _focusNode.unfocus();
    final isOnline = await ref.read(networkStatusProvider.future).then(
          (s) => s == NetworkStatus.online,
        );
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
        backgroundColor: AppColors.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analyzeState = ref.watch(analyzeProvider);

    return GradientBackground(
      child: AppShell(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────
                // const _Header(),
                _Header(
                  serviceReady: _serviceReady,
                  onPickFolder: () async {
                    final path = await StorageService.instance.pickDownloadDirectory();
                    if (path != null) {
                      setState(() {});

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã chọn: $path')),
                      );
                    }
                  },
                ),
                const SizedBox(height: 28),

                // ── URL Input ────────────────────────────────
                _UrlInputCard(
                  controller: _controller,
                  focusNode: _focusNode,
                  platform: analyzeState.detectedPlatform,
                  onChanged: (url) =>
                      ref.read(analyzeProvider.notifier).onUrlChanged(url),
                  onPaste: _paste,
                  onClear: _clear,
                ),
                const SizedBox(height: 16),

                // ── Analyze Button ───────────────────────────
                PrimaryButton(
                  label: _serviceReady ? 'Phân tích' : 'Đang khởi động...',
                  icon: Icons.search_rounded,
                  isLoading: analyzeState.isLoading || !_serviceReady,
                  onPressed: _serviceReady &&
                      analyzeState.currentUrl.isNotEmpty &&
                      !analyzeState.isLoading
                      ? _analyze
                      : null,
                ),
                // Hiện lỗi init nếu có
                if (_initError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _ErrorCard(message: _initError!),
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

// ── Header ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final bool serviceReady;
  final VoidCallback onPickFolder;

  const _Header({
    required this.serviceReady,
    required this.onPickFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShaderMask(
          shaderCallback: (bounds) =>
              AppColors.primaryGradient.createShader(bounds),
          child: const Text(
            'Tải video',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),

        Text(
          'Dán link từ YouTube, TikTok, Instagram và hơn thế nữa',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            PrimaryIconButton(
              icon: Icons.folder_open_rounded,
              onPressed: onPickFolder,
            ),

            const SizedBox(width: 6),

            Expanded(
              child: GestureDetector(
                onTap: serviceReady ? () => _showFullPath(context) : null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        serviceReady
                            ? 'Thư mục lưu: ${StorageService.instance.downloadPath}'
                            : 'Đang tải thư mục...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}

void _showFullPath(BuildContext context) {
  final path = StorageService.instance.downloadPath;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
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
  final ValueChanged<String> onChanged;
  final VoidCallback onPaste;
  final VoidCallback onClear;

  const _UrlInputCard({
    required this.controller,
    required this.focusNode,
    required this.platform,
    required this.onChanged,
    required this.onPaste,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TextField
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Dán link video vào đây...',
                    hintStyle: TextStyle(
                      color: AppColors.textTertiary,
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
                  autocorrect: false,
                ),
              ),
              // Paste / Clear button
              _ActionIconButton(
                onTap: controller.text.isEmpty ? onPaste : onClear,
                icon: controller.text.isEmpty
                    ? Icons.content_paste_rounded
                    : Icons.close_rounded,
                tooltip: controller.text.isEmpty ? 'Dán' : 'Xóa',
              ),
            ],
          ),

          // Platform chip (hiện khi detect được)
          if (platform.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Nhận diện: ',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
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
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 18),
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
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail
          if (info.thumbnail != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: info.thumbnail!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppColors.surfaceElevated,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.surfaceElevated,
                    child: const Icon(
                      Icons.broken_image_rounded,
                      color: AppColors.textTertiary,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Title
          Text(
            info.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),

          // Meta row
          Row(
            children: [
              PlatformChip(platform: info.platform.displayName),
              const SizedBox(width: 8),
              _MetaBadge(
                icon: info.type == VideoType.playlist
                    ? Icons.playlist_play_rounded
                    : Icons.play_arrow_rounded,
                label: info.type == VideoType.playlist
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

          // Divider
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),

          // Navigate to format screen
          Consumer(
            builder: (context, ref, _) => PrimaryButton(
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
                  // Video đơn → thẳng FormatScreen
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
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

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF3B30).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF3B30).withOpacity(0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFFF3B30),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFFF3B30),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
