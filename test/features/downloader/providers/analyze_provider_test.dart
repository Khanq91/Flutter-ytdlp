import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ytdlp/features/downloader/models/video_info.dart';
import 'package:flutter_ytdlp/features/downloader/providers/analyze_provider.dart';
import 'package:flutter_ytdlp/features/downloader/services/ytdlp_service.dart';

void main() {
  test('changing URL clears the previous result', () async {
    final gateway = _FakeAnalyzeGateway();
    final container = ProviderContainer(
      overrides: [analyzeGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(analyzeProvider.notifier);
    notifier.onUrlChanged(_urlA);
    final request = notifier.analyze();
    gateway.complete(_urlA, AnalyzeSuccess(_videoA));
    await request;
    expect(container.read(analyzeProvider).videoInfo, same(_videoA));

    notifier.onUrlChanged(_urlB);

    final state = container.read(analyzeProvider);
    expect(state.status, AnalyzeStatus.idle);
    expect(state.videoInfo, isNull);
    expect(state.errorMessage, isNull);
  });

  test('an older response cannot overwrite a newer request', () async {
    final gateway = _FakeAnalyzeGateway();
    final container = ProviderContainer(
      overrides: [analyzeGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(analyzeProvider.notifier);
    notifier.onUrlChanged(_urlA);
    final requestA = notifier.analyze();
    notifier.onUrlChanged(_urlB);
    final requestB = notifier.analyze();

    gateway.complete(_urlB, AnalyzeSuccess(_videoB));
    await requestB;
    gateway.complete(_urlA, AnalyzeSuccess(_videoA));
    await requestA;

    final state = container.read(analyzeProvider);
    expect(state.currentUrl, _urlB);
    expect(state.status, AnalyzeStatus.success);
    expect(state.videoInfo, same(_videoB));
  });

  test('duplicate submit while loading starts one request', () async {
    final gateway = _FakeAnalyzeGateway();
    final container = ProviderContainer(
      overrides: [analyzeGatewayProvider.overrideWithValue(gateway)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(analyzeProvider.notifier);
    notifier.onUrlChanged(_urlA);
    final first = notifier.analyze();
    final duplicate = notifier.analyze();

    expect(gateway.calls, [_urlA]);
    gateway.complete(_urlA, AnalyzeSuccess(_videoA));
    await Future.wait([first, duplicate]);
  });
}

class _FakeAnalyzeGateway implements AnalyzeGateway {
  final calls = <String>[];
  final _responses = <String, Completer<AnalyzeResult>>{};

  @override
  Future<AnalyzeResult> analyze(String url) {
    calls.add(url);
    return (_responses[url] ??= Completer<AnalyzeResult>()).future;
  }

  void complete(String url, AnalyzeResult result) {
    (_responses[url] ??= Completer<AnalyzeResult>()).complete(result);
  }
}

const _urlA = 'https://example.com/a';
const _urlB = 'https://example.com/b';

const _videoA = VideoInfo(
  id: 'a',
  title: 'Video A',
  platform: VideoPlatform.unknown,
  type: VideoType.video,
  skippedCount: null,
  formats: [],
  url: _urlA,
);

const _videoB = VideoInfo(
  id: 'b',
  title: 'Video B',
  platform: VideoPlatform.unknown,
  type: VideoType.video,
  skippedCount: null,
  formats: [],
  url: _urlB,
);
