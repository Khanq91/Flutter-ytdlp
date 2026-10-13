// lib/screens/download/download_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_ytdlp/widgets/reveal_list/reveal_list.dart';

import '../../core/app_router.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';
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
  Widget build(BuildContext context) {
    final c = context.appColors;
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
                onPressed:
                    () => ref.read(downloadProvider.notifier).clearFinished(),
                child: Text(
                  'Xóa xong',
                  style: TextStyle(color: c.textTertiary, fontSize: 13),
                ),
              ),
          ],
        ),
        child:
            dlState.tasks.isEmpty
                ? const _EmptyState()
                : Column(
                  children: [
                    // Stats header
                    _StatsHeader(state: dlState),

                    // Task list
                    Expanded(
                      child: RevealList(
                        itemSpacing: 0,
                        showEdgeFades: false,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: dlState.tasks.length,
                        itemKeyBuilder: (i) => ValueKey(dlState.tasks[i].id),
                        itemBuilder: (ctx, i, __) {
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
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _StatChip(
            label: 'Đang tải',
            count: state.activeTasks.length,
            color: c.primary,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Xếp hàng',
            count: state.queuedTasks.length,
            color: c.warning,
          ),
          const SizedBox(width: 8),
          _StatChip(
            label: 'Xong',
            count: state.successCount,
            color: c.success,
          ),
          if (state.errorCount > 0) ...[
            const SizedBox(width: 8),
            _StatChip(
              label: 'Lỗi',
              count: state.errorCount,
              color: c.error,
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
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
            style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12),
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
    final c = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.6),
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
                      style: TextStyle(
                        color: c.textPrimary,
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
          if ((task.status == DownloadStatus.error ||
                  task.status == DownloadStatus.waitingToRetry) &&
              task.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (task.status == DownloadStatus.error
                        ? c.error
                        : c.warning)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task.errorMessage!,
                style: TextStyle(
                  color:
                      task.status == DownloadStatus.error
                          ? c.error
                          : c.warning,
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
                Icon(
                  Icons.folder_rounded,
                  size: 13,
                  color: c.textTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    task.outputPath!,
                    style: TextStyle(
                      color: c.textTertiary,
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
            onCancel: () => ref.read(downloadProvider.notifier).cancel(task.id),
            onRetry: () => ref.read(downloadProvider.notifier).retry(task.id),
            onRemove: () => ref.read(downloadProvider.notifier).remove(task.id),
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
    final c = context.appColors;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child:
              task.thumbnail != null
                  ? CachedNetworkImage(
                    imageUrl: task.thumbnail!,
                    width: 64,
                    height: 42,
                    // Decode to a bounded width (aspect kept) instead of the
                    // full 1280x720 frame for a 64x42 cell; 256px still covers
                    // the cell at dpr 3.5 without upscaling.
                    memCacheWidth: 256,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _placeholder(c),
                  )
                  : _placeholder(c),
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

  Widget _placeholder(AppColorsData c) => Container(
    width: 64,
    height: 42,
    decoration: BoxDecoration(
      color: c.surfaceElevated,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      Icons.movie_rounded,
      color: c.textTertiary,
      size: 20,
    ),
  );
}

class _StatusIcon extends StatelessWidget {
  final DownloadStatus status;

  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    IconData icon;
    Color color;

    switch (status) {
      case DownloadStatus.queued:
        icon = Icons.schedule_rounded;
        color = c.warning;
      case DownloadStatus.waitingToRetry:
        icon = Icons.wifi_off_rounded;
        color = c.warning;
      case DownloadStatus.preparing:
      case DownloadStatus.downloading:
        return SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: c.primary,
          ),
        );
      case DownloadStatus.done:
        icon = Icons.check_circle_rounded;
        color = c.success;
      case DownloadStatus.error:
        icon = Icons.error_rounded;
        color = c.error;
      case DownloadStatus.cancelled:
        icon = Icons.cancel_rounded;
        color = c.textTertiary;
    }

    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: c.card,
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
    final c = context.appColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: c.surfaceElevated,
        valueColor: AlwaysStoppedAnimation<Color>(c.primary),
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
    final c = context.appColors;
    return Row(
      children: [
        Text(
          task.progressPercent,
          style: TextStyle(
            color: c.primary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (task.speed.isNotEmpty) ...[
          Text(
            '  ·  ${task.speed}',
            style: TextStyle(color: c.textTertiary, fontSize: 12),
          ),
        ],
        if (task.eta.isNotEmpty) ...[
          Text(
            '  ·  ETA ${task.eta}',
            style: TextStyle(color: c.textTertiary, fontSize: 12),
          ),
        ],
        const Spacer(),
        Text(
          task.status.displayText,
          style: TextStyle(color: c.textTertiary, fontSize: 11),
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
    final c = context.appColors;
    Color color;
    switch (status) {
      case DownloadStatus.queued:
      case DownloadStatus.waitingToRetry:
        color = c.warning;
      case DownloadStatus.preparing:
      case DownloadStatus.downloading:
        color = c.primary;
      case DownloadStatus.done:
        color = c.success;
      case DownloadStatus.error:
        color = c.error;
      case DownloadStatus.cancelled:
        color = c.textTertiary;
    }

    return Text(
      status.displayText,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
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
    final c = context.appColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (task.canCancel)
          _TinyButton(
            label: 'Hủy',
            icon: Icons.close_rounded,
            color: c.error,
            onTap: onCancel,
          ),
        if (task.canRetry) ...[
          _TinyButton(
            label: 'Thử lại',
            icon: Icons.refresh_rounded,
            color: c.primary,
            onTap: onRetry,
          ),
          const SizedBox(width: 6),
          _TinyButton(
            label: 'Xóa',
            icon: Icons.delete_outline_rounded,
            color: c.textTertiary,
            onTap: onRemove,
          ),
        ],
        if (task.status == DownloadStatus.done)
          _TinyButton(
            label: 'Xóa',
            icon: Icons.delete_outline_rounded,
            color: c.textTertiary,
            onTap: onRemove,
          ),
        if (task.status == DownloadStatus.cancelled)
          _TinyButton(
            label: 'Xóa',
            icon: Icons.delete_outline_rounded,
            color: c.textTertiary,
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
    // Keep the compact pill look but give it a >=44dp hit area.
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.2), width: 0.6),
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
            ),
          ),
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
    final c = context.appColors;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_rounded,
            size: 56,
            color: c.textTertiary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có download nào',
            style: TextStyle(color: c.textTertiary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Phân tích một link để bắt đầu',
            style: TextStyle(color: c.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
