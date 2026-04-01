// // lib/services/audio_extract_service.dart
//
// import 'dart:io';
// import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_audio/return_code.dart';
// import 'package:flutter/foundation.dart';
//
// class AudioExtractResult {
//   final bool success;
//   final String? outputPath;
//   final String? error;
//
//   const AudioExtractResult({
//     required this.success,
//     this.outputPath,
//     this.error,
//   });
// }
//
// class AudioExtractService {
//   AudioExtractService._();
//   static final AudioExtractService instance = AudioExtractService._();
//
//   /// Extract audio từ video file
//   /// [inputPath]: đường dẫn file video (.mp4)
//   /// [outputExt]: 'm4a' hoặc 'mp3'
//   Future<AudioExtractResult> extractAudio({
//     required String inputPath,
//     String outputExt = 'm4a',
//     void Function(double progress)? onProgress,
//   }) async {
//     // Tạo output path: thay đuôi file
//     final outputPath = inputPath.replaceAll(
//       RegExp(r'\.[^.]+$'),
//       '.$outputExt',
//     );
//
//     // Xóa file cũ nếu tồn tại
//     final outputFile = File(outputPath);
//     if (outputFile.existsSync()) outputFile.deleteSync();
//
//     debugPrint('[AudioExtract] $inputPath → $outputPath');
//
//     // ffmpeg command:
//     // -i input.mp4       → input file
//     // -vn                → bỏ video stream
//     // -acodec copy       → copy audio không re-encode (nhanh, không mất chất)
//     // output.m4a
//     final command = '-i "$inputPath" -vn -acodec copy "$outputPath"';
//
//     final session = await FFmpegKit.execute(command);
//     final returnCode = await session.getReturnCode();
//
//     if (ReturnCode.isSuccess(returnCode)) {
//       debugPrint('[AudioExtract] Thành công: $outputPath');
//
//       // Xóa file video gốc sau khi extract xong
//       try {
//         File(inputPath).deleteSync();
//       } catch (_) {}
//
//       return AudioExtractResult(success: true, outputPath: outputPath);
//     } else {
//       final logs = await session.getLogsAsString();
//       debugPrint('[AudioExtract] Lỗi: $logs');
//       return AudioExtractResult(
//         success: false,
//         error: 'FFmpeg thất bại: ${returnCode?.getValue()}',
//       );
//     }
//   }
//
//   /// Extract sang MP3 (có re-encode — chậm hơn nhưng tương thích hơn)
//   Future<AudioExtractResult> extractMp3({
//     required String inputPath,
//     int bitrate = 192,
//     void Function(double progress)? onProgress,
//   }) async {
//     final outputPath = inputPath.replaceAll(RegExp(r'\.[^.]+$'), '.mp3');
//     final outputFile = File(outputPath);
//     if (outputFile.existsSync()) outputFile.deleteSync();
//
//     final command =
//         '-i "$inputPath" -vn -acodec libmp3lame -ab ${bitrate}k "$outputPath"';
//
//     final session = await FFmpegKit.execute(command);
//     final returnCode = await session.getReturnCode();
//
//     if (ReturnCode.isSuccess(returnCode)) {
//       try { File(inputPath).deleteSync(); } catch (_) {}
//       return AudioExtractResult(success: true, outputPath: outputPath);
//     } else {
//       final logs = await session.getLogsAsString();
//       return AudioExtractResult(success: false, error: logs);
//     }
//   }
// }