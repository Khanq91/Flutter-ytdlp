// lib/services/downloader_storage_service.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

/// Storage boundary the downloader providers depend on, so neither widgets
/// nor notifiers reach [DownloaderStorageService.instance] directly and tests
/// can substitute a fake.
abstract interface class DownloadStorageGateway {
  /// Loads the saved output directory or creates the default one.
  Future<void> init();

  /// Current output directory. Only valid after [init] completed.
  String get downloadPath;

  Future<bool> requestStoragePermission();

  /// Root of external storage, e.g. `/storage/emulated/0`.
  Future<String> getExternalBasePath();

  /// Creates [path] if needed, then persists it as the output directory.
  /// Keeps the previous directory when [path] cannot be created.
  Future<void> setAndSavePath(String path);

  /// Opens the system directory picker without persisting the choice.
  /// Returns null when the user cancels.
  Future<String?> pickDirectory({String? initialDirectory});

  Future<void> openDownloadFolder();
}

class DownloaderStorageService implements DownloadStorageGateway {
  DownloaderStorageService._();
  static final DownloaderStorageService instance = DownloaderStorageService._();

  static const _channel = MethodChannel('ytdlp_channel');

  String? _downloadPath;

  @override
  String get downloadPath {
    assert(_downloadPath != null, 'Gọi init() trước');
    return _downloadPath!;
  }

  Future<void> _savePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_path', path);
  }

  Future<void> _loadSavedOrInitDownloadPath() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('download_path');

    if (saved != null && saved.isNotEmpty) {
      final dir = Directory(saved);

      if (dir.existsSync()) {
        _downloadPath = saved;
        debugPrint('[StorageService] Loaded saved path: $_downloadPath');
        return;
      } else {
        debugPrint('[StorageService] Saved path invalid → fallback');
        await prefs.remove('download_path');
      }
    }

    await _initDownloadPath();
  }

  @override
  Future<void> init() async {
    await _loadSavedOrInitDownloadPath();
  }

  Future<void> _initDownloadPath() async {
    try {
      final path = await _channel.invokeMethod<String>('getDownloadDir');
      if (path != null && path.isNotEmpty) {
        final dir = Directory(path);
        if (!dir.existsSync()) await dir.create(recursive: true);
        _downloadPath = path;
        debugPrint('[StorageService] downloadPath: $_downloadPath');
        return;
      }
    } catch (e) {
      debugPrint('[StorageService] getDownloadDir channel failed: $e');
      // fallback bên dưới
    }

    // Fallback: dùng path_provider
    final extDir = await getExternalStorageDirectory();
    if (extDir != null) {
      final dir = Directory(
        '${extDir.path.split('Android').first}${AppConstants.defaultDownloadFolder}',
      );
      if (!dir.existsSync()) await dir.create(recursive: true);
      _downloadPath = dir.path;
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      _downloadPath = docDir.path;
    }
    debugPrint('[StorageService] downloadPath (fallback): $_downloadPath');
  }

  // ── Quick path helpers ─────────────────────────────────────────────────────

  /// Trả về đường dẫn gốc bộ nhớ ngoài, ví dụ: /storage/emulated/0
  @override
  Future<String> getExternalBasePath() async {
    try {
      final path = await _channel.invokeMethod<String>('getDownloadDir');
      if (path != null && path.isNotEmpty) {
        final idx = path.lastIndexOf('/');
        if (idx > 0) return path.substring(0, idx);
      }
    } catch (e) {
      debugPrint('[StorageService] getExternalBasePath failed: $e');
    }
    return '/storage/emulated/0';
  }

  /// Đặt đường dẫn lưu file trực tiếp (không qua file picker system)
  @override
  Future<void> setAndSavePath(String path) async {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        debugPrint('[StorageService] cannot create $path: $e');
        return; // giữ path cũ, không lưu thư mục không tạo được
      }
    }
    _downloadPath = path;
    await _savePath(path);
    debugPrint('[StorageService] Path set to: $_downloadPath');
  }

  // ── Pickers ────────────────────────────────────────────────────────────────

  /// Chỉ mở picker; caller quyết định có lưu hay không (analyze lưu ngay,
  /// format giữ pending tới lúc bấm tải). Trả null khi user huỷ.
  @override
  Future<String?> pickDirectory({String? initialDirectory}) async {
    await requestStoragePermission();
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Chọn thư mục lưu file',
      initialDirectory: initialDirectory ?? _downloadPath,
    );
  }

  @override
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Dùng channel thay vì gọi shell — an toàn hơn
      try {
        final sdk = await _channel.invokeMethod<int>('getSdkVersion') ?? 33;
        if (sdk >= 30) {
          return (await Permission.manageExternalStorage.request()).isGranted;
        } else {
          return (await Permission.storage.request()).isGranted;
        }
      } catch (e) {
        debugPrint('[StorageService] getSdkVersion failed: $e');
        return (await Permission.manageExternalStorage.request()).isGranted;
      }
    }
    return true;
  }

  @override
  Future<void> openDownloadFolder() async {
    try {
      await _channel.invokeMethod('openFolder', {'path': downloadPath});
    } on PlatformException catch (e) {
      debugPrint('[StorageService] openFolder error: ${e.message}');
      // Không crash app — lỗi mở folder không critical
    }
  }
}