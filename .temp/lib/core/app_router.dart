// lib/core/app_router.dart

import 'package:flutter/material.dart';

import '../models/video_info.dart';
import '../screens/analyze/analyze_screen.dart';
import '../screens/download/download_screen.dart';
import '../screens/format/format_screen.dart';
import '../screens/summary/summary_screen.dart';

class AppRoutes {
  static const String analyze = '/';
  static const String format = '/format';
  static const String download = '/download';
  static const String summary = '/summary';
}

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.analyze:
        return _slide(const AnalyzeScreen());

      case AppRoutes.format:
        final info = settings.arguments as VideoInfo;
        return _slide(FormatScreen(videoInfo: info));

      case AppRoutes.download:
        return _slide(const DownloadScreen());

      case AppRoutes.summary:
        return _slide(const SummaryScreen());

      default:
        return _slide(const AnalyzeScreen());
    }
  }

  static PageRouteBuilder _slide(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
    );
  }
}
