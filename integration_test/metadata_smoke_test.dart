import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Opt-in: these tests contact public websites, so they do not run in unit CI.
// flutter test integration_test/metadata_smoke_test.dart -d <android-device>
//   --dart-define=LIVE_METADATA_TESTS=true
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('LIVE_METADATA_TESTS');
  const urls = {
    'playlist':
        'https://www.youtube.com/playlist?list=PLqQqNpXWFqHpZsOWV7-KPMHe2tTBAB2RG',
    'youtube':
        'https://www.youtube.com/watch?v=RChxQsvPTEs&list=PLqQqNpXWFqHpZsOWV7-KPMHe2tTBAB2RG&index=1',
    'facebook': 'https://www.facebook.com/share/v/1d2kGLBV5z/',
    'tiktok': 'https://vt.tiktok.com/ZSbKTBhQQ/',
  };
  for (final entry in urls.entries) {
    testWidgets(
      'Android metadata: ${entry.key}',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        final backend = jsonDecode(
          (await const MethodChannel('ytdlp_channel')
              .invokeMethod<String>('getBackendInfo'))!,
        ) as Map<String, dynamic>;
        expect(backend['curl_cffi_error'], isNull, reason: '$backend');
        expect(backend['curl_cffi'], '0.16.2');
        final raw = await const MethodChannel('ytdlp_channel')
            .invokeMethod<String>('analyze', {'url': entry.value})
            .timeout(const Duration(seconds: 120));
        final data = jsonDecode(raw!) as Map<String, dynamic>;
        expect(data['error'], isNull, reason: '$data');
        expect(data['title'], isNotEmpty);
        if (entry.key == 'playlist') {
          expect(data['_type'], 'playlist');
          expect(data['playlist_count'], greaterThan(0));
        } else {
          expect(data['_type'], isNot('playlist'));
          expect(data['formats'], isNotEmpty);
        }
      },
      skip: !enabled,
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
