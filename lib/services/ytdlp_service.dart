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

// ── Service ────────────────────────────────────────────────

class YtdlpService {
  YtdlpService._();
  static final YtdlpService instance = YtdlpService._();

  static const _channel = MethodChannel('ytdlp_channel');

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

  Stream<DownloadTask> download(
      DownloadTask task, {
        String? outputDir,
      }) async* {
    final dir = outputDir ?? '/sdcard/Download/YTDLModule';

    yield task.copyWith(status: DownloadStatus.preparing);

    try {
      yield task.copyWith(
        status: DownloadStatus.downloading,
        startedAt: DateTime.now(),
        progress: 0.0,
      );

      final jsonStr = await _channel.invokeMethod<String>(
        'download',
        {
          'url': task.url,
          'formatId': task.formatId,
          'outputPath': dir,
        },
      );

      final data = json.decode(jsonStr!) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        yield task.copyWith(
          status: DownloadStatus.error,
          errorMessage: data['error'] as String,
        );
      } else {
        yield task.copyWith(
          status: DownloadStatus.done,
          progress: 1.0,
          completedAt: DateTime.now(),
        );
      }
    } on PlatformException catch (e) {
      yield task.copyWith(
        status: DownloadStatus.error,
        errorMessage: e.message ?? 'Lỗi download',
      );
    } catch (e) {
      yield task.copyWith(
        status: DownloadStatus.error,
        errorMessage: 'Lỗi: $e',
      );
    }
  }

  String _parseError(String err) {
    if (err.contains('Private video')) return 'Video này là riêng tư';
    if (err.contains('Unsupported URL')) return 'URL không được hỗ trợ';
    if (err.contains('404')) return 'Video không tồn tại';
    if (err.contains('Sign in')) return 'Video yêu cầu đăng nhập';
    return err.length > 100 ? '${err.substring(0, 100)}...' : err;
  }
}