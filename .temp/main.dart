// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khóa portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Transparent status bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    navigationBarColor: Colors.transparent,
  ));

  // Init storage: extract libytdlp.so binary + chuẩn bị download folder
  await StorageService.instance.init();

  runApp(
    const ProviderScope(
      child: YtdlApp(),
    ),
  );
}

class YtdlApp extends StatelessWidget {
  const YtdlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YTDLModule',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRoutes.analyze,
      // Đảm bảo app hiển thị đúng trên màn hình cong / notch
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling, // Giữ font size nhất quán
          ),
          child: child!,
        );
      },
    );
  }
}
