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

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

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
    final songs = library.favourites;

    return GradientBg(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Favourites',
                            style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text('${songs.length} songs',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  if (songs.isNotEmpty)
                    IconButton(
                      onPressed: () => _play(context, songs, 0),
                      icon: const Icon(Icons.play_circle_fill_rounded,
                          size: 40, color: AppColors.lime),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: songs.isEmpty
                  ? const EmptyState(
                      icon: Icons.favorite_border_rounded,
                      title: 'Abhi kuch favourite nahi',
                      message:
                          'Kisi bhi gaane ke ⋮ menu se "Add to favourites" dabao — wo yahan aa jayega.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 4, bottom: 200),
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return Dismissible(
                          key: ValueKey(song.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            color: AppColors.cardSoft,
                            child: const Icon(Icons.heart_broken_rounded,
                                color: AppColors.danger, size: 20),
                          ),
                          onDismissed: (_) => library.toggleFavourite(song),
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
    );
  }
}
