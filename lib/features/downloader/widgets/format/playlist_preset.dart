import 'package:flutter/material.dart';
import '../../models/format_option.dart';

class PlaylistPreset {
  final String label;
  final String formatId;
  final String ext;
  final String description;
  final bool isAudioOnly;
  final IconData icon;

  const PlaylistPreset({
    required this.label,
    required this.formatId,
    required this.ext,
    required this.description,
    required this.isAudioOnly,
    required this.icon,
  });

  FormatOption toFormatOption() => FormatOption(
    formatId: formatId,
    ext: ext,
    quality: label,
    isAudioOnly: isAudioOnly,
  );
}

const videoPresets = [
  PlaylistPreset(
    label: 'Tốt nhất',
    formatId: 'bestvideo+bestaudio/best',
    ext: 'mp4',
    description: 'Chất lượng cao nhất có thể',
    isAudioOnly: false,
    icon: Icons.hd_rounded,
  ),
  PlaylistPreset(
    label: '1080p',
    formatId: 'bestvideo[height<=1080]+bestaudio/best[height<=1080]',
    ext: 'mp4',
    description: 'Tối đa Full HD',
    isAudioOnly: false,
    icon: Icons.videocam_rounded,
  ),
  PlaylistPreset(
    label: '720p',
    formatId: 'bestvideo[height<=720]+bestaudio/best[height<=720]',
    ext: 'mp4',
    description: 'HD — dung lượng nhỏ hơn',
    isAudioOnly: false,
    icon: Icons.videocam_outlined,
  ),
  PlaylistPreset(
    label: '480p',
    formatId: 'bestvideo[height<=480]+bestaudio/best[height<=480]',
    ext: 'mp4',
    description: 'Tiết kiệm dung lượng',
    isAudioOnly: false,
    icon: Icons.sd_rounded,
  ),
];

const audioPresets = [
  PlaylistPreset(
    label: 'M4A',
    formatId: 'bestaudio[ext=m4a]',
    ext: 'm4a',
    description: 'Chỉ tải nguồn âm thanh M4A',
    isAudioOnly: true,
    icon: Icons.audio_file_rounded,
  ),
];
