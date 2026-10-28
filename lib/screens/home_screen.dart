import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/device_music_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork.dart';
import '../widgets/category_chips.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/section_header.dart';
import '../widgets/sheets.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';
import 'song_list_screen.dart';

const List<String> kCategories = [
  'All',
  'Hindi',
  'Punjabi',
  'Tamil',
  'Ghazal',
  'Bhakti',
  'Party',
  'Chill',
  'Hip-Hop',
  'Sad',
  'Jazz',
  'Focus',
  'Blues',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _category = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceMusicService>().load();
    });
  }

  List<Song> _filter(List<Song> songs) {
    if (_category == 'All') return songs;
    final query = _category.toLowerCase();
    return songs
        .where((song) =>
            song.title.toLowerCase().contains(query) ||
            (song.album ?? '').toLowerCase().contains(query) ||
            song.artist.toLowerCase().contains(query))
        .toList();
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceMusicService>();
    final library = context.watch<LibraryService>();
    final songs = _filter(device.songs);
    final recent = library.recent.take(4).toList();

    return GradientBg(
      child: RefreshIndicator(
        color: AppColors.lime,
        backgroundColor: AppColors.card,
        onRefresh: () => device.load(force: true),
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 230),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _header(library),
            const SectionHeader(title: 'Select Categories'),
            CategoryChips(
              categories: kCategories,
              selected: _category,
              onSelected: (value) => setState(() => _category = value),
            ),
            SectionHeader(
              title: _category == 'All' ? 'Popular Songs' : _category,
              actionLabel: songs.isEmpty ? null : 'See all',
              onAction: songs.isEmpty
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SongListScreen(
                          title: _category == 'All' ? 'Popular Songs' : _category,
                          subtitle: '${songs.length} tracks · device',
                          songs: songs,
                        ),
                      )),
            ),
            _songRow(device, songs),
            if (recent.isNotEmpty) ...[
              SectionHeader(
                title: 'Recently Played',
                actionLabel: 'History',
                onAction: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SongListScreen(
                    title: 'History',
                    subtitle: '${library.recent.length} tracks',
                    songs: library.recent,
                    emptyMessage: 'Abhi tak kuch suna nahi.',
                  ),
                )),
              ),
              ...recent.asMap().entries.map((entry) => SongTile(
                    song: entry.value,
                    onTap: () => _play(recent, entry.key),
                    onMore: () => showSongMenu(context, entry.value),
                  )),
            ],
            if (songs.length > 12)
              SectionHeader(
                title: 'All songs',
                actionLabel: '${songs.length}',
                onAction: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SongListScreen(
                    title: 'All songs',
                    subtitle: '${songs.length} tracks · device',
                    songs: songs,
                  ),
                )),
              ),
            if (songs.length > 12)
              ...songs
                  .take(15)
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) => SongTile(
                        song: entry.value,
                        onTap: () => _play(songs, entry.key),
                        onMore: () => showSongMenu(context, entry.value),
                      )),
          ],
        ),
      ),
    );
  }

  Widget _header(LibraryService library) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 14, 0),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line),
            ),
            child: Image.asset('assets/images/logo.png'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(), style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(
                  library.listenerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => showSleepSheet(context),
            icon: const Icon(Icons.nightlight_round, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _songRow(DeviceMusicService device, List<Song> songs) {
    if (device.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
      );
    }
    if (device.permissionDenied) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Music access chahiye',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                'TuneHive ko sirf audio files padhni hain. Internet, camera ya location — kuch nahi maanga jaata.',
                style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => device.load(force: true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.lime,
                  foregroundColor: const Color(0xFF10160A),
                ),
                child: const Text('Allow access'),
              ),
            ],
          ),
        ),
      );
    }
    if (songs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.songs.isEmpty ? 'Device me gaane nahi mile' : 'Is category me kuch nahi',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                device.songs.isEmpty
                    ? '30 second se lambi audio files hi dikhti hain. Phone me gaane download karke app dobara kholo.'
                    : '"All" select karke saare gaane dekh lo.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 204,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: songs.take(12).length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = songs[index];
          return GestureDetector(
            onTap: () => _play(songs, index),
            child: SizedBox(
              width: 148,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SongArtwork(song: song, size: 148, radius: 20),
                  const SizedBox(height: 10),
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    song.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
