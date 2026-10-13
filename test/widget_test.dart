import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_ytdlp/core/app_strings.dart';
import 'package:flutter_ytdlp/main.dart';
import 'package:flutter_ytdlp/features/downloader/providers/download_provider.dart';
import 'package:flutter_ytdlp/features/downloader/screens/analyze/analyze_screen.dart';
import 'package:flutter_ytdlp/features/downloader/screens/downloader_gateway_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var online = true;

  setUp(() {
    online = true;
    GoogleFonts.config.allowRuntimeFetching = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    // Fonts are outside this navigation test: provide in-memory asset entries
    // so GoogleFonts does not perform network or filesystem work.
    messenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == 'AssetManifest.bin') {
        return const StandardMessageCodec().encodeMessage({
          for (final weight in [
            'Thin',
            'ExtraLight',
            'Light',
            'Regular',
            'Medium',
            'SemiBold',
            'Bold',
            'ExtraBold',
            'Black',
          ])
            'fonts/Outfit-$weight.ttf': [
              {'asset': 'fonts/Outfit-$weight.ttf'},
            ],
        });
      }
      if (key.startsWith('fonts/Outfit-')) return ByteData(0);
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity'),
      (_) async => [online ? 'wifi' : 'none'],
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/connectivity_status'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('ytdlp_channel'),
      (call) async => call.method == 'getDownloadTasks' ? '[]' : null,
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMessageHandler('flutter/assets', null);
    for (final channel in [
      'dev.fluttercommunity.plus/connectivity',
      'dev.fluttercommunity.plus/connectivity_status',
      'ytdlp_channel',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), null);
    }
  });

  testWidgets('standalone gateway opens downloader and back returns safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadOutputDirectoryProvider.overrideWith(_ReadyDirectory.new),
        ],
        child: const YtdlApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(DownloaderGatewayScreen), findsOneWidget);
    expect(find.byTooltip(AppStrings.back), findsNothing);
    expect(find.text('Quét lại thư viện'), findsNothing);

    await tester.ensureVisible(find.text(AppStrings.downloadFromUrl));
    await tester.tap(find.text(AppStrings.downloadFromUrl));
    await tester.pumpAndSettle();
    expect(find.byType(AnalyzeScreen), findsOneWidget);
    expect(find.textContaining('/storage/emulated/0/Download'), findsWidgets);

    await tester.tap(find.byTooltip(AppStrings.back));
    await tester.pumpAndSettle();
    expect(find.byType(DownloaderGatewayScreen), findsOneWidget);
    expect(find.byType(AnalyzeScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('offline gateway retains network guard from Muzicz', (
    tester,
  ) async {
    online = false;
    await tester.pumpWidget(const ProviderScope(child: YtdlApp()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.downloadFromUrl));
    await tester.tap(find.text(AppStrings.downloadFromUrl));
    await tester.pumpAndSettle();
    expect(find.byType(DownloaderGatewayScreen), findsOneWidget);
    expect(find.byType(AnalyzeScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _ReadyDirectory extends OutputDirectoryNotifier {
  @override
  Future<String> build() async => '/storage/emulated/0/Download';
}
