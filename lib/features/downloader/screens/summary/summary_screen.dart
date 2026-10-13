// lib/features/downloader/screens/summary/summary_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';
import 'package:flutter_ytdlp/widgets/glass_container.dart';
import '../../models/download_task.dart';
import '../../providers/download_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/primary_button.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.appColors;
    final dlState = ref.watch(downloadProvider);

    return GradientBackground(
      child: AppShell(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: c.textPrimary,
            ),
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
            tooltip: 'Về trang chủ',
          ),
          title: Text(
            'Kết quả tải',
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: false,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Icon + title ─────────────────────────────
                        _SummaryHeader(
                          successCount: dlState.successCount,
                          errorCount: dlState.errorCount,
                        ),
                        const SizedBox(height: 32),

                        // ── Stats ────────────────────────────────────
                        _StatsGrid(state: dlState),
                        const SizedBox(height: 24),

                        // ── Failed list ──────────────────────────────
                        if (dlState.errorCount > 0) ...[
                          _FailedList(
                            tasks:
                                dlState.tasks
                                    .where(
                                      (t) => t.status == DownloadStatus.error,
                                    )
                                    .toList(),
                            onRetryAll: () {
                              for (final t in dlState.tasks.where(
                                (t) => t.status == DownloadStatus.error,
                              )) {
                                ref.read(downloadProvider.notifier).retry(t.id);
                              }
                              Navigator.pushReplacementNamed(
                                context,
                                AppRoutes.download,
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Actions ──────────────────────────────────
                PrimaryButton(
                  label: 'Mở thư mục Tải',
                  icon: Icons.folder_open_rounded,
                  onPressed: () async {
                    try {
                      await ref
                          .read(downloadOutputDirectoryProvider.notifier)
                          .openFolder();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Không thể mở thư mục, vui lòng mở Files thủ công',
                            ),
                            backgroundColor: c.surfaceElevated,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    ref.read(downloadProvider.notifier).clearFinished();
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.analyze,
                      (_) => false,
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Tải thêm video'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.primary,
                    side: BorderSide(
                      color: c.primary,
                      width: 0.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Nút về trang chủ / profile ──────────────
                TextButton.icon(
                  onPressed:
                      () => Navigator.of(context, rootNavigator: true).pop(),
                  icon: Icon(
                    Icons.home_rounded,
                    size: 18,
                    color: c.textTertiary,
                  ),
                  label: Text(
                    'Về trang chủ',
                    style: TextStyle(color: c.textTertiary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final int successCount;
  final int errorCount;

  const _SummaryHeader({required this.successCount, required this.errorCount});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final allSuccess = errorCount == 0;

    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                allSuccess
                    ? c.successGradient
                    : c.primaryGradient,
          ),
          child: Icon(
            allSuccess ? Icons.check_rounded : Icons.download_done_rounded,
            color: c.onPlayer,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),

        Text(
          allSuccess ? 'Tải thành công!' : 'Hoàn thành',
          style: TextStyle(
            color: c.textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          allSuccess
              ? 'Tất cả $successCount video đã được tải xuống'
              : '$successCount thành công · $errorCount thất bại',
          style: TextStyle(color: c.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}

// ── Stats Grid ─────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final DownloadState state;

  const _StatsGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Tổng cộng',
            value: '${state.totalCount}',
            icon: Icons.download_rounded,
            color: c.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Thành công',
            value: '${state.successCount}',
            icon: Icons.check_circle_rounded,
            color: c.success,
          ),
        ),
        if (state.errorCount > 0) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Thất bại',
              value: '${state.errorCount}',
              icon: Icons.error_rounded,
              color: c.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: c.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Failed List ────────────────────────────────────────────

class _FailedList extends StatelessWidget {
  final List<DownloadTask> tasks;
  final VoidCallback onRetryAll;

  const _FailedList({required this.tasks, required this.onRetryAll});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Video thất bại',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: onRetryAll,
                style: TextButton.styleFrom(
                  foregroundColor: c.primary,
                  backgroundColor: c.primary.withValues(alpha: 0.12),
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 13),
                label: const Text('Thử lại tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: c.divider),
          ...tasks.take(5).map((t) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 14,
                        color: c.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (t.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 22, top: 2),
                      child: Text(
                        t.errorMessage!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: c.error,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
          if (tasks.length > 5) ...[
            const SizedBox(height: 4),
            Text(
              '...và ${tasks.length - 5} video khác',
              style: TextStyle(
                color: c.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
