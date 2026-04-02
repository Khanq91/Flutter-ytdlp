// // lib/services/audio_extract_service.dart
// // Phương án 1: ffmpeg_kit_flutter_new — fallback khi native MediaExtractor thất bại
//
// import 'dart:io';
// import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_new/return_code.dart';
// import 'package:flutter/foundation.dart';
//
// import 'ytdlp_service.dart';
//
// class AudioExtractService {
//   AudioExtractService._();
//   static final AudioExtractService instance = AudioExtractService._();
//
//   /// Extract audio từ video file, output ra M4A.
//   /// Dùng `-acodec copy` nên không re-encode → nhanh.
//   Future<ExtractAudioResult> extractAudio({
//     required String inputPath,
//     String outputExt = 'm4a',
//   }) async {
//     final outputPath = inputPath.replaceAll(RegExp(r'\.[^.]+$'), '.$outputExt');
//
//     // Xóa output file cũ nếu có
//     final outputFile = File(outputPath);
//     if (outputFile.existsSync()) {
//       try { outputFile.deleteSync(); } catch (_) {}
//     }
//
//     debugPrint('[AudioExtractService] $inputPath → $outputPath');
//
//     // -vn: bỏ video stream
//     // -acodec copy: copy audio không re-encode (AAC, Opus đều OK)
//     final command = '-i "$inputPath" -vn -acodec copy "$outputPath"';
//
//     try {
//       final session    = await FFmpegKit.execute(command);
//       final returnCode = await session.getReturnCode();
//
//       if (ReturnCode.isSuccess(returnCode)) {
//         debugPrint('[AudioExtractService] Thành công: $outputPath');
//
//         // Xóa video gốc sau khi extract xong
//         try { File(inputPath).deleteSync(); } catch (_) {}
//
//         return ExtractAudioResult(success: true, outputPath: outputPath);
//       } else {
//         final logs = await session.getOutput();
//         debugPrint('[AudioExtractService] Lỗi: $logs');
//         return ExtractAudioResult(
//           success: false,
//           error:   'FFmpeg thất bại (code ${returnCode?.getValue()})',
//         );
//       }
//     } catch (e) {
//       return ExtractAudioResult(success: false, error: '$e');
//     }
//   }
// }