// lib/models/format_option.dart

/// Đại diện cho một định dạng tải xuống từ libytdlp.so
class FormatOption {
  final String formatId;
  final String ext;

  /// Label hiển thị: "720p", "1080p", "m4a 128kbps", v.v.
  final String quality;

  /// Chỉ audio (không có video)
  final bool isAudioOnly;

  /// Bitrate (kbps) — dùng cho audio
  final int? bitrate;

  /// Kích thước file ước tính (bytes) — có thể null nếu libytdlp.so không biết
  final int? filesize;

  /// Chiều rộng video (null nếu audio only)
  final int? width;

  /// Chiều cao video (null nếu audio only)
  final int? height;

  /// Frame rate
  final double? fps;

  /// Video codec
  final String? vcodec;

  /// Audio codec
  final String? acodec;

  const FormatOption({
    required this.formatId,
    required this.ext,
    required this.quality,
    required this.isAudioOnly,
    this.bitrate,
    this.filesize,
    this.width,
    this.height,
    this.fps,
    this.vcodec,
    this.acodec,
  });

  // ── Factory từ JSON libytdlp.so ─────────────────────────────

  factory FormatOption.fromJson(Map<String, dynamic> json) {
    final vcodec = json['vcodec'] as String?;
    final acodec = json['acodec'] as String?;

    final bool isAudioOnly =
        (vcodec == null || vcodec == 'none' || vcodec.isEmpty) &&
            (acodec != null && acodec != 'none' && acodec.isNotEmpty);

    // ✅ Fix: filesize có thể là double — ép kiểu an toàn
    int? _parseInt(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    final int? height = _parseInt(json['height']);
    final int? abr = _parseInt(json['abr']);

    // TikTok: format muxed có cả vcodec + acodec → không phải audioOnly
    // nhưng không có height → dùng format_note
    String quality;
    if (isAudioOnly) {
      quality = abr != null ? '${abr}kbps' : 'audio';
    } else if (height != null && height > 0) {
      quality = '${height}p';
    } else {
      // TikTok muxed format: dùng format_note hoặc tbr
      final note = json['format_note'] as String?;
      final tbr = _parseInt(json['tbr']);
      quality = note?.isNotEmpty == true
          ? note!
          : (tbr != null ? '${tbr}kbps' : json['format_id'] as String);
    }

    return FormatOption(
      formatId: json['format_id'] as String,
      ext:      json['ext'] as String? ?? 'unknown',
      quality:  quality,
      isAudioOnly: isAudioOnly,
      bitrate:  abr,
      // ✅ Fix: dùng _parseInt thay vì cast thẳng
      filesize: _parseInt(json['filesize']) ?? _parseInt(json['filesize_approx']),
      width:    _parseInt(json['width']),
      height:   height,
      fps:      (json['fps'] as num?)?.toDouble(),
      vcodec:   vcodec,
      acodec:   acodec,
    );
  }

  // ── Helpers ────────────────────────────────────────────

  /// Kích thước file định dạng human-readable
  String get formattedFilesize {
    if (filesize == null) return 'Không rõ';
    if (filesize! < 1024 * 1024) {
      return '${(filesize! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(filesize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Label đầy đủ hiển thị trên UI
  String get displayLabel {
    if (isAudioOnly) {
      return '$ext · $quality';
    }
    final fpsStr = fps != null ? ' · ${fps!.toStringAsFixed(0)}fps' : '';
    return '$quality · $ext$fpsStr';
  }

  @override
  String toString() =>
      'FormatOption(id=$formatId, ext=$ext, quality=$quality, '
      'audioOnly=$isAudioOnly, size=$formattedFilesize)';
}
