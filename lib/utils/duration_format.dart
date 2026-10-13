/// Định dạng [Duration] → chuỗi hiển thị. Nguồn duy nhất cho toàn app,
/// thay cho các helper lặp lại trong model/screen.
extension DurationFormat on Duration {
  /// `mm:ss`, luôn 2 chữ số phút (03:05).
  /// Dùng cho thời lượng bài hát và thanh tiến trình.
  String get mmss =>
      '${inMinutes.toString().padLeft(2, '0')}:'
      '${(inSeconds % 60).toString().padLeft(2, '0')}';

  /// `h:mm:ss` khi ≥ 1 giờ, ngược lại `m:ss` (3:05).
  /// Dùng cho video / playlist entry của downloader.
  String get clock {
    final m = (inMinutes % 60).toString().padLeft(2, '0');
    final s = (inSeconds % 60).toString().padLeft(2, '0');
    if (inHours > 0) return '$inHours:$m:$s';
    return '$inMinutes:$s';
  }

  /// `Xh Ym` khi ≥ 1 giờ, ngược lại `Ym`. Dùng cho tổng thời lượng playlist.
  String get compact =>
      inHours > 0 ? '${inHours}h ${inMinutes % 60}m' : '${inMinutes}m';
}
