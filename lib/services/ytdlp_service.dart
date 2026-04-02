// lib/services/ytdlp_service.dart

import 'dart:async';
import 'dart:convert';
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

class YtdlpService {
  YtdlpService._();
  static final YtdlpService instance = YtdlpService._();

  static const _channel = MethodChannel('ytdlp_channel');

  // ── Analyze ───────────────────────────────────────────────

  Future<AnalyzeResult> analyze(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return const AnalyzeFailure('URL không được để trống');
    if (!trimmed.startsWith('http')) return const AnalyzeFailure('URL không hợp lệ');

    try {
      final jsonStr = await _channel.invokeMethod<String>(
        'analyze',
        {'url': trimmed},
      ).timeout(const Duration(seconds: 30));

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

  Future<PlaylistEntriesResult> getPlaylistEntries(String url) async {
    try {
      final jsonStr = await _channel.invokeMethod<String>(
        'getPlaylistEntries',
        {'url': url},
      ).timeout(const Duration(seconds: 120));

      final data = json.decode(jsonStr!) as Map<String, dynamic>;

      if (data['success'] != true) {
        return PlaylistEntriesFailure(
          _parseError(data['error'] as String? ?? 'Lỗi không xác định'),
        );
      }

      final rawEntries = data['entries'] as List<dynamic>? ?? [];
      final entries = rawEntries
          .whereType<Map<String, dynamic>>()
          .map(PlaylistEntry.fromJson)
          .where((e) => e.isPlayable)
          .toList();

      return PlaylistEntriesSuccess(
        title:   data['title'] as String? ?? 'Playlist',
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

  // ── Download với real progress polling ───────────────────
  // Bug fix: key name changed từ 'outputPath' → 'outputDir' để match Kotlin
  // Bug fix 4: poll getProgress() thực sự thay vì chỉ dùng FakeProgress

  Stream<DownloadTask> download(
      DownloadTask task, {
        String? outputDir,
      }) {
    final controller = StreamController<DownloadTask>();
    final dir = outputDir ?? '/sdcard/Download/YTDLModule';

    // Biến mutable để track state hiện tại của task
    DownloadTask currentTask = task;
    Timer? progressTimer;

    void safeAdd(DownloadTask t) {
      currentTask = t;
      if (!controller.isClosed) controller.add(t);
    }

    // Bắt đầu: preparing
    safeAdd(task.copyWith(status: DownloadStatus.preparing));

    // Chuyển sang downloading
    safeAdd(currentTask.copyWith(
      status: DownloadStatus.downloading,
      startedAt: DateTime.now(),
      progress: 0.0,
    ));

    // Poll progress từ Python mỗi 600ms
    // Python's get_progress() trả về dict được cập nhật bởi yt-dlp hook
    // GIL được release khi yt-dlp thực hiện network I/O → safe to poll concurrently
    progressTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) async {
      if (controller.isClosed) {
        timer.cancel();
        return;
      }
      try {
        final jsonStr = await _channel.invokeMethod<String>('getProgress');
        if (jsonStr == null || controller.isClosed) return;

        final data   = json.decode(jsonStr) as Map<String, dynamic>;
        final status = data['status'] as String? ?? '';

        if (status != 'downloading') return;

        final percent = (data['percent'] as num?)?.toDouble() ?? 0.0;
        final speed   = (data['speed']   as String?) ?? '';
        final eta     = (data['eta']     as String?) ?? '';

        safeAdd(currentTask.copyWith(
          status:   DownloadStatus.downloading,
          progress: (percent / 100.0).clamp(0.0, 0.99),
          speed:    speed,
          eta:      eta,
        ));
      } catch (_) {
        // Bỏ qua lỗi poll — không critical
      }
    });

    // Gửi lệnh download (blocking đến khi hoàn thành)
    _channel.invokeMethod<String>('download', {
      'url':      task.url,
      'formatId': task.formatId,
      'outputDir': dir,  // Bug fix: 'outputPath' → 'outputDir'
    }).then((jsonStr) {
      progressTimer?.cancel();

      if (controller.isClosed) return;

      if (jsonStr == null) {
        safeAdd(currentTask.copyWith(
          status:       DownloadStatus.error,
          errorMessage: 'Không nhận được phản hồi',
        ));
        controller.close();
        return;
      }

      final data = json.decode(jsonStr) as Map<String, dynamic>;

      if (data['success'] == false || data.containsKey('error')) {
        safeAdd(currentTask.copyWith(
          status:       DownloadStatus.error,
          errorMessage: _parseError(data['error'] as String? ?? 'Download thất bại'),
        ));
      } else {
        // Lấy path từ response (single video: 'path', playlist: 'path' = outputDir)
        final outputPath = data['path'] as String?;
        safeAdd(currentTask.copyWith(
          status:      DownloadStatus.done,
          progress:    1.0,
          completedAt: DateTime.now(),
          outputPath:  outputPath,
          speed:       '',
          eta:         '',
        ));
      }
      controller.close();
    }).catchError((Object e) {
      progressTimer?.cancel();
      if (controller.isClosed) return;

      final msg = e is PlatformException
          ? _parseError(e.message ?? 'Platform error')
          : 'Lỗi: $e';

      safeAdd(currentTask.copyWith(
        status:       DownloadStatus.error,
        errorMessage: msg,
      ));
      controller.close();
    });

    return controller.stream;
  }

  // ── Extract audio (Phương án 2: Android native MediaExtractor) ──────────────
  // Copy audio track trực tiếp, không re-encode → nhanh, lossless
  // Kết quả: file .m4a cùng thư mục với input

  Future<ExtractAudioResult> extractAudioNative({
    required String inputPath,
  }) async {
    final outputPath = inputPath.replaceAll(RegExp(r'\.[^.]+$'), '.m4a');

    try {
      final success = await _channel.invokeMethod<bool>('extractAudio', {
        'inputPath':  inputPath,
        'outputPath': outputPath,
      });

      if (success == true) {
        return ExtractAudioResult(success: true, outputPath: outputPath);
      } else {
        return const ExtractAudioResult(
          success: false,
          error:   'MediaExtractor: không tìm thấy audio track',
        );
      }
    } on PlatformException catch (e) {
      return ExtractAudioResult(
        success: false,
        error:   'MediaExtractor lỗi: ${e.message}',
      );
    } catch (e) {
      return ExtractAudioResult(success: false, error: '$e');
    }
  }

  // ── Private ────────────────────────────────────────────────

  String _parseError(String err) {
    if (err.contains('Private video'))  return 'Video này là riêng tư';
    if (err.contains('Unsupported URL')) return 'URL không được hỗ trợ';
    if (err.contains('404'))            return 'Video không tồn tại';
    if (err.contains('Sign in'))        return 'Video yêu cầu đăng nhập';
    return err.length > 120 ? '${err.substring(0, 120)}...' : err;
  }
}