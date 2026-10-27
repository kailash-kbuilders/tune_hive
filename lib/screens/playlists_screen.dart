import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/sheets.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final library = context.read<LibraryService>();
    final name = await promptForPlaylistName(context);
    if (name == null) return;
    await library.createPlaylist(name);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlaylistDetailScreen(name: name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final names = library.playlistNames;

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
                      child: Text('Playlists', style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                      onPressed: () => _create(context),
                      icon: const Icon(Icons.add_rounded, size: 24, color: AppColors.lime),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: names.isEmpty
                    ? EmptyState(
                        icon: Icons.queue_music_rounded,
                        title: 'Koi playlist nahi',
                        message: 'Apni playlist banao aur gaane usme jama karo.',
                        actionLabel: 'Playlist banao',
                        onAction: () => _create(context),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: names.length,
                        itemBuilder: (context, index) {
                          final name = names[index];
                          final songs = library.playlist(name);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              radius: 18,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => PlaylistDetailScreen(name: name),
                              )),
                              child: Row(
                                children: [
                                  Container(
                                    height: 44,
                                    width: 44,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF3B4D1F), Color(0xFF1B2410)],
                                      ),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Icon(Icons.queue_music_rounded,
                                        size: 20, color: AppColors.lime),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13.5, fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 2),
                                        Text('${songs.length} songs',
                                            style: const TextStyle(
                                                fontSize: 11, color: AppColors.muted)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _confirmDelete(context, library, name),
                                    icon: const Icon(Icons.delete_outline_rounded,
                                        size: 18, color: AppColors.muted),
                                  ),
                                ],
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

  Future<void> _confirmDelete(BuildContext context, LibraryService library, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('"$name" delete karein?', style: const TextStyle(fontSize: 15)),
        content: const Text('Playlist hat jayegi, gaane device me rahenge.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) await library.deletePlaylist(name);
  }
}
