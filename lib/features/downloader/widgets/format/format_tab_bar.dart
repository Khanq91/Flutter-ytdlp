import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';

class FormatTabBar extends StatelessWidget {
  final TabController controller;
  const FormatTabBar({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: c.primaryGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: c.onPlayer,
        unselectedLabelColor: c.textTertiary,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        tabs: const [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note_rounded, size: 16),
                SizedBox(width: 6),
                Text('Audio'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_rounded, size: 16),
                SizedBox(width: 6),
                Text('Video'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
