import '../../models/format_option.dart';

// ── Synthetic format cho tách audio (TikTok / Instagram muxed video) ─────────

const kExtractAudioFormatId = '__extract_audio__';
const kMuxedVideoFormatId = '__muxed_video__';

final kExtractAudioFormat = FormatOption(
  formatId: kExtractAudioFormatId,
  ext: 'm4a',
  quality: 'Tách từ video',
  isAudioOnly: true,
);
const kMuxedVideoFormat = FormatOption(
  formatId: kMuxedVideoFormatId,
  ext: 'mp4',
  quality: 'Video gốc',
  isAudioOnly: false,
);
