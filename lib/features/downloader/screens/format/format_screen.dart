// lib/screens/format/format_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';
import '../../models/format_option.dart';
import '../../models/playlist_entry.dart';
import '../../models/video_info.dart';
import '../../providers/download_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/format/bottom_download_bar.dart';
import '../../widgets/format/extract_audio_tile.dart';
import '../../widgets/format/format_empty_label.dart';
import '../../widgets/format/format_folder_sheet.dart';
import '../../widgets/format/format_tab_bar.dart';
import '../../widgets/format/format_tile.dart';
import '../../widgets/format/playlist_preset.dart';
import '../../widgets/format/playlist_preset_list.dart';
import '../../widgets/format/synthetic_formats.dart';
import '../../widgets/format/video_preview_card.dart';
import '../../widgets/gradient_background.dart';
import 'package:flutter_ytdlp/widgets/reveal_list/reveal_list.dart';

// ── Screen ─────────────────────────────────────────────────

class FormatScreen extends ConsumerStatefulWidget {
  final VideoInfo videoInfo;
  final List<PlaylistEntry>? selectedEntries;

  const FormatScreen({
    super.key,
    required this.videoInfo,
    this.selectedEntries,
  });

  @override
  ConsumerState<FormatScreen> createState() => _FormatScreenState();
}

class _FormatScreenState extends ConsumerState<FormatScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  FormatOption? _selectedFormat;
  PlaylistPreset? _selectedPreset;
  bool _isAudioTab = true;
  bool _submitting = false;

  String? _pendingOutputPath;

  bool get _isPlaylist => widget.videoInfo.type == VideoType.playlist;

  /// Folder shown in the bottom bar: the pending pick, else the saved one.
  /// For callbacks; [build] watches the provider so the bar stays in sync.
  String get _currentPath =>
      _pendingOutputPath ??
      ref.read(downloadOutputDirectoryProvider).value ??
      '';

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _isPlaylist ? 1 : 0,
    );
    _isAudioTab = !_isPlaylist;

    if (_isPlaylist) {
      _selectedPreset = videoPresets[1];
    } else {
      _selectedFormat =
          widget.videoInfo.bestAudioFormat ?? kExtractAudioFormat;
    }

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _isAudioTab = _tabController.index == 0;
          if (_isPlaylist) {
            _selectedPreset =
                _isAudioTab ? audioPresets.first : videoPresets[1];
          } else {
            if (_isAudioTab) {
              _selectedFormat =
                  widget.videoInfo.bestAudioFormat ?? kExtractAudioFormat;
            } else {
              _selectedFormat = _bestVideoFormat;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<FormatOption> get _audioFormats {
    final list = widget.videoInfo.audioFormats.toList();
    list.sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
    return list;
  }

  List<FormatOption> get _videoFormats {
    final formats = widget.videoInfo.videoFormats;
    final Map<int, FormatOption> byHeight = {};
    for (final f in formats) {
      final h = f.height ?? 0;
      if (!byHeight.containsKey(h) ||
          (byHeight[h]!.filesize ?? 0) < (f.filesize ?? 0)) {
        byHeight[h] = f;
      }
    }
    return byHeight.values.toList()
      ..sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
  }

  FormatOption? get _bestVideoFormat =>
      _videoFormats.isNotEmpty ? _videoFormats.first : null;

  bool get _isMuxedOnly => _audioFormats.isEmpty && _videoFormats.isNotEmpty;

  Future<void> _showPathPickerSheet() async {
    final base = await ref.read(downloadExternalBasePathProvider.future);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => FormatFolderSheet(
            basePath: base,
            currentPath: _currentPath,
            onSelect: (path) {
              setState(() => _pendingOutputPath = path);
            },
            onCustomPick: () async {
              // Not saved yet: the folder is persisted when the download starts.
              final picked = await ref
                  .read(downloadOutputDirectoryProvider.notifier)
                  .pickDirectory(save: false, initialDirectory: _currentPath);
              if (picked != null && mounted) {
                setState(() => _pendingOutputPath = picked);
              }
            },
          ),
    );
  }

  Future<void> _startDownload() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _doStartDownload();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _doStartDownload() async {
    final format =
        _isPlaylist ? _selectedPreset?.toFormatOption() : _selectedFormat;
    if (format == null) return;

    // Pending folder is saved here, at confirm time, not when it was picked.
    final outcome = await ref
        .read(downloadProvider.notifier)
        .startFromFormat(
          info: widget.videoInfo,
          format: format,
          selectedEntries: widget.selectedEntries,
          outputPath: _pendingOutputPath,
        );
    if (!mounted) return;

    if (outcome == DownloadStartOutcome.startedWithoutNotification) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tải nền vẫn tiếp tục, nhưng tiến trình có thể không hiện trong thông báo.',
          ),
        ),
      );
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.download,
      (route) => route.settings.name == AppRoutes.analyze,
    );
  }

  bool get _canDownload =>
      _isPlaylist ? _selectedPreset != null : _selectedFormat != null;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final savedPath = ref.watch(
      downloadOutputDirectoryProvider.select((dir) => dir.value),
    );
    final currentPath = _pendingOutputPath ?? savedPath ?? '';

    return GradientBackground(
      child: AppShell(
        appBar: AppBar(
          title: const Text('Chọn định dạng'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        child: Column(
          children: [
            VideoPreviewCard(info: widget.videoInfo),

            if (widget.videoInfo.skippedCount != null &&
                widget.videoInfo.skippedCount! > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: c.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 15,
                        color: c.warning,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.videoInfo.skippedCount} video không khả dụng sẽ bị bỏ qua',
                        style: TextStyle(
                          color: c.warning,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FormatTabBar(controller: _tabController),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children:
                    _isPlaylist
                        ? [
                          PlaylistPresetList(
                            presets: audioPresets,
                            selected: _selectedPreset,
                            onSelect:
                                (p) => setState(() => _selectedPreset = p),
                          ),
                          PlaylistPresetList(
                            presets: videoPresets,
                            selected: _selectedPreset,
                            onSelect:
                                (p) => setState(() => _selectedPreset = p),
                          ),
                        ]
                        : [
                          // ── Audio tab ──
                          RevealList.children(
                            itemSpacing: 0,
                            showEdgeFades: false,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            children:
                                _isMuxedOnly
                                    ? [
                                      ExtractAudioTile(
                                        selectedFormatId:
                                            _selectedFormat?.formatId,
                                        onSelectAudio:
                                            () => setState(
                                              () =>
                                                  _selectedFormat =
                                                      kExtractAudioFormat,
                                            ),
                                        onSelectVideo:
                                            () => setState(
                                              () =>
                                                  _selectedFormat =
                                                      kMuxedVideoFormat,
                                            ),
                                      ),
                                    ]
                                    : _audioFormats.isEmpty
                                    ? [
                                      const FormatEmptyLabel(
                                        label: 'Không có định dạng audio',
                                      ),
                                    ]
                                    : _audioFormats
                                        .map(
                                          (f) => FormatTile(
                                            format: f,
                                            isSelected:
                                                _selectedFormat?.formatId ==
                                                f.formatId,
                                            onTap:
                                                () => setState(
                                                  () => _selectedFormat = f,
                                                ),
                                          ),
                                        )
                                        .toList(),
                          ),
                          // ── Video tab ──
                          RevealList.children(
                            itemSpacing: 0,
                            showEdgeFades: false,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            children:
                                _videoFormats.isEmpty
                                    ? [
                                      const FormatEmptyLabel(
                                        label: 'Không có định dạng video',
                                      ),
                                    ]
                                    : _videoFormats
                                        .map(
                                          (f) => FormatTile(
                                            format: f,
                                            isSelected:
                                                _selectedFormat?.formatId ==
                                                f.formatId,
                                            onTap:
                                                () => setState(
                                                  () => _selectedFormat = f,
                                                ),
                                          ),
                                        )
                                        .toList(),
                          ),
                        ],
              ),
            ),

            BottomDownloadBar(
              selectedFormat: _selectedFormat,
              selectedPreset: _selectedPreset,
              isPlaylist: _isPlaylist,
              playlistCount: widget.videoInfo.playlistCount,
              currentPath: currentPath,
              onPickFolder: _showPathPickerSheet,
              isSubmitting: _submitting,
              onDownload:
                  _canDownload && !_submitting ? _startDownload : null,
            ),
          ],
        ),
      ),
    );
  }
}
