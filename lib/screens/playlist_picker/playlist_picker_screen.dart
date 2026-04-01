// lib/screens/playlist_picker/playlist_picker_screen.dart

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../models/playlist_entry.dart';
import '../../models/video_info.dart';
import '../../services/ytdlp_service.dart';
import '../../utils/vietnamese_normalize.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/primary_button.dart';

class PlaylistPickerScreen extends ConsumerStatefulWidget {
  final VideoInfo playlistInfo;

  const PlaylistPickerScreen({super.key, required this.playlistInfo});

  @override
  ConsumerState<PlaylistPickerScreen> createState() =>
      _PlaylistPickerScreenState();
}

class _PlaylistPickerScreenState extends ConsumerState<PlaylistPickerScreen> {
  List<PlaylistEntry> _entries = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  List<PlaylistEntry> get _filteredEntries {
    if (_searchQuery.isEmpty) return _entries;

    final query = VNnormalize(_searchQuery);

    return _entries.where((e) {
      final title = VNnormalize(e.title);
      return title.contains(query);
    }).toList();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await YtdlpService.instance
        .getPlaylistEntries(widget.playlistInfo.url);

    if (!mounted) return;

    switch (result) {
      case PlaylistEntriesSuccess(:final entries):
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      case PlaylistEntriesFailure(:final message):
        setState(() {
          _error = message;
          _isLoading = false;
        });
    }
  }

  // ── Selection helpers ──────────────────────────────────

  int get _selectedCount => _entries.where((e) => e.selected).length;
  bool get _allSelected => _entries.isNotEmpty && _entries.every((e) => e.selected);

  void _toggleEntry(int index) {
    setState(() {
      _entries[index] = _entries[index].copyWith(
        selected: !_entries[index].selected,
      );
    });
  }

  void _selectAll() {
    setState(() {
      _entries = _entries.map((e) => e.copyWith(selected: true)).toList();
    });
  }

  void _deselectAll() {
    setState(() {
      _entries = _entries.map((e) => e.copyWith(selected: false)).toList();
    });
  }

  void _proceed() {
    final selected = _entries.where((e) => e.selected).toList();
    if (selected.isEmpty) return;

    // Tạo VideoInfo mới với url là danh sách các url được chọn
    // Truyền sang FormatScreen kèm selectedEntries
    Navigator.pushNamed(
      context,
      AppRoutes.format,
      arguments: FormatScreenArgs(
        videoInfo: widget.playlistInfo.copyWith(
          playlistCount: selected.length,
        ),
        selectedEntries: selected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: AppShell(
        appBar: AppBar(
          title: Text(
            widget.playlistInfo.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        child: Column(
          children: [
            // ── Toolbar: select all / count ──────────────
            if (!_isLoading && _error == null)
              _SelectionToolbar(
                total: _entries.length,
                selectedCount: _selectedCount,
                allSelected: _allSelected,
                onSelectAll: _selectAll,
                onDeselectAll: _deselectAll,
              ),
            // ── SEARCH ───────────────────────────────────
            if (!_isLoading && _error == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Tìm video...',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            // ── Body ─────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? const _LoadingState()
                  : _error != null
                  ? _ErrorState(
                message: _error!,
                onRetry: _loadEntries,
              )
                  : _EntryList(
                entries: _filteredEntries,
                onToggle: (index) {
                  final realIndex = _entries.indexOf(_filteredEntries[index]);
                  _toggleEntry(realIndex);
                },
              ),
            ),

            // ── Bottom bar ───────────────────────────────
            if (!_isLoading && _error == null)
              _BottomBar(
                selectedCount: _selectedCount,
                total: _entries.length,
                onProceed: _selectedCount > 0 ? _proceed : null,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Toolbar ────────────────────────────────────────────────

class _SelectionToolbar extends StatelessWidget {
  final int total;
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onSelectAll;
  final VoidCallback onDeselectAll;

  const _SelectionToolbar({
    required this.total,
    required this.selectedCount,
    required this.allSelected,
    required this.onSelectAll,
    required this.onDeselectAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            'Đã chọn $selectedCount / $total Video hợp lệ',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: allSelected ? onDeselectAll : onSelectAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                allSelected ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Entry List ─────────────────────────────────────────────

class _EntryList extends StatelessWidget {
  final List<PlaylistEntry> entries;
  final void Function(int index) onToggle;

  const _EntryList({required this.entries, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _EntryTile(
          entry: entries[index],
          index: index + 1,
          onTap: () => onToggle(index),
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  final PlaylistEntry entry;
  final int index;
  final VoidCallback onTap;

  const _EntryTile({
    required this.entry,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: entry.selected
              ? AppColors.primary.withOpacity(0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: entry.selected
                ? AppColors.primary.withOpacity(0.4)
                : AppColors.border,
            width: entry.selected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: entry.selected ? AppColors.primaryGradient : null,
                border: entry.selected
                    ? null
                    : Border.all(color: AppColors.textTertiary, width: 1.5),
              ),
              child: entry.selected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 10),

            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: entry.thumbnail != null
                  ? CachedNetworkImage(
                imageUrl: entry.thumbnail!,
                width: 72,
                height: 46,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _ThumbnailPlaceholder(index: index),
              )
                  : _ThumbnailPlaceholder(index: index),
            ),
            const SizedBox(width: 10),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: entry.selected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                  if (entry.formattedDuration.isNotEmpty ||
                      entry.uploader?.isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (entry.formattedDuration.isNotEmpty)
                          Text(
                            entry.formattedDuration,
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        if (entry.formattedDuration.isNotEmpty &&
                            entry.uploader?.isNotEmpty == true)
                          const Text(
                            ' · ',
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                        if (entry.uploader?.isNotEmpty == true)
                          Expanded(
                            child: Text(
                              entry.uploader!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailPlaceholder extends StatelessWidget {
  final int index;
  const _ThumbnailPlaceholder({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 46,
      color: AppColors.surfaceElevated,
      child: Center(
        child: Text(
          '$index',
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Loading / Error states ─────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
          SizedBox(height: 16),
          Text(
            'Đang tải danh sách video...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Color(0xFFFF3B30), size: 40),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: GestureDetector(
                onTap: onRetry,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh_rounded,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Thử lại',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom Bar ─────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final int selectedCount;
  final int total;
  final VoidCallback? onProceed;

  const _BottomBar({
    required this.selectedCount,
    required this.total,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 12, 20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        border: const Border(
            top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedCount < total)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 13, color: AppColors.textTertiary),
                  const SizedBox(width: 5),
                  Text(
                    '${total - selectedCount} video bị bỏ qua',
                    style: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
          PrimaryButton(
            label: 'Tiếp theo ($selectedCount video)',
            icon: Icons.arrow_forward_rounded,
            onPressed: onProceed,
          ),
        ],
      ),
    );
  }
}