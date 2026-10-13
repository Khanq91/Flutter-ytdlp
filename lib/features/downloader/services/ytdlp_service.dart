// lib/services/ytdlp_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/playlist_entry.dart';
import '../models/video_info.dart';
import '../models/download_task.dart';

// ── Sealed classes kết quả analyze ────────────────────────

sealed class AnalyzeResult {
  const AnalyzeResult();
}

class AnalyzeSuccess extends AnalyzeResult {
  final VideoInfo info;
  const AnalyzeSuccess(this.info);
}

class AnalyzeFailure extends AnalyzeResult {
  final String message;
  const AnalyzeFailure(this.message);
}

// ── Sealed classes kết quả getPlaylistEntries ──────────────

sealed class PlaylistEntriesResult {
  const PlaylistEntriesResult();
}

class PlaylistEntriesSuccess extends PlaylistEntriesResult {
  final String title;
  final List<PlaylistEntry> entries;
  const PlaylistEntriesSuccess({required this.title, required this.entries});
}

class PlaylistEntriesFailure extends PlaylistEntriesResult {
  final String message;
  const PlaylistEntriesFailure(this.message);
}

// ── Kết quả extractAudio ────────────────────────────────────

class ExtractAudioResult {
  final bool success;
  final String? outputPath;
  final String? error;

  const ExtractAudioResult({
    required this.success,
    this.outputPath,
    this.error,
  });
}

// ── Service ────────────────────────────────────────────────

abstract interface class DownloadGateway {
  Stream<DownloadTask> download(DownloadTask task, {String? outputDir});

  Future<bool> cancel(String taskId);

  Future<ExtractAudioResult> extractAudioNative({required String inputPath});
}

abstract interface class RestorableDownloadGateway {
  Future<List<DownloadTask>> restoreDownloads();
}

abstract interface class PersistentDownloadHistoryGateway {
  Future<void> removeFinishedDownload(String taskId);

  Future<void> clearFinishedDownloads();
}

abstract interface class AnalyzeGateway {
  Future<AnalyzeResult> analyze(String url);
}

abstract interface class PlaylistGateway {
  Future<PlaylistEntriesResult> getPlaylistEntries(String url);
}

class YtdlpService
    implements
        AnalyzeGateway,
        PlaylistGateway,
        DownloadGateway,
        RestorableDownloadGateway,
        PersistentDownloadHistoryGateway {
  YtdlpService._();
  static final YtdlpService instance = YtdlpService._();

  static const _channel = MethodChannel('ytdlp_channel');

  // ── Analyze ───────────────────────────────────────────────

  @override
  Future<AnalyzeResult> analyze(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return const AnalyzeFailure('URL không được để trống');
    if (!trimmed.startsWith('http')) {
      return const AnalyzeFailure('URL không hợp lệ');
    }

    try {
      final jsonStr = await _channel
          .invokeMethod<String>('analyze', {'url': trimmed})
          .timeout(const Duration(seconds: 30));

      final data = json.decode(jsonStr!) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        return AnalyzeFailure(_parseError(data['error'] as String));
      }

      return AnalyzeSuccess(VideoInfo.fromYtDlpJson(data, trimmed));
    } on PlatformException catch (e) {
      return AnalyzeFailure(_parseError(e.message ?? 'Lỗi không xác định'));
    } on TimeoutException {
      return const AnalyzeFailure('Phân tích quá thời gian');
    } catch (e) {
      return AnalyzeFailure('Lỗi: $e');
    }
  }

  // ── Playlist entries ──────────────────────────────────────

  @override
  Future<PlaylistEntriesResult> getPlaylistEntries(String url) async {
    try {
      final jsonStr = await _channel
          .invokeMethod<String>('getPlaylistEntries', {'url': url})
          .timeout(const Duration(seconds: 120));

      final data = json.decode(jsonStr!) as Map<String, dynamic>;

      if (data['success'] != true) {
        return PlaylistEntriesFailure(
          _parseError(data['error'] as String? ?? 'Lỗi không xác định'),
        );
      }

      final rawEntries = data['entries'] as List<dynamic>? ?? [];
      final entries =
          rawEntries
              .whereType<Map<String, dynamic>>()
              .map(PlaylistEntry.fromJson)
              .where((e) => e.isPlayable)
              .toList();

      return PlaylistEntriesSuccess(
        title: data['title'] as String? ?? 'Playlist',
        entries: entries,
      );
    } on PlatformException catch (e) {
      return PlaylistEntriesFailure(e.message ?? 'Lỗi không xác định');
    } on TimeoutException {
      return const PlaylistEntriesFailure('Quá thời gian chờ');
    } catch (e) {
      return PlaylistEntriesFailure('Lỗi: $e');
    }
  }

  // ── Foreground download với task-scoped polling ──────────

  @override
  Stream<DownloadTask> download(DownloadTask task, {String? outputDir}) {
    late final StreamController<DownloadTask> controller;
    final dir = outputDir ?? '/sdcard/Download/YTDLModule';
    DownloadTask currentTask = task;
    var stoppedPolling = false;

    void safeAdd(DownloadTask t) {
      currentTask = t;
      if (!controller.isClosed) controller.add(t);
    }

    Future<void> run() async {
      try {
        final acceptedJson = await _channel
            .invokeMethod<String>('enqueueDownload', {
              'taskId': task.id,
              'title': task.title,
              'url': task.url,
              'formatId': task.formatId,
              'ext': task.ext,
              'thumbnail': task.thumbnail,
              'outputDir': dir,
            });
        final accepted =
            acceptedJson == null
                ? false
                : (json.decode(acceptedJson)
                        as Map<String, dynamic>)['accepted'] ==
                    true;
        if (!accepted) throw StateError('Foreground service rejected task');

        safeAdd(task.copyWith(status: DownloadStatus.queued));

        while (!stoppedPolling && !controller.isClosed) {
          final snapshotJson = await _channel.invokeMethod<String>(
            'getDownloadTask',
            {'taskId': task.id},
          );
          if (snapshotJson != null) {
            final snapshot = json.decode(snapshotJson) as Map<String, dynamic>;
            var updated = _taskFromNative(snapshot, fallback: currentTask);

            if (updated.status == DownloadStatus.downloading) {
              updated = await _withLiveProgress(updated);
            }
            safeAdd(updated);

            if (updated.status.isFinished) {
              await controller.close();
              return;
            }
          }
          await Future<void>.delayed(const Duration(milliseconds: 600));
        }
      } catch (error) {
        if (controller.isClosed || stoppedPolling) return;
        final message =
            error is PlatformException
                ? _parseError(error.message ?? 'Platform error')
                : 'Lỗi: $error';
        safeAdd(
          currentTask.copyWith(
            status: DownloadStatus.error,
            errorMessage: message,
          ),
        );
        await controller.close();
      }
    }

    controller = StreamController<DownloadTask>(
      onListen: () => unawaited(run()),
      onCancel: () {
        // Detaching Flutter must not cancel a foreground download.
        stoppedPolling = true;
      },
    );

    return controller.stream;
  }

  @override
  Future<List<DownloadTask>> restoreDownloads() async {
    try {
      final raw = await _channel.invokeMethod<String>('getDownloadTasks');
      if (raw == null) return const [];
      final data = json.decode(raw) as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map((item) => _taskFromNative(item))
          .toList();
    } catch (e, st) {
      debugPrint('[YtdlpService] restoreDownloads failed: $e\n$st');
      return const [];
    }
  }

  @override
  Future<void> removeFinishedDownload(String taskId) =>
      _channel.invokeMethod('removeFinishedDownload', {'taskId': taskId});

  @override
  Future<void> clearFinishedDownloads() =>
      _channel.invokeMethod('clearFinishedDownloads');

  Future<DownloadTask> _withLiveProgress(DownloadTask task) async {
    try {
      final raw = await _channel.invokeMethod<String>('getProgress', {
        'taskId': task.id,
      });
      if (raw == null) return task;
      final progress = json.decode(raw) as Map<String, dynamic>;
      if (progress['status'] != 'downloading') return task;
      final percent = (progress['percent'] as num?)?.toDouble() ?? 0;
      return task.copyWith(
        progress: (percent / 100).clamp(0, 0.99).toDouble(),
        speed: progress['speed'] as String? ?? '',
        eta: progress['eta'] as String? ?? '',
      );
    } catch (e) {
      debugPrint('[YtdlpService] getProgress(${task.id}) failed: $e');
      return task;
    }
  }

  DownloadTask _taskFromNative(
    Map<String, dynamic> data, {
    DownloadTask? fallback,
  }) {
    final statusName = data['status'] as String? ?? 'queued';
    final status = DownloadStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => DownloadStatus.error,
    );
    DateTime? time(String key) {
      final milliseconds = (data[key] as num?)?.toInt();
      return milliseconds == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }

    return DownloadTask(
      id: data['id'] as String? ?? fallback?.id ?? '',
      title: data['title'] as String? ?? fallback?.title ?? '',
      url: data['url'] as String? ?? fallback?.url ?? '',
      formatId: data['formatId'] as String? ?? fallback?.formatId ?? '',
      ext: data['ext'] as String? ?? fallback?.ext ?? '',
      thumbnail: data['thumbnail'] as String? ?? fallback?.thumbnail,
      progress:
          (data['progress'] as num?)?.toDouble() ?? fallback?.progress ?? 0,
      status: status,
      speed: data['speed'] as String? ?? fallback?.speed ?? '',
      eta: data['eta'] as String? ?? fallback?.eta ?? '',
      errorMessage: data['errorMessage'] as String?,
      outputPath: data['outputPath'] as String?,
      startedAt: time('startedAt') ?? fallback?.startedAt,
      completedAt: time('completedAt') ?? fallback?.completedAt,
    );
  }

  @override
  Future<bool> cancel(String taskId) async {
    try {
      final jsonStr = await _channel
          .invokeMethod<String>('cancelDownload', {'taskId': taskId})
          .timeout(const Duration(seconds: 20));
      if (jsonStr == null) return false;

      final data = json.decode(jsonStr) as Map<String, dynamic>;
      return data['accepted'] == true && data['stopped'] == true;
    } catch (e, st) {
      debugPrint('[YtdlpService] cancelDownload($taskId) failed: $e\n$st');
      return false;
    }
  }

  // ── Extract audio (Phương án 2: Android native MediaExtractor) ──────────────
  // Copy audio track trực tiếp, không re-encode → nhanh, lossless
  // Kết quả: file .m4a cùng thư mục với input

  @override
  Future<ExtractAudioResult> extractAudioNative({
    required String inputPath,
  }) async {
    final outputPath = inputPath.replaceAll(RegExp(r'\.[^.]+$'), '.m4a');

    try {
      final success = await _channel.invokeMethod<bool>('extractAudio', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });

      if (success == true) {
        return ExtractAudioResult(success: true, outputPath: outputPath);
      } else {
        return const ExtractAudioResult(
          success: false,
          error: 'MediaExtractor: không tìm thấy audio track',
        );
      }
    } on PlatformException catch (e) {
      return ExtractAudioResult(
        success: false,
        error: 'MediaExtractor lỗi: ${e.message}',
      );
    } catch (e) {
      return ExtractAudioResult(success: false, error: '$e');
    }
  }

  // ── Private ────────────────────────────────────────────────

  String _parseError(String err) {
    if (err.contains('Private video')) return 'Video này là riêng tư';
    if (err.contains('Unsupported URL')) return 'URL không được hỗ trợ';
    if (err.contains('404')) return 'Video không tồn tại';
    if (err.contains('Sign in')) return 'Video yêu cầu đăng nhập';
    return err.length > 120 ? '${err.substring(0, 120)}...' : err;
  }
}
