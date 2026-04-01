// lib/services/storage_service.dart

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  // ✅ Channel phải khớp với MainActivity
  static const _channel = MethodChannel('ytdlp_channel');

  String? _downloadPath;

  // ❌ Bỏ hoàn toàn _ytdlpPath — project dùng Chaquopy, không có libytdlp.so
  // yt-dlp chạy qua Python module, không phải native binary

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
    } catch (_) {
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

  Future<String?> pickDownloadDirectory() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      final manageStatus = await Permission.manageExternalStorage.request();
      if (!manageStatus.isGranted) return null;
    }

    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Chọn thư mục lưu file',
      initialDirectory: _downloadPath,
    );

    if (result != null) {
      _downloadPath = result;
      await _savePath(result);
    }
    return _downloadPath;
  }

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
      } catch (_) {
        return (await Permission.manageExternalStorage.request()).isGranted;
      }
    }
    return true;
  }

  Future<void> openDownloadFolder() async {
    try {
      await _channel.invokeMethod('openFolder', {'path': downloadPath});
    } on PlatformException catch (e) {
      debugPrint('[StorageService] openFolder error: ${e.message}');
      // Không crash app — lỗi mở folder không critical
    }
  }
}