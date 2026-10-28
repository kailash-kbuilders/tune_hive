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

/// A plain list of songs — used for "See all", genres, recents and playlists.
class SongListScreen extends StatelessWidget {
  const SongListScreen({
    super.key,
    required this.title,
    required this.songs,
    this.subtitle,
    this.emptyMessage = 'Yahan abhi koi gaana nahi hai.',
  });

  final String title;
  final List<Song> songs;
  final String? subtitle;
  final String emptyMessage;

  Future<void> _play(BuildContext context, int index) async {
    final player = context.read<PlayerService>();
    final library = context.read<LibraryService>();
    unawaited(player.playSongs(songs, index));
    unawaited(library.addRecent(songs[index]));
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    return Scaffold(
      body: GradientBg(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
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
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge),
                          if (subtitle != null)
                            Text(subtitle!,
                                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    if (songs.isNotEmpty)
                      IconButton(
                        onPressed: () => _play(context, 0),
                        icon: const Icon(Icons.play_circle_fill_rounded,
                            size: 34, color: AppColors.lime),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: songs.isEmpty
                    ? EmptyState(
                        icon: Icons.music_note_rounded,
                        title: 'Kuch nahi mila',
                        message: emptyMessage,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 160),
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return SongTile(
                            song: song,
                            isCurrent: player.current?.id == song.id,
                            onTap: () => _play(context, index),
                            onMore: () => showSongMenu(context, song),
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
