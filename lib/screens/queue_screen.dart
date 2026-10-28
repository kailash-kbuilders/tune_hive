import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/sheets.dart';
import '../widgets/song_tile.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final songs = player.songs;

    return Scaffold(
      body: GradientBg(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Queue', style: Theme.of(context).textTheme.titleLarge),
                          Text(
                            '${songs.length} songs · drag karke order badlo',
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: songs.isEmpty
                    ? const EmptyState(
                        icon: Icons.queue_music_rounded,
                        title: 'Queue khali hai',
                        message: 'Koi gaana play karo — uske baad queue yahan dikhegi.',
                      )
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: songs.length,
                        onReorder: player.reorderQueue,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return KeyedSubtree(
                            key: ValueKey('${song.id}-$index'),
                            child: SongTile(
                              song: song,
                              isCurrent: player.current?.id == song.id,
                              onTap: () => player.playAt(index),
                              onMore: () => showSongMenu(context, song),
                            ),
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
