// lib/services/storage_service.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants/app_constants.dart';

/// Quản lý:
/// 1. Extract + chmod libytdlp.so binary ra filesDir
/// 2. Đường dẫn thư mục lưu file download
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  String? _ytdlpPath;
  String? _downloadPath;

  // ── libytdlp.so binary ──────────────────────────────────────

  /// Đường dẫn thực thi libytdlp.so sau khi đã extract
  String get ytdlpPath {
    assert(_ytdlpPath != null, 'Gọi init() trước');
    return _ytdlpPath!;
  }

  /// Extract binary từ assets vào filesDir lần đầu, sau đó dùng lại.
  /// Gọi khi app khởi động (trước khi cần dùng libytdlp.so).
  Future<void> init() async {
    await _extractYtdlp();
    await _initDownloadPath();
  }

  Future<void> _extractYtdlp() async {
    final dir = await getApplicationSupportDirectory();
    final binPath = '${dir.path}/${AppConstants.ytdlpBinaryName}';
    final file = File(binPath);

    // Chỉ copy nếu chưa tồn tại hoặc cần update
    if (!file.existsSync()) {
      final data = await rootBundle.load(AppConstants.ytdlpAssetPath);
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes, flush: true);

      // chmod +x để có thể execute
      await Process.run('chmod', ['755', binPath]);
    }

    _ytdlpPath = binPath;
  }

  // ── Download path ──────────────────────────────────────

  String get downloadPath {
    assert(_downloadPath != null, 'Gọi init() trước');
    return _downloadPath!;
  }

  Future<void> _initDownloadPath() async {
    // Lấy thư mục Downloads của thiết bị
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) {
      final dir = Directory(
        '${extDir.path.split('Android').first}${AppConstants.defaultDownloadFolder}',
      );
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
      _downloadPath = dir.path;
    } else {
      // Fallback: dùng app documents dir
      final docDir = await getApplicationDocumentsDirectory();
      _downloadPath = docDir.path;
    }
  }

  /// Cho user chọn thư mục lưu file
  Future<String?> pickDownloadDirectory() async {
    // Request permission trước
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      final manageStatus =
          await Permission.manageExternalStorage.request();
      if (!manageStatus.isGranted) return null;
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Chọn thư mục lưu file',
      initialDirectory: _downloadPath,
    );

    if (result != null) {
      _downloadPath = result;
    }

    return _downloadPath;
  }

  /// Kiểm tra quyền ghi storage
  Future<bool> checkStoragePermission() async {
    if (Platform.isAndroid) {
      // Android 10+ (API 29+) không cần WRITE_EXTERNAL_STORAGE
      // nhưng cần MANAGE_EXTERNAL_STORAGE cho /sdcard
      final info = await Process.run('getprop', ['ro.build.version.sdk']);
      final sdk = int.tryParse(info.stdout.toString().trim()) ?? 33;

      if (sdk >= 30) {
        return Permission.manageExternalStorage.isGranted;
      } else {
        return Permission.storage.isGranted;
      }
    }
    return true;
  }

  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final info = await Process.run('getprop', ['ro.build.version.sdk']);
      final sdk = int.tryParse(info.stdout.toString().trim()) ?? 33;

      if (sdk >= 30) {
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true;
  }

  /// Mở file manager tại thư mục download
  Future<void> openDownloadFolder() async {
    await Process.run('am', [
      'start',
      '-a',
      'android.intent.action.VIEW',
      '-d',
      'file://$downloadPath',
    ]);
  }

  /// Lấy dung lượng trống của thư mục download (bytes)
  Future<int?> getFreeSpace() async {
    try {
      final result = await Process.run('df', ['-k', downloadPath]);
      final lines = result.stdout.toString().split('\n');
      if (lines.length > 1) {
        final parts = lines[1].trim().split(RegExp(r'\s+'));
        if (parts.length >= 4) {
          final kbFree = int.tryParse(parts[3]);
          return kbFree != null ? kbFree * 1024 : null;
        }
      }
    } catch (_) {}
    return null;
  }
}
