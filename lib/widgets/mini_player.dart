import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/player_screen.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import 'artwork.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final song = player.current;
    if (song == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: AppColors.cardSoft,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlayerScreen()),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                child: Row(
                  children: [
                    SongArtwork(song: song, size: 42, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: player.previous,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.skip_previous_rounded, size: 22),
                    ),
                    Container(
                      height: 38,
                      width: 38,
                      decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: player.toggle,
                        icon: Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: const Color(0xFF10160A),
                          size: 22,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: player.next,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.skip_next_rounded, size: 22),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: StreamBuilder<Duration>(
                  stream: player.player.positionStream,
                  builder: (context, snapshot) {
                    final total = player.player.duration?.inMilliseconds ?? 0;
                    final pos = snapshot.data?.inMilliseconds ?? 0;
                    final value = total <= 0 ? 0.0 : (pos / total).clamp(0.0, 1.0);
                    return LinearProgressIndicator(
                      value: value,
                      minHeight: 2.5,
                      backgroundColor: const Color(0x1FFFFFFF),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
