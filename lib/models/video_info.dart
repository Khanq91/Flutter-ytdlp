// lib/models/video_info.dart

import 'format_option.dart';

enum VideoType { video, playlist }

enum VideoPlatform {
  youtube,
  tiktok,
  instagram,
  facebook,
  twitter,
  vimeo,
  unknown;

  static VideoPlatform fromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return VideoPlatform.youtube;
    }
    if (lower.contains('tiktok.com')) return VideoPlatform.tiktok;
    if (lower.contains('instagram.com')) return VideoPlatform.instagram;
    if (lower.contains('facebook.com') || lower.contains('fb.watch')) {
      return VideoPlatform.facebook;
    }
    if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return VideoPlatform.twitter;
    }
    if (lower.contains('vimeo.com')) return VideoPlatform.vimeo;
    return VideoPlatform.unknown;
  }

  String get displayName {
    switch (this) {
      case VideoPlatform.youtube:
        return 'YouTube';
      case VideoPlatform.tiktok:
        return 'TikTok';
      case VideoPlatform.instagram:
        return 'Instagram';
      case VideoPlatform.facebook:
        return 'Facebook';
      case VideoPlatform.twitter:
        return 'Twitter / X';
      case VideoPlatform.vimeo:
        return 'Vimeo';
      case VideoPlatform.unknown:
        return 'Không xác định';
    }
  }
}

/// Thông tin video/playlist sau khi phân tích bằng libytdlp.so
class VideoInfo {
  final String id;
  final String title;
  final String? thumbnail;
  final int? duration; // giây
  final VideoPlatform platform;
  final VideoType type;
  final int? skippedCount;

  /// Số lượng video trong playlist (null nếu là video đơn)
  final int? playlistCount;

  /// Danh sách các định dạng có thể tải
  final List<FormatOption> formats;

  /// URL gốc user nhập vào
  final String url;

  final String? uploader;
  final String? description;

  const VideoInfo({
    required this.id,
    required this.title,
    this.thumbnail,
    this.duration,
    required this.platform,
    required this.type,
    required this.skippedCount,
    this.playlistCount,
    required this.formats,
    required this.url,
    this.uploader,
    this.description,
  });

  // ── Factory từ JSON libytdlp.so ─────────────────────────────

  factory VideoInfo.fromYtDlpJson(Map<String, dynamic> json, String url) {
    final rawType  = json['_type'] as String?;
    final isPlaylist = rawType == 'playlist';

    final rawFormats = json['formats'] as List<dynamic>? ?? [];
    final formats = rawFormats
        .whereType<Map<String, dynamic>>()
        .map(FormatOption.fromJson)
        .where((f) {
      // Bỏ format không hữu dụng
      if (f.ext == 'mhtml') return false;
      if (f.ext == 'none') return false;
      // ✅ Giữ lại muxed format (TikTok): có cả vcodec + acodec
      // và pure audio: không có vcodec
      return true;
    })
        .toList();

    return VideoInfo(
      id:           json['id'] as String? ?? '',
      title:        json['title'] as String? ?? 'Không có tiêu đề',
      thumbnail:    json['thumbnail'] as String?,
      duration:     (json['duration'] as num?)?.toInt(), // ✅ ép kiểu an toàn
      platform:     VideoPlatform.fromUrl(url),
      type:         isPlaylist ? VideoType.playlist : VideoType.video,
      playlistCount: json['playlist_count'] as int?,
      formats:      formats,
      url:          url,
      uploader:     json['uploader'] as String?,
      description:  json['description'] as String?,
      skippedCount: json['skipped_count'] as int?,
    );
  }

  // ── Helpers ────────────────────────────────────────────

  String get formattedDuration {
    if (duration == null) return '';
    final h = duration! ~/ 3600;
    final m = (duration! % 3600) ~/ 60;
    final s = duration! % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Formats chỉ audio (m4a, mp3, opus...)
  List<FormatOption> get audioFormats =>
      formats.where((f) => f.isAudioOnly).toList();

  /// Formats có video (đã gộp audio+video)
  List<FormatOption> get videoFormats =>
      formats.where((f) => !f.isAudioOnly).toList();

  /// Format audio tốt nhất (ưu tiên m4a)
  FormatOption? get bestAudioFormat {
    final m4a = audioFormats.where((f) => f.ext == 'm4a').toList();
    if (m4a.isNotEmpty) {
      m4a.sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
      return m4a.first;
    }
    return audioFormats.isNotEmpty ? audioFormats.first : null;
  }

  VideoInfo copyWith({
    List<FormatOption>? formats,
    int? playlistCount,
    int? skippedCount,
  }) {
    return VideoInfo(
      id: id,
      title: title,
      thumbnail: thumbnail,
      duration: duration,
      platform: platform,
      type: type,
      skippedCount: skippedCount,
      playlistCount: playlistCount,
      formats: formats ?? this.formats,
      url: url,
      uploader: uploader,
      description: description,
    );
  }

  @override
  String toString() =>
      'VideoInfo(id=$id, title="$title", platform=${platform.displayName}, '
      'type=$type, formats=${formats.length})';
}
