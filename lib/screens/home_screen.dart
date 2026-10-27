import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/device_music_service.dart';
import '../services/library_service.dart';
import '../services/online_music_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork.dart';
import '../widgets/category_chips.dart';
import '../widgets/empty_state.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/section_header.dart';
import '../widgets/sheets.dart';
import '../widgets/song_tile.dart';
import 'player_screen.dart';
import 'song_list_screen.dart';

const List<String> kCategories = [
  'All',
  'Party',
  'Blues',
  'Sad',
  'Hip-Hop',
  'Chill',
  'Jazz',
  'Focus',
];

class _Collection {
  const _Collection(this.title, this.query, this.caption);
  final String title;
  final String query;
  final String caption;
}

const List<_Collection> kCollections = [
  _Collection('Top Songs Global', 'pop', 'Popular worldwide'),
  _Collection('Chill & Lo-Fi', 'lofi', 'Slow down a little'),
  _Collection('Jazz Nights', 'jazz', 'Late night listening'),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _category = 'All';
  List<Song> _online = [];
  bool _onlineLoading = false;
  String? _onlineError;
  String? _busyQuery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final device = context.read<DeviceMusicService>();
      device.load().then((_) {
        if (!mounted) return;
        if (device.songs.isEmpty) _loadOnline();
      });
    });
  }

  Future<void> _loadOnline({String? genre}) async {
    if (_onlineLoading) return;
    setState(() {
      _onlineLoading = true;
      _onlineError = null;
    });
    try {
      final songs = await context.read<OnlineMusicService>().browse(
            genre: genre ?? (_category == 'All' ? null : _category),
            limit: 12,
          );
      if (!mounted) return;
      setState(() => _online = songs);
    } on OnlineUnavailable {
      if (!mounted) return;
      setState(() => _onlineError = 'Internet nahi hai — abhi device ke gaane chal rahe hain.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _onlineError = 'Online songs load nahi hue. Dobara try karo.');
    } finally {
      if (mounted) setState(() => _onlineLoading = false);
    }
  }

  List<Song> _filter(List<Song> songs) {
    if (_category == 'All') return songs;
    final q = _category.toLowerCase();
    return songs
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            (s.album ?? '').toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _play(BuildContext context, List<Song> songs, int index) async {
    final player = context.read<PlayerService>();
    final library = context.read<LibraryService>();
    await player.playSongs(songs, index);
    await library.addRecent(songs[index]);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  Future<void> _openCollection(_Collection collection) async {
    setState(() => _busyQuery = collection.query);
    try {
      final songs = await context.read<OnlineMusicService>().search(collection.query, limit: 24);
      if (!mounted) return;
      if (songs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Is collection me abhi kuch nahi mila')),
        );
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SongListScreen(
          title: collection.title,
          subtitle: '${songs.length} tracks · Internet Archive',
          songs: songs,
        ),
      ));
    } on OnlineUnavailable {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Internet nahi hai — collection ke liye net chahiye')),
      );
    } finally {
      if (mounted) setState(() => _busyQuery = null);
    }
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
    final popular = _filter(device.songs);
    final recent = library.recent.take(5).toList();

    return GradientBg(
      child: RefreshIndicator(
        color: AppColors.lime,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          await device.load(force: true);
          await _loadOnline();
        },
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 200),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 14, 0),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    padding: const EdgeInsets.all(9),
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
                        Text(_greeting(),
                            style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
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
            ),
            const SectionHeader(title: 'Select Categories'),
            CategoryChips(
              categories: kCategories,
              selected: _category,
              onSelected: (value) {
                setState(() => _category = value);
                if (_online.isEmpty && value != 'All') _loadOnline(genre: value);
              },
            ),
            SectionHeader(
              title: 'Popular Songs',
              actionLabel: popular.isEmpty ? null : 'See all',
              onAction: popular.isEmpty
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SongListScreen(
                          title: 'Popular Songs',
                          subtitle: '${popular.length} tracks · device',
                          songs: popular,
                        ),
                      )),
            ),
            if (device.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
              )
            else if (device.permissionDenied)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Music access chahiye',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text(
                        'TuneHive ko sirf audio files padhni hain — iske alawa koi permission nahi maangi jaati.',
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
              )
            else if (popular.isEmpty)
              Padding(
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
                            ? '30 second se lambi audio files hi dikhti hain. Internet wale section se free songs bhi chala sakte ho.'
                            : '"All" select karke saare gaane dekh lo.',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 204,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: popular.take(12).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final song = popular[index];
                    return GestureDetector(
                      onTap: () => _play(context, popular, index),
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
              ),
            SectionHeader(title: 'New Collection'),
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: kCollections.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final collection = kCollections[index];
                  final busy = _busyQuery == collection.query;
                  return GestureDetector(
                    onTap: busy ? null : () => _openCollection(collection),
                    child: Container(
                      width: 248,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3B4D1F), Color(0xFF161D0E)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -16,
                            bottom: -22,
                            child: Icon(Icons.album_rounded,
                                size: 108, color: AppColors.lime.withOpacity(0.10)),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                collection.title,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600, height: 1.25),
                              ),
                              Row(
                                children: [
                                  if (busy)
                                    const SizedBox(
                                      height: 12,
                                      width: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: AppColors.lime),
                                    )
                                  else
                                    const Icon(Icons.explore_rounded,
                                        size: 13, color: AppColors.lime),
                                  const SizedBox(width: 6),
                                  Text(
                                    busy ? 'Load ho raha hai…' : collection.caption,
                                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (recent.isNotEmpty) ...[
              SectionHeader(title: 'Recently Played'),
              ...recent.asMap().entries.map((entry) {
                final song = entry.value;
                return SongTile(
                  song: song,
                  onTap: () => _play(context, recent, entry.key),
                  onMore: () => showSongMenu(context, song),
                );
              }),
            ],
            SectionHeader(
              title: 'From the Internet',
              actionLabel: _onlineLoading ? 'Loading' : 'Refresh',
              onAction: _onlineLoading ? null : () => _loadOnline(),
            ),
            if (_onlineLoading && _online.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
              )
            else if (_onlineError != null && _online.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Offline',
                  message: _onlineError!,
                  actionLabel: 'Try again',
                  onAction: () => _loadOnline(),
                ),
              )
            else if (_online.isEmpty)
              const SizedBox.shrink()
            else
              SizedBox(
                height: 204,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _online.take(12).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final song = _online[index];
                    return GestureDetector(
                      onTap: () => _play(context, _online, index),
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
              ),
          ],
        ),
      ),
    );
  }
}
