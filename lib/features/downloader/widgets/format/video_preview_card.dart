import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ytdlp/theme/app_colors_data.dart';
import 'package:flutter_ytdlp/widgets/glass_container.dart';
import '../../models/video_info.dart';

class VideoPreviewCard extends StatelessWidget {
  final VideoInfo info;
  const VideoPreviewCard({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GlassContainer(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (info.thumbnail != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: info.thumbnail!,
                  width: 80,
                  height: 52,
                  fit: BoxFit.cover,
                  errorWidget:
                      (_, __, ___) => Container(
                        width: 80,
                        height: 52,
                        color: c.surfaceElevated,
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: c.textTertiary,
                          size: 20,
                        ),
                      ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    info.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    info.type == VideoType.playlist
                        ? '${info.playlistCount ?? "?"} video'
                        : info.platform.displayName,
                    style: TextStyle(
                      color: c.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
