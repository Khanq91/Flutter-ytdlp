// lib/providers/download_provider.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';
import '../models/download_task.dart';
import '../models/format_option.dart';
import '../models/video_info.dart';
import '../services/storage_service.dart';
import '../services/ytdlp_service.dart';
import '../utils/fake_progress.dart';

// ── State ──────────────────────────────────────────────────

class DownloadState {
  final List<DownloadTask> tasks;

  const DownloadState({this.tasks = const []});

  /// Đang chạy (downloading hoặc preparing)
  List<DownloadTask> get activeTasks =>
      tasks.where((t) => t.status.isActive).toList();

  /// Đang xếp hàng chờ
  List<DownloadTask> get queuedTasks =>
      tasks.where((t) => t.status == DownloadStatus.queued).toList();

  /// Đã xong (done, error, cancelled)
  List<DownloadTask> get finishedTasks =>
      tasks.where((t) => t.status.isFinished).toList();

  int get successCount =>
      tasks.where((t) => t.status == DownloadStatus.done).length;

  int get errorCount =>
      tasks.where((t) => t.status == DownloadStatus.error).length;

  int get totalCount => tasks.length;

  /// True khi không còn task nào active/queued
  bool get allFinished =>
      tasks.isNotEmpty &&
      tasks.every((t) => t.status.isFinished);

  DownloadState copyWith({List<DownloadTask>? tasks}) =>
      DownloadState(tasks: tasks ?? this.tasks);
}

// ── Notifier ───────────────────────────────────────────────

class DownloadNotifier extends Notifier<DownloadState> {
  final _uuid = const Uuid();

  /// Map taskId → StreamSubscription (để cancel)
  final Map<String, StreamSubscription<DownloadTask>> _subs = {};
  final Map<String, FakeProgress> _fakeMap = {};

  @override
  DownloadState build() {
    ref.onDispose(() {
      for (final sub in _subs.values) {
        sub.cancel();
      }
      _subs.clear();
    });

    return const DownloadState();
  }

  // ── Public API ─────────────────────────────────────────

  /// Thêm một video đơn vào hàng đợi
  Future<void> enqueue({
    required VideoInfo info,
    required FormatOption format,
  }) async {
    final task = DownloadTask(
      id: _uuid.v4(),
      title: info.title,
      url: info.url,
      formatId: format.formatId,
      ext: format.ext,
      thumbnail: info.thumbnail,
      status: DownloadStatus.queued,
    );

    _addTask(task);
    _processQueue();
  }

  /// Thêm toàn bộ playlist vào hàng đợi
  Future<void> enqueuePlaylist({
    required VideoInfo playlistInfo,
    required FormatOption format,
  }) async {
    // Lấy danh sách URL entries từ libytdlp.so
    // (playlistInfo.url đã là playlist URL)
    // Tạo 1 task tổng cho playlist — mỗi item sẽ thành 1 task riêng
    // Ta dùng libytdlp.so tải playlist trực tiếp, nó tự xử lý từng video

    final task = DownloadTask(
      id: _uuid.v4(),
      title: '${playlistInfo.title} (${playlistInfo.playlistCount ?? "?"} video)',
      url: playlistInfo.url,
      formatId: format.formatId,
      ext: format.ext,
      thumbnail: playlistInfo.thumbnail,
      status: DownloadStatus.queued,
    );

    _addTask(task);
    _processQueue();
  }

  /// Hủy một task đang chạy hoặc đang xếp hàng
  void cancel(String taskId) {
    final task = _findTask(taskId);
    if (task == null || !task.canCancel) return;
    //Hủy FAKE PROCESS
    _fakeMap[taskId]?.dispose();
    _fakeMap.remove(taskId);

    // Kill process nếu đang chạy
    task.process?.kill(ProcessSignal.sigterm);

    // Hủy subscription
    _subs[taskId]?.cancel();
    _subs.remove(taskId);

    _updateTask(taskId, (t) => t.copyWith(status: DownloadStatus.cancelled));

    // Xử lý queue tiếp
    _processQueue();
  }

  /// Retry task lỗi
  Future<void> retry(String taskId) async {
    final task = _findTask(taskId);
    if (task == null || !task.canRetry) return;

    _updateTask(
      taskId,
      (t) => t.copyWith(
        status: DownloadStatus.queued,
        progress: 0,
        speed: '',
        eta: '',
        errorMessage: null,
      ),
    );

    _processQueue();
  }

  /// Xóa task khỏi danh sách (chỉ khi đã finished)
  void remove(String taskId) {
    final current = state.tasks.toList();
    current.removeWhere((t) => t.id == taskId && t.status.isFinished);
    state = state.copyWith(tasks: current);
  }

  /// Xóa tất cả task đã xong
  void clearFinished() {
    final current = state.tasks
        .where((t) => !t.status.isFinished)
        .toList();
    state = state.copyWith(tasks: current);
  }

  // ── Queue management ───────────────────────────────────

  void _processQueue() {
    final activeCount = state.activeTasks.length;
    final available = AppConstants.maxConcurrentDownloads - activeCount;
    if (available <= 0) return;

    final queued = state.queuedTasks.take(available).toList();
    for (final task in queued) {
      _startDownload(task);
    }
  }

  void _startDownload(DownloadTask task) {
    // START: FAKE PROCESS ---------------------------------------------
    final fake = FakeProgress();

    // fake.start((progress) {
    //   _updateTask(task.id, (t) => t.copyWith(progress: progress));
    // });
    fake.start((progress) {
      if (!_subs.containsKey(task.id)) return;

      _updateTask(task.id, (t) => t.copyWith(progress: progress));
    });

    _fakeMap[task.id] = fake;
    // END: FAKE PROCESS  ---------------------------------------------

    final stream = YtdlpService.instance.download(
      task,
      outputDir: StorageService.instance.downloadPath,
    );

    final sub = stream.listen(
      (updatedTask) async {
        _replaceTask(updatedTask);

        // Khi task xong → xử lý queue tiếp (TASK PROCESS RIEAL
        // if (updatedTask.status.isFinished) {
        //   _subs.remove(task.id);
        //   _processQueue();
        // }

        if (updatedTask.status == DownloadStatus.done) {
          // ✅ Kiểm tra có cần extract audio không
          if (_needsExtract(updatedTask) && updatedTask.outputPath != null) {
            // Hiện fake progress trong lúc extract
            _updateTask(task.id, (t) => t.copyWith(
              status: DownloadStatus.preparing,
              speed: 'Đang tách audio...',
              progress: 0.95,
            ));
            await _extractAudio(updatedTask);
          } else {
            _fakeMap[task.id]?.complete((p) {
              if (!_subs.containsKey(task.id)) return;
              _updateTask(task.id, (t) => t.copyWith(progress: p));
            });
            _fakeMap.remove(task.id);
          }
          _subs.remove(task.id);
          _processQueue();
        } else if (updatedTask.status.isFinished) {
          _fakeMap[task.id]?.dispose();
          _fakeMap.remove(task.id);
          _subs.remove(task.id);
          _processQueue();
        }
        // // TASK PROCESS FAKE
        // if (updatedTask.status.isFinished) {
        //   // Future.delayed(const Duration(milliseconds: 100), () {
        //   //   _fakeMap[task.id]?.complete((progress) {
        //   //     _updateTask(task.id, (t) => t.copyWith(progress: progress));
        //   //   });
        //   _fakeMap[task.id]?.complete((progress) {
        //     if (!_subs.containsKey(task.id)) return;
        //
        //     _updateTask(task.id, (t) => t.copyWith(progress: progress));
        //   });
        //
        //     _fakeMap.remove(task.id);
        //   // });
        //
        //   _subs.remove(task.id);
        //   _processQueue();
        // }
      },
      onError: (_) {
        // START: FAKE PROCESS ---------------------------------------------
        _fakeMap[task.id]?.dispose();
        _fakeMap.remove(task.id);
        // END: FAKE PROCESS ---------------------------------------------


        _updateTask(
          task.id,
          (t) => t.copyWith(
            status: DownloadStatus.error,
            errorMessage: 'Stream error',
          ),
        );
        _subs.remove(task.id);
        _processQueue();
      },
    );

    _subs[task.id] = sub;
  }

  bool _needsExtract(DownloadTask task) =>
      task.formatId == '__extract_audio__' ||
          task.formatId == '__extract_m4a__'   ||
          task.formatId == '__extract_mp3__';

  // Future<void> _extractAudio(DownloadTask task) async {
  //   final result = await YtdlpService.instance.extractAudioNative(
  //     inputPath: task.outputPath!,
  //   );
  //
  //   _updateTask(task.id, (t) => t.copyWith(
  //     status:      result.success ? DownloadStatus.done : DownloadStatus.error,
  //     outputPath:  result.outputPath ?? t.outputPath,
  //     errorMessage: result.error,
  //     speed:       '',
  //     progress:    result.success ? 1.0 : t.progress,
  //     completedAt: result.success ? DateTime.now() : null,
  //   ));
  // }

  Future<void> _extractAudio(DownloadTask task) async {
    _updateTask(task.id, (t) => t.copyWith(
      status:   DownloadStatus.preparing,
      speed:    'Đang tách audio...',
      progress: 0.95,
    ));

    final result = await YtdlpService.instance.extractAudioNative(
      inputPath: task.outputPath!,
    );

    if (result.success) {
      // ✅ Xóa file video gốc sau khi extract xong
      try {
        final original = File(task.outputPath!);
        if (await original.exists()) await original.delete();
      } catch (_) {
        // Không crash nếu xóa thất bại
      }
    }

    _updateTask(task.id, (t) => t.copyWith(
      status:       result.success ? DownloadStatus.done : DownloadStatus.error,
      outputPath:   result.outputPath ?? t.outputPath,
      errorMessage: result.error,
      speed:        '',
      progress:     result.success ? 1.0 : t.progress,
      completedAt:  result.success ? DateTime.now() : null,
    ));
  }

  // Trong _startDownload(), sau khi stream báo done
  // void _startDownload(DownloadTask task) {
  //   final stream = YtdlpService.instance.download(
  //     task,
  //     outputDir: StorageService.instance.downloadPath,
  //   );
  //
  //   final sub = stream.listen(
  //         (updatedTask) async {
  //       _replaceTask(updatedTask);
  //
  //       if (updatedTask.status == DownloadStatus.done) {
  //         // ✅ Kiểm tra có cần extract audio không
  //         if (_needsExtract(updatedTask) && updatedTask.outputPath != null) {
  //           await _extractAudio(updatedTask);
  //         }
  //         _subs.remove(task.id);
  //         _processQueue();
  //       } else if (updatedTask.status.isFinished) {
  //         _subs.remove(task.id);
  //         _processQueue();
  //       }
  //     },
  //     onError: (_) {
  //       _updateTask(task.id, (t) => t.copyWith(
  //         status: DownloadStatus.error,
  //         errorMessage: 'Stream error',
  //       ));
  //       _subs.remove(task.id);
  //       _processQueue();
  //     },
  //   );
  //
  //   _subs[task.id] = sub;
  // }
  //
  // bool _needsExtract(DownloadTask task) =>
  //     task.formatId == '__extract_m4a__' ||
  //         task.formatId == '__extract_mp3__';
  //
  // Future<void> _extractAudio(DownloadTask task) async {
  //   // Hiện trạng thái "Đang xử lý audio"
  //   _updateTask(task.id, (t) => t.copyWith(
  //     status: DownloadStatus.preparing,
  //     speed: 'Đang tách audio...',
  //   ));
  //
  //   final result = task.formatId == '__extract_mp3__'
  //       ? await AudioExtractService.instance.extractMp3(
  //     inputPath: task.outputPath!,
  //   )
  //       : await AudioExtractService.instance.extractAudio(
  //     inputPath: task.outputPath!,
  //     outputExt: 'm4a',
  //   );
  //
  //   _updateTask(task.id, (t) => t.copyWith(
  //     status: result.success ? DownloadStatus.done : DownloadStatus.error,
  //     outputPath: result.outputPath ?? t.outputPath,
  //     errorMessage: result.error,
  //     speed: '',
  //     completedAt: DateTime.now(),
  //   ));
  // }


  // ── Task CRUD helpers ──────────────────────────────────

  void _addTask(DownloadTask task) {
    state = state.copyWith(tasks: [...state.tasks, task]);
  }

  void _replaceTask(DownloadTask updated) {
    final tasks = state.tasks.map((t) {
      return t.id == updated.id ? updated : t;
    }).toList();
    state = state.copyWith(tasks: tasks);
  }

  void _updateTask(String id, DownloadTask Function(DownloadTask) updater) {
    final tasks = state.tasks.map((t) {
      return t.id == id ? updater(t) : t;
    }).toList();
    state = state.copyWith(tasks: tasks);
  }

  DownloadTask? _findTask(String id) {
    try {
      return state.tasks.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

}

// ── Providers ──────────────────────────────────────────────

final downloadProvider =
    NotifierProvider<DownloadNotifier, DownloadState>(DownloadNotifier.new);

/// Shorthand: lấy 1 task theo id (dùng trong item widget)
final downloadTaskProvider = Provider.family<DownloadTask?, String>((ref, id) {
  return ref.watch(downloadProvider).tasks.cast<DownloadTask?>().firstWhere(
    (t) => t?.id == id,
    orElse: () => null,
  );
});

/// Đếm task đang active (dùng cho badge trên Download tab)
final activeDownloadCountProvider = Provider<int>((ref) {
  return ref.watch(downloadProvider).activeTasks.length;
});
