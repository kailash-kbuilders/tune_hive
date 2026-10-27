import 'package:flutter/material.dart';

import '../models/song.dart';
import '../theme/app_theme.dart';
import 'artwork.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onMore,
    this.isCurrent = false,
    this.showDuration = true,
  });

  final Song song;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final bool isCurrent;
  final bool showDuration;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              SongArtwork(song: song, size: 52, radius: 14),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: isCurrent ? AppColors.lime : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (song.isOnline) ...[
                          const Icon(Icons.public_rounded, size: 11, color: AppColors.muted),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            song.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (showDuration)
                Text(
                  song.durationLabel,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              if (onMore != null)
                IconButton(
                  onPressed: onMore,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
