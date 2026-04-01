// lib/services/ytdlp_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/download_task.dart';
import '../models/video_info.dart';
import 'storage_service.dart';

/// Kết quả phân tích URL
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

// ── Lỗi cụ thể ─────────────────────────────────────────────

class YtdlpException implements Exception {
  final String message;
  const YtdlpException(this.message);
  @override
  String toString() => 'YtdlpException: $message';
}

/// Core service: bọc toàn bộ tương tác với libytdlp.so binary
class YtdlpService {
  YtdlpService._();
  static final YtdlpService instance = YtdlpService._();

  String get _bin => StorageService.instance.ytdlpPath;

  // ── Analyze URL ────────────────────────────────────────

  /// Phân tích URL, trả về [VideoInfo] hoặc thông báo lỗi.
  /// Dùng `--dump-json` để lấy metadata không cần tải.
  Future<AnalyzeResult> analyze(String url) async {
    // Validate URL cơ bản
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return const AnalyzeFailure('URL không được để trống');
    }
    if (!trimmed.startsWith('http')) {
      return const AnalyzeFailure('URL không hợp lệ');
    }

    try {
      final result = await Process.run(
        _bin,
        [
          '--dump-json',
          '--no-playlist',   // Mặc định chỉ lấy video đơn
          '--flat-playlist', // Nếu là playlist: lấy danh sách nhanh
          '--no-warnings',
          trimmed,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw const YtdlpException(
          'Phân tích quá thời gian. Kiểm tra kết nối mạng.',
        ),
      );

      if (result.exitCode != 0) {
        final errMsg = _parseError(result.stderr.toString());
        return AnalyzeFailure(errMsg);
      }

      final stdout = result.stdout.toString().trim();
      if (stdout.isEmpty) {
        return const AnalyzeFailure('Không nhận được dữ liệu từ libytdlp.so');
      }

      // libytdlp.so có thể trả về nhiều dòng JSON (playlist)
      final lines = stdout.split('\n').where((l) => l.trim().isNotEmpty);
      final firstJson = json.decode(lines.first) as Map<String, dynamic>;

      // Nếu là playlist, lấy thêm info đầy đủ
      final type = firstJson['_type'] as String?;
      if (type == 'playlist') {
        return await _analyzePlaylist(trimmed, firstJson);
      }

      final info = VideoInfo.fromYtDlpJson(firstJson, trimmed);
      return AnalyzeSuccess(info);
    } on YtdlpException catch (e) {
      return AnalyzeFailure(e.message);
    } on FormatException {
      return const AnalyzeFailure('Không thể đọc dữ liệu từ libytdlp.so');
    } catch (e) {
      return AnalyzeFailure('Lỗi không xác định: $e');
    }
  }

  /// Analyze playlist: lấy full info kèm formats
  Future<AnalyzeResult> _analyzePlaylist(
    String url,
    Map<String, dynamic> flatJson,
  ) async {
    try {
      final result = await Process.run(
        _bin,
        [
          '--dump-json',
          '--yes-playlist',
          '--no-warnings',
          '--playlist-items', '1', // Lấy item đầu để có formats
          url,
        ],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(seconds: 30));

      String stdout = result.stdout.toString().trim();
      Map<String, dynamic> fullJson;

      if (stdout.isNotEmpty) {
        fullJson = json.decode(stdout.split('\n').first) as Map<String, dynamic>;
      } else {
        fullJson = flatJson;
      }

      // Merge playlist_count từ flatJson
      fullJson['_type'] = 'playlist';
      fullJson['playlist_count'] =
          flatJson['playlist_count'] ?? flatJson['entries']?.length;
      fullJson['title'] = flatJson['title'] ?? fullJson['title'];

      return AnalyzeSuccess(VideoInfo.fromYtDlpJson(fullJson, url));
    } catch (_) {
      // Fallback: dùng flat json, thiếu formats nhưng vẫn có metadata
      return AnalyzeSuccess(VideoInfo.fromYtDlpJson(flatJson, url));
    }
  }

  // ── Download ───────────────────────────────────────────

  /// Bắt đầu tải một task.
  /// Trả về Stream<DownloadTask> để UI lắng nghe tiến trình realtime.
  ///
  /// [outputDir] nếu null sẽ dùng [StorageService.instance.downloadPath]
  Stream<DownloadTask> download(
    DownloadTask task, {
    String? outputDir,
  }) async* {
    final dir = outputDir ?? StorageService.instance.downloadPath;
    final outTemplate = '$dir/%(title)s.%(ext)s';

    yield task.copyWith(status: DownloadStatus.preparing);

    Process? process;

    try {
      // Build command
      final args = _buildDownloadArgs(task, outTemplate);

      process = await Process.start(_bin, args);

      // Cập nhật process vào task để có thể cancel
      var current = task.copyWith(
        status: DownloadStatus.downloading,
        startedAt: DateTime.now(),
        process: process,
      );
      yield current;

      // Lắng nghe stdout realtime
      final stdoutStream = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      final stderrBuffer = StringBuffer();
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => stderrBuffer.writeln(line));

      await for (final line in stdoutStream) {
        final updated = current.applyLogLine(line);
        if (updated != null) {
          current = updated.copyWith(process: process);
          yield current;

          if (current.status == DownloadStatus.done) break;
          if (current.status == DownloadStatus.error) break;
        }
      }

      // Chờ process kết thúc
      final exitCode = await process.exitCode;

      if (exitCode == 0 && current.status != DownloadStatus.error) {
        yield current.copyWith(
          status: DownloadStatus.done,
          progress: 1.0,
          speed: '',
          eta: '',
          completedAt: DateTime.now(),
        );
      } else if (current.status != DownloadStatus.cancelled &&
          current.status != DownloadStatus.done) {
        final errMsg = stderrBuffer.toString().trim();
        yield current.copyWith(
          status: DownloadStatus.error,
          errorMessage: _parseError(errMsg).isNotEmpty
              ? _parseError(errMsg)
              : 'Tải thất bại (exit code: $exitCode)',
        );
      }
    } catch (e) {
      process?.kill();
      yield task.copyWith(
        status: DownloadStatus.error,
        errorMessage: 'Lỗi: $e',
      );
    }
  }

  // ── Build args ─────────────────────────────────────────

  List<String> _buildDownloadArgs(DownloadTask task, String outTemplate) {
    final args = <String>[
      '-f', task.formatId,
      '-o', outTemplate,
      '--no-playlist',
      '--newline', // Đảm bảo mỗi progress update ra 1 dòng
      '--progress',
      '--no-warnings',
      '--restrict-filenames', // Tránh ký tự đặc biệt trong tên file
    ];

    // Nếu formatId là audio-only → merge thêm audio
    if (task.formatId.contains('audio') ||
        task.ext == 'm4a' ||
        task.ext == 'mp3') {
      // Audio: không cần merge
    } else {
      // Video: tự libytdlp.so merge nếu cần
      args.addAll(['--merge-output-format', 'mp4']);
    }

    args.add(task.url);
    return args;
  }

  // ── Helpers ────────────────────────────────────────────

  /// Parse thông báo lỗi từ stderr libytdlp.so, trả về string thân thiện VI
  String _parseError(String stderr) {
    if (stderr.contains('Private video')) {
      return 'Video này là riêng tư';
    }
    if (stderr.contains('Sign in') || stderr.contains('login')) {
      return 'Video yêu cầu đăng nhập';
    }
    if (stderr.contains('Unsupported URL')) {
      return 'URL không được hỗ trợ';
    }
    if (stderr.contains('Unable to extract')) {
      return 'Không thể trích xuất thông tin video';
    }
    if (stderr.contains('404')) {
      return 'Video không tồn tại (404)';
    }
    if (stderr.contains('429')) {
      return 'Quá nhiều yêu cầu, thử lại sau';
    }
    if (stderr.contains('is not a valid URL')) {
      return 'URL không hợp lệ';
    }
    if (stderr.contains('No internet') || stderr.contains('Unable to connect')) {
      return 'Không có kết nối mạng';
    }

    // Lấy dòng ERROR đầu tiên
    final errorLine = stderr
        .split('\n')
        .where((l) => l.toLowerCase().startsWith('error'))
        .firstOrNull;

    if (errorLine != null) {
      return errorLine.replaceFirst(RegExp(r'error:\s*', caseSensitive: false), '').trim();
    }

    return 'Đã xảy ra lỗi khi xử lý';
  }

  /// Kiểm tra libytdlp.so version (để xác nhận binary hoạt động)
  Future<String?> getVersion() async {
    try {
      final result = await Process.run(_bin, ['--version'], stdoutEncoding: utf8);
      return result.stdout.toString().trim();
    } catch (_) {
      return null;
    }
  }
}
