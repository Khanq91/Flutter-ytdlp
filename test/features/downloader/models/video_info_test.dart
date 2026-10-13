import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ytdlp/features/downloader/models/format_option.dart';
import 'package:flutter_ytdlp/features/downloader/models/video_info.dart';

void main() {
  test('audio download choices exclude WebM containers', () {
    final info = VideoInfo(
      id: 'video',
      title: 'Video',
      platform: VideoPlatform.youtube,
      type: VideoType.video,
      skippedCount: 0,
      formats: const [
        FormatOption(
          formatId: '251',
          ext: 'webm',
          quality: '160kbps',
          isAudioOnly: true,
          bitrate: 160,
        ),
        FormatOption(
          formatId: '140',
          ext: 'm4a',
          quality: '128kbps',
          isAudioOnly: true,
          bitrate: 128,
        ),
      ],
      url: 'https://example.com/video',
    );

    expect(info.audioFormats.map((format) => format.ext), ['m4a']);
    expect(info.bestAudioFormat?.ext, 'm4a');
  });
}
