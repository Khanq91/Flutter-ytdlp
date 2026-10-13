// lib/features/downloader/services/download_permission_service.dart

import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions the download flow needs, behind an interface so
/// [DownloadNotifier.startFromFormat] can be tested without the platform.
abstract interface class DownloadPermissionGateway {
  /// Asks for the notification permission the foreground download service
  /// uses to show progress. True when granted or when the platform has no
  /// such runtime permission; downloads proceed either way.
  Future<bool> requestNotificationPermission();
}

class DownloadPermissionService implements DownloadPermissionGateway {
  DownloadPermissionService._();
  static final DownloadPermissionService instance =
      DownloadPermissionService._();

  @override
  Future<bool> requestNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    return (await Permission.notification.request()).isGranted;
  }
}
