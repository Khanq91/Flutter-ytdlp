// lib/providers/analyze_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video_info.dart';
import '../services/ytdlp_service.dart';

// ── State ──────────────────────────────────────────────────

enum AnalyzeStatus { idle, loading, success, error }

class AnalyzeState {
  final AnalyzeStatus status;
  final VideoInfo? videoInfo;
  final String? errorMessage;

  /// URL hiện tại trong TextField
  final String currentUrl;

  /// Platform detect từ URL (trước khi analyze)
  final String detectedPlatform;

  const AnalyzeState({
    this.status = AnalyzeStatus.idle,
    this.videoInfo,
    this.errorMessage,
    this.currentUrl = '',
    this.detectedPlatform = '',
  });

  bool get isLoading => status == AnalyzeStatus.loading;
  bool get hasResult => status == AnalyzeStatus.success && videoInfo != null;
  bool get hasError => status == AnalyzeStatus.error;

  AnalyzeState copyWith({
    AnalyzeStatus? status,
    VideoInfo? videoInfo,
    String? errorMessage,
    String? currentUrl,
    String? detectedPlatform,
  }) {
    return AnalyzeState(
      status: status ?? this.status,
      videoInfo: videoInfo ?? this.videoInfo,
      errorMessage: errorMessage ?? this.errorMessage,
      currentUrl: currentUrl ?? this.currentUrl,
      detectedPlatform: detectedPlatform ?? this.detectedPlatform,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────

class AnalyzeNotifier extends Notifier<AnalyzeState> {
  @override
  AnalyzeState build() => const AnalyzeState();

  /// Gọi khi user thay đổi nội dung TextField
  void onUrlChanged(String url) {
    final platform = _detectPlatform(url);
    state = state.copyWith(
      currentUrl: url,
      detectedPlatform: platform,
      // Reset error nếu user đang sửa
      status: state.hasError ? AnalyzeStatus.idle : null,
    );
  }

  /// Gọi khi user nhấn nút Analyze
  Future<void> analyze() async {
    final url = state.currentUrl.trim();
    if (url.isEmpty) return;

    state = state.copyWith(status: AnalyzeStatus.loading);

    final result = await YtdlpService.instance.analyze(url);

    switch (result) {
      case AnalyzeSuccess(:final info):
        state = state.copyWith(
          status: AnalyzeStatus.success,
          videoInfo: info,
          errorMessage: null,
        );
      case AnalyzeFailure(:final message):
        state = state.copyWith(
          status: AnalyzeStatus.error,
          errorMessage: message,
          videoInfo: null,
        );
    }
  }

  /// Reset về idle (khi user xóa URL hoặc quay lại)
  void reset() {
    state = const AnalyzeState();
  }

  // ── Private ─────────────────────────────────────────────

  String _detectPlatform(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      return 'YouTube';
    }
    if (lower.contains('tiktok.com')) return 'TikTok';
    if (lower.contains('instagram.com')) return 'Instagram';
    if (lower.contains('facebook.com') || lower.contains('fb.watch')) {
      return 'Facebook';
    }
    if (lower.contains('twitter.com') || lower.contains('x.com')) {
      return 'Twitter / X';
    }
    if (lower.contains('vimeo.com')) return 'Vimeo';
    if (lower.startsWith('http')) return 'Web';
    return '';
  }
}

// ── Provider ───────────────────────────────────────────────

final analyzeProvider =
    NotifierProvider<AnalyzeNotifier, AnalyzeState>(AnalyzeNotifier.new);
