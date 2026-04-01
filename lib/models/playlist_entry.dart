// lib/models/playlist_entry.dart

class PlaylistEntry {
  final String id;
  final String title;
  final String? thumbnail;
  final int? duration;
  final String url;
  final String? uploader;

  /// true = được chọn để tải
  final bool selected;

  const PlaylistEntry({
    required this.id,
    required this.title,
    this.thumbnail,
    this.duration,
    required this.url,
    this.uploader,
    this.selected = true,
  });

  factory PlaylistEntry.fromJson(Map<String, dynamic> json) {
    return PlaylistEntry(
      id:        json['id'] as String? ?? '',
      title:     json['title'] as String? ?? 'Không có tiêu đề',
      thumbnail: json['thumbnail'] as String?,
      duration:  (json['duration'] as num?)?.toInt(),
      url:       json['url'] as String? ?? '',
      uploader:  json['uploader'] as String?,
      // selected:  true,
      selected: (json['url'] as String?)?.isNotEmpty == true,
    );
  }

  PlaylistEntry copyWith({bool? selected}) {
    return PlaylistEntry(
      id:        id,
      title:     title,
      thumbnail: thumbnail,
      duration:  duration,
      url:       url,
      uploader:  uploader,
      selected:  selected ?? this.selected,
    );
  }
  bool get isPlayable {
    if (url.isEmpty) return false;

    final t = title.toLowerCase();
    if (t.contains('deleted') || t.contains('private')) {
      return false;
    }

    return true;
  }

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is PlaylistEntry && other.id == id);

  @override
  int get hashCode => id.hashCode;
}