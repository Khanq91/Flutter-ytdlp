// lib/screens/summary/summary_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/download_task.dart';
import '../../providers/download_provider.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/primary_button.dart';

class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dlState = ref.watch(downloadProvider);

    return GradientBackground(
      child: AppShell(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
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
                    tasks: dlState.tasks
                        .where((t) => t.status == DownloadStatus.error)
                        .toList(),
                    onRetryAll: () {
                      for (final t in dlState.tasks
                          .where((t) => t.status == DownloadStatus.error)) {
                        ref.read(downloadProvider.notifier).retry(t.id);
                      }
                      Navigator.pushReplacementNamed(
                          context, AppRoutes.download);
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                const Spacer(),

                // ── Actions ──────────────────────────────────
                PrimaryButton(
                  label: 'Mở thư mục Download',
                  icon: Icons.folder_open_rounded,
                  onPressed: () async {
                    await StorageService.instance.openDownloadFolder();
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
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                        color: AppColors.primary, width: 0.8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size(double.infinity, 52),
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

  const _SummaryHeader({
    required this.successCount,
    required this.errorCount,
  });

  @override
  Widget build(BuildContext context) {
    final allSuccess = errorCount == 0;

    return Column(
      children: [
        // Icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: allSuccess
                ? const LinearGradient(
                    colors: [Color(0xFF34C759), Color(0xFF30D158)],
                  )
                : AppColors.primaryGradient,
          ),
          child: Icon(
            allSuccess
                ? Icons.check_rounded
                : Icons.download_done_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),

        Text(
          allSuccess ? 'Tải thành công!' : 'Hoàn thành',
          style: const TextStyle(
            color: AppColors.textPrimary,
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
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
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
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Tổng cộng',
            value: '${state.totalCount}',
            icon: Icons.download_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Thành công',
            value: '${state.successCount}',
            icon: Icons.check_circle_rounded,
            color: const Color(0xFF34C759),
          ),
        ),
        if (state.errorCount > 0) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              label: 'Thất bại',
              value: '${state.errorCount}',
              icon: Icons.error_rounded,
              color: const Color(0xFFFF3B30),
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
    return GlassCard(
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
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
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
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Video thất bại',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: onRetryAll,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 13, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text(
                        'Thử lại tất cả',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          ...tasks.take(5).map((t) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 14, color: Color(0xFFFF3B30)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
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
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
