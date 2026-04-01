// lib/models/download_task.dart

import 'dart:io';

/// Trạng thái của một tác vụ tải xuống
enum DownloadStatus {
  /// Đang xếp hàng chờ (vượt quá maxConcurrentDownloads)
  queued,

  /// Đang chuẩn bị (extract binary, kiểm tra thư mục...)
  preparing,

  /// Đang tải
  downloading,

  /// Hoàn thành
  done,

  /// Lỗi
  error,

  /// Đã hủy bởi user
  cancelled;

  bool get isActive => this == downloading || this == preparing;
  bool get isFinished => this == done || this == error || this == cancelled;

  String get displayText {
    switch (this) {
      case DownloadStatus.queued:
        return 'Đang xếp hàng';
      case DownloadStatus.preparing:
        return 'Chuẩn bị...';
      case DownloadStatus.downloading:
        return 'Đang tải';
      case DownloadStatus.done:
        return 'Hoàn thành';
      case DownloadStatus.error:
        return 'Lỗi';
      case DownloadStatus.cancelled:
        return 'Đã hủy';
    }
  }
}

/// Đại diện cho một tác vụ tải xuống (video hoặc audio)
class DownloadTask {
  final String id;
  final String title;
  final String url;
  final String formatId;
  final String ext;
  final String? thumbnail;

  /// Tiến trình 0.0 → 1.0
  final double progress;

  final DownloadStatus status;

  /// Tốc độ tải ví dụ: "1.2MiB/s"
  final String speed;

  /// Thời gian còn lại ví dụ: "00:42"
  final String eta;

  /// Thông báo lỗi nếu status == error
  final String? errorMessage;

  /// Đường dẫn file sau khi tải xong
  final String? outputPath;

  /// Thời điểm bắt đầu tải (để tính elapsed time)
  final DateTime? startedAt;

  /// Thời điểm hoàn thành
  final DateTime? completedAt;

  /// Process handle để cancel
  final Process? process;

  const DownloadTask({
    required this.id,
    required this.title,
    required this.url,
    required this.formatId,
    required this.ext,
    this.thumbnail,
    this.progress = 0.0,
    this.status = DownloadStatus.queued,
    this.speed = '',
    this.eta = '',
    this.errorMessage,
    this.outputPath,
    this.startedAt,
    this.completedAt,
    this.process,
  });

  // ── copyWith ───────────────────────────────────────────

  DownloadTask copyWith({
    double? progress,
    DownloadStatus? status,
    String? speed,
    String? eta,
    String? errorMessage,
    String? outputPath,
    DateTime? startedAt,
    DateTime? completedAt,
    Process? process,
  }) {
    return DownloadTask(
      id: id,
      title: title,
      url: url,
      formatId: formatId,
      ext: ext,
      thumbnail: thumbnail,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      errorMessage: errorMessage ?? this.errorMessage,
      outputPath: outputPath ?? this.outputPath,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      process: process ?? this.process,
    );
  }

  // ── Helpers ────────────────────────────────────────────

  /// Phần trăm hiển thị "45%"
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  /// Có thể retry không
  bool get canRetry => status == DownloadStatus.error;

  /// Có thể cancel không
  bool get canCancel =>
      status == DownloadStatus.downloading ||
      status == DownloadStatus.queued ||
      status == DownloadStatus.preparing;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is DownloadTask && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'DownloadTask(id=$id, title="$title", '
      'status=${status.name}, progress=${progressPercent})';
}

// ── Extension parse progress từ log libytdlp.so ────────────────

extension DownloadTaskParsing on DownloadTask {
  /// Parse dòng log libytdlp.so, trả về task đã cập nhật progress
  /// Input: "[download]  45.3% of 10.00MiB at 1.2MiB/s ETA 00:10"
  DownloadTask? applyLogLine(String line) {
    // Progress line
    final progressMatch = RegExp(
      r'\[download\]\s+([\d.]+)%\s+of\s+[\S]+\s+at\s+([\S]+)\s+ETA\s+(\S+)',
      caseSensitive: false,
    ).firstMatch(line);

    if (progressMatch != null) {
      final pct = double.tryParse(progressMatch.group(1)!) ?? 0;
      final spd = progressMatch.group(2) ?? '';
      final etaStr = progressMatch.group(3) ?? '';

      return copyWith(
        progress: pct / 100.0,
        speed: spd,
        eta: etaStr,
        status: DownloadStatus.downloading,
      );
    }

    // Destination line — lấy output path
    final destMatch = RegExp(
      r'\[download\] Destination: (.+)',
    ).firstMatch(line);

    if (destMatch != null) {
      return copyWith(outputPath: destMatch.group(1)?.trim());
    }

    // 100% done line
    if (line.contains('[download] 100%')) {
      return copyWith(
        progress: 1.0,
        status: DownloadStatus.done,
        speed: '',
        eta: '',
        completedAt: DateTime.now(),
      );
    }

    // Error line
    final errMatch = RegExp(
      r'ERROR: (.+)',
      caseSensitive: false,
    ).firstMatch(line);

    if (errMatch != null) {
      return copyWith(
        status: DownloadStatus.error,
        errorMessage: errMatch.group(1)?.trim(),
      );
    }

    return null;
  }
}
