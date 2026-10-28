import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/sheets.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';

class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.name});

  final String name;

  Future<void> _play(BuildContext context, List<Song> songs, int index) async {
    final player = context.read<PlayerService>();
    final library = context.read<LibraryService>();
    unawaited(player.playSongs(songs, index));
    unawaited(library.addRecent(songs[index]));
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();
    final songs = library.playlist(name);

    return Scaffold(
      body: GradientBg(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 4),
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
                          Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge),
                          Text('${songs.length} songs',
                              style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    if (songs.isNotEmpty)
                      IconButton(
                        onPressed: () => _play(context, songs, 0),
                        icon: const Icon(Icons.play_circle_fill_rounded,
                            size: 34, color: AppColors.lime),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: songs.isEmpty
                    ? const EmptyState(
                        icon: Icons.playlist_add_rounded,
                        title: 'Playlist khali hai',
                        message:
                            'Kisi gaane ke ⋮ menu se "Add to playlist" chuno — wo yahan aa jayega.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return Dismissible(
                            key: ValueKey('${song.id}-$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              color: AppColors.cardSoft,
                              child: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.danger, size: 20),
                            ),
                            onDismissed: (_) => library.removeFromPlaylist(name, song),
                            child: SongTile(
                              song: song,
                              isCurrent: player.current?.id == song.id,
                              onTap: () => _play(context, songs, index),
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
