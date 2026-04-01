// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // ── libytdlp.so Binary ─────────────────────────────────────
  static const String ytdlpAssetPath = 'assets/bin/libytdlp.so';
  static const String ytdlpBinaryName = 'libytdlp.so';

  // ── Download ───────────────────────────────────────────
  /// Số lượng download chạy song song tối đa
  static const int maxConcurrentDownloads = 10;

  /// Timeout phân tích URL (giây)
  static const int analyzeTimeoutSeconds = 30;

  /// Thư mục mặc định nếu user chưa chọn
  static const String defaultDownloadFolder = 'Download/YTDLModule';

  // ── Platform detection ─────────────────────────────────
  static const Map<String, String> platformPatterns = {
    'youtube': r'(youtube\.com|youtu\.be)',
    'tiktok': r'tiktok\.com',
    'instagram': r'instagram\.com',
    'facebook': r'facebook\.com|fb\.watch',
    'twitter': r'twitter\.com|x\.com',
    'vimeo': r'vimeo\.com',
  };

  static const Map<String, String> platformIcons = {
    'youtube': '▶',
    'tiktok': '♪',
    'instagram': '◈',
    'facebook': 'f',
    'twitter': '✕',
    'vimeo': '◉',
    'unknown': '◎',
  };

  // ── Format priorities ──────────────────────────────────
  /// Format audio ưu tiên khi user chọn Audio
  static const String preferredAudioFormat = 'bestaudio[ext=m4a]/bestaudio';

  /// Format video ưu tiên mặc định
  static const String preferredVideoFormat =
      'bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best';

  // ── Regex parse log libytdlp.so ─────────────────────────────
  /// [download]  45.3% of 10.00MiB at 1.2MiB/s ETA 00:10
  static final RegExp downloadProgressRegex = RegExp(
    r'\[download\]\s+([\d.]+)%\s+of\s+[\d.]+\S+\s+at\s+([\d.]+\S+)\s+ETA\s+(\d+:\d+)',
    caseSensitive: false,
  );

  /// [download] Destination: /path/to/file.mp4
  static final RegExp downloadDestinationRegex = RegExp(
    r'\[download\] Destination: (.+)',
  );

  /// ERROR: ...
  static final RegExp errorRegex = RegExp(
    r'ERROR: (.+)',
    caseSensitive: false,
  );
}