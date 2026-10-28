import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/sheets.dart';
import 'player_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _play(BuildContext context, List<Song> songs, int index) async {
    final player = context.read<PlayerService>();
    final library = context.read<LibraryService>();
    unawaited(player.playSongs(songs, index));
    unawaited(library.addRecent(songs[index]));
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  Future<void> _clear(BuildContext context, LibraryService library) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('History clear karein?', style: TextStyle(fontSize: 15)),
        content: const Text(
          'Sunne ka record hat jayega. Gaane device se delete nahi honge.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) await library.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();
    final songs = library.recent;

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
                          Text('History', style: Theme.of(context).textTheme.titleLarge),
                          Text(
                            '${songs.length} songs${library.topArtist != null ? ' · ${library.topArtist}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (songs.isNotEmpty)
                      IconButton(
                        onPressed: () => _clear(context, library),
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 20, color: AppColors.muted),
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
                        icon: Icons.history_rounded,
                        title: 'History khali hai',
                        message: 'Jo bhi gaana bajega wo yahan aa jayega, saath me kitni baar suna.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          final plays = library.playCount(song);
                          final isCurrent = player.current?.id == song.id;
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _play(context, songs, index),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                                const Icon(Icons.public_rounded,
                                                    size: 11, color: AppColors.muted),
                                                const SizedBox(width: 4),
                                              ],
                                              Flexible(
                                                child: Text(
                                                  song.subtitle,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 11.5, color: AppColors.muted),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (plays > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.cardSoft,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${plays}x',
                                          style: const TextStyle(
                                              fontSize: 10.5, color: AppColors.muted),
                                        ),
                                      ),
                                    IconButton(
                                      onPressed: () => showSongMenu(context, song),
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.more_vert_rounded,
                                          size: 18, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
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
