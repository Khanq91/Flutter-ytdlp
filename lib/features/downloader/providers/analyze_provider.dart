// lib/providers/analyze_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/video_info.dart';
import '../services/ytdlp_service.dart';

final analyzeGatewayProvider = Provider<AnalyzeGateway>(
  (ref) => YtdlpService.instance,
);

final playlistGatewayProvider = Provider<PlaylistGateway>(
  (ref) => YtdlpService.instance,
);

// ── State ──────────────────────────────────────────────────

enum AnalyzeStatus { idle, loading, success, error }

const _notProvided = Object();

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
    Object? videoInfo = _notProvided,
    Object? errorMessage = _notProvided,
    String? currentUrl,
    String? detectedPlatform,
  }) {
    return AnalyzeState(
      status: status ?? this.status,
      videoInfo:
          identical(videoInfo, _notProvided)
              ? this.videoInfo
              : videoInfo as VideoInfo?,
      errorMessage:
          identical(errorMessage, _notProvided)
              ? this.errorMessage
              : errorMessage as String?,
      currentUrl: currentUrl ?? this.currentUrl,
      detectedPlatform: detectedPlatform ?? this.detectedPlatform,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────

class AnalyzeNotifier extends Notifier<AnalyzeState> {
  int _requestRevision = 0;

  @override
  AnalyzeState build() => const AnalyzeState();

  /// Gọi khi user thay đổi nội dung TextField
  void onUrlChanged(String url) {
    if (url == state.currentUrl) return;

    _requestRevision++;
    final platform = _detectPlatform(url);
    state = state.copyWith(
      currentUrl: url,
      detectedPlatform: platform,
      status: AnalyzeStatus.idle,
      videoInfo: null,
      errorMessage: null,
    );
  }

  /// Gọi khi user nhấn nút Analyze
  Future<void> analyze() async {
    final url = state.currentUrl.trim();
    if (url.isEmpty || state.isLoading) return;

    final requestRevision = ++_requestRevision;
    state = state.copyWith(
      status: AnalyzeStatus.loading,
      videoInfo: null,
      errorMessage: null,
    );

    final result = await ref.read(analyzeGatewayProvider).analyze(url);
    if (requestRevision != _requestRevision) return;

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
    _requestRevision++;
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

final analyzeProvider = NotifierProvider<AnalyzeNotifier, AnalyzeState>(
  AnalyzeNotifier.new,
);
