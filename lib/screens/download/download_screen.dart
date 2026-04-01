// lib/screens/download/download_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/download_task.dart';
import '../../providers/download_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/gradient_background.dart';

class DownloadScreen extends ConsumerStatefulWidget {
  const DownloadScreen({super.key});

  @override
  ConsumerState<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends ConsumerState<DownloadScreen> {
  bool _navigated = false;
  ProviderSubscription<DownloadState>? _sub;

  @override
  void initState() {
    super.initState();

    ref.listenManual<DownloadState>(downloadProvider, (prev, next) {
      if (!_navigated && next.allFinished && next.totalCount > 0) {
        _navigated = true;

        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            Navigator.pushReplacementNamed(context, AppRoutes.summary);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dlState = ref.watch(downloadProvider);

    // Khi tất cả xong → chuyển sang Summary
    // ref.listen<DownloadState>(downloadProvider, (prev, next) {
    //   if (next.allFinished && next.totalCount > 0) {
    //     Future.delayed(const Duration(milliseconds: 800), () {
    //       if (context.mounted) {
    //         Navigator.pushReplacementNamed(context, AppRoutes.summary);
    //       }
    //     });
    //   }
    // });

    return GradientBackground(
      child: AppShell(
        appBar: AppBar(
          title: const Text('Đang tải'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            if (dlState.finishedTasks.isNotEmpty)
              TextButton(
                onPressed: () =>
                    ref.read(downloadProvider.notifier).clearFinished(),
                child: const Text(
                  'Xóa xong',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
        child: dlState.tasks.isEmpty
            ? const _EmptyState()
            : Column(
                children: [
                  // Stats header
                  _StatsHeader(state: dlState),

                  // Task list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      itemCount: dlState.tasks.length,
                      itemBuilder: (ctx, i) {
                        final task = dlState.tasks[i];
                        return _DownloadTaskCard(task: task);
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── Stats Header ───────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final DownloadState state;

  const _StatsHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _StatChip(
            label: 'Đang tải',
            count: state.activeTasks.length,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Xếp hàng',
            count: state.queuedTasks.length,
            color: const Color(0xFFFF9F0A),
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Xong',
            count: state.successCount,
            color: const Color(0xFF34C759),
          ),
          if (state.errorCount > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
              label: 'Lỗi',
              count: state.errorCount,
              color: const Color(0xFFFF3B30),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Task Card ──────────────────────────────────────────────

class _DownloadTaskCard extends ConsumerWidget {
  final DownloadTask task;

  const _DownloadTaskCard({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: thumbnail + title + status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              _TaskThumbnail(task: task),
              const SizedBox(width: 12),

              // Title + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
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
                    _StatusBadge(status: task.status),
                  ],
                ),
              ),
            ],
          ),

          // Progress area (chỉ khi đang download)
          if (task.status == DownloadStatus.downloading ||
              task.status == DownloadStatus.preparing) ...[
            const SizedBox(height: 12),
            _ProgressBar(progress: task.progress),
            const SizedBox(height: 6),
            _ProgressMeta(task: task),
          ],

          // Error message
          if (task.status == DownloadStatus.error &&
              task.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF3B30).withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFFF3B30),
                  fontSize: 12,
                ),
              ),
            ),
          ],

          // Done path
          if (task.status == DownloadStatus.done &&
              task.outputPath != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.folder_rounded,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.outputPath!,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Action buttons
          const SizedBox(height: 10),
          _ActionButtons(
            task: task,
            onCancel: () =>
                ref.read(downloadProvider.notifier).cancel(task.id),
            onRetry: () =>
                ref.read(downloadProvider.notifier).retry(task.id),
            onRemove: () =>
                ref.read(downloadProvider.notifier).remove(task.id),
          ),
        ],
      ),
    );
  }
}

// ── Task Thumbnail ─────────────────────────────────────────

class _TaskThumbnail extends StatelessWidget {
  final DownloadTask task;

  const _TaskThumbnail({required this.task});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: task.thumbnail != null
              ? CachedNetworkImage(
                  imageUrl: task.thumbnail!,
                  width: 64,
                  height: 42,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _placeholder(),
                )
              : _placeholder(),
        ),
        // Status overlay icon
        Positioned(
          bottom: 3,
          right: 3,
          child: _StatusIcon(status: task.status),
        ),
      ],
    );
  }

  Widget _placeholder() => Container(
        width: 64,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.movie_rounded,
            color: AppColors.textTertiary, size: 20),
      );
}

class _StatusIcon extends StatelessWidget {
  final DownloadStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (status) {
      case DownloadStatus.queued:
        icon = Icons.schedule_rounded;
        color = const Color(0xFFFF9F0A);
      case DownloadStatus.preparing:
      case DownloadStatus.downloading:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        );
      case DownloadStatus.done:
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF34C759);
      case DownloadStatus.error:
        icon = Icons.error_rounded;
        color = const Color(0xFFFF3B30);
      case DownloadStatus.cancelled:
        icon = Icons.cancel_rounded;
        color = AppColors.textTertiary;
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}

// ── Progress Bar ───────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double progress;

  const _ProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: AppColors.surfaceElevated,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
        minHeight: 5,
      ),
    );
  }
}

class _ProgressMeta extends StatelessWidget {
  final DownloadTask task;

  const _ProgressMeta({required this.task});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          task.progressPercent,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (task.speed.isNotEmpty) ...[
          Text(
            '  ·  ${task.speed}',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ],
        if (task.eta.isNotEmpty) ...[
          Text(
            '  ·  ETA ${task.eta}',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ],
        const Spacer(),
        Text(
          task.status.displayText,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Status Badge ───────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final DownloadStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case DownloadStatus.queued:
        color = const Color(0xFFFF9F0A);
      case DownloadStatus.preparing:
      case DownloadStatus.downloading:
        color = AppColors.primary;
      case DownloadStatus.done:
        color = const Color(0xFF34C759);
      case DownloadStatus.error:
        color = const Color(0xFFFF3B30);
      case DownloadStatus.cancelled:
        color = AppColors.textTertiary;
    }

    return Text(
      status.displayText,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

// ── Action Buttons ─────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final VoidCallback onRemove;

  const _ActionButtons({
    required this.task,
    required this.onCancel,
    required this.onRetry,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (task.canCancel)
          _TinyButton(
            label: 'Hủy',
            icon: Icons.close_rounded,
            color: const Color(0xFFFF3B30),
            onTap: onCancel,
          ),
        if (task.canRetry) ...[
          _TinyButton(
            label: 'Thử lại',
            icon: Icons.refresh_rounded,
            color: AppColors.primary,
            onTap: onRetry,
          ),
          const SizedBox(width: 6),
          _TinyButton(
            label: 'Xóa',
            icon: Icons.delete_outline_rounded,
            color: AppColors.textTertiary,
            onTap: onRemove,
          ),
        ],
        if (task.status == DownloadStatus.done)
          _TinyButton(
            label: 'Xóa',
            icon: Icons.delete_outline_rounded,
            color: AppColors.textTertiary,
            onTap: onRemove,
          ),
        if (task.status == DownloadStatus.cancelled)
          _TinyButton(
            label: 'Xóa',
            icon: Icons.delete_outline_rounded,
            color: AppColors.textTertiary,
            onTap: onRemove,
          ),
      ],
    );
  }
}

class _TinyButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TinyButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2), width: 0.6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_rounded,
            size: 56,
            color: AppColors.textTertiary.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có download nào',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Phân tích một link để bắt đầu',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
