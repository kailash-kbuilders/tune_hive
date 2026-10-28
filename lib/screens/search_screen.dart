import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/device_music_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/sheets.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _play(List<Song> songs, int index) async {
    if (songs.isEmpty || index >= songs.length) return;
    final player = context.read<PlayerService>();
    final library = context.read<LibraryService>();
    await player.playSongs(songs, index);
    await library.addRecent(songs[index]);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceMusicService>();
    final player = context.watch<PlayerService>();
    final results = device.search(_query);

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
                    child: Text('Search', style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  Text(
                    '${device.songs.length} songs',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 20, color: AppColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onChanged: (value) => setState(() => _query = value),
                        style: const TextStyle(fontSize: 13.5),
                        decoration: const InputDecoration(
                          hintText: 'Gaana, artist ya album',
                          hintStyle: TextStyle(color: AppColors.muted, fontSize: 13),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: results.isEmpty
                  ? EmptyState(
                      icon: Icons.phone_android_rounded,
                      title: _query.isEmpty ? 'Apne gaane dhoondo' : 'Kuch nahi mila',
                      message: _query.isEmpty
                          ? 'Device ke saare gaane yahan search ho sakte hain — title, artist ya album se.'
                          : 'Doosra naam ya artist try karo.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 220),
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final song = results[index];
                        return SongTile(
                          song: song,
                          isCurrent: player.current?.id == song.id,
                          onTap: () => _play(results, index),
                          onMore: () => showSongMenu(context, song),
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
