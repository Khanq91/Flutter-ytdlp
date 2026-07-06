import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_ytdlp/main.dart';
import 'package:flutter_ytdlp/screens/analyze/analyze_screen.dart';

void main() {
  testWidgets('App starts on analyze screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: YtdlApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AnalyzeScreen), findsOneWidget);
  });
}
