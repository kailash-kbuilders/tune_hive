import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/device_music_service.dart';
import '../services/library_service.dart';
import '../services/network_service.dart';
import '../services/online_music_service.dart';
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

class _Collection {
  const _Collection(this.title, this.query, this.caption);
  final String title;
  final String query;
  final String caption;
}

const List<_Collection> kCollections = [
  _Collection('Bollywood & Hindi', 'bollywood', 'Filmi aur indie geet'),
  _Collection('Punjabi Beats', 'punjabi', 'Bhangra aur dhol'),
  _Collection('Ghazal & Sufi', 'ghazal', 'Shaam dhalne ke baad'),
  _Collection('Bhakti & Bhajan', 'bhakti', 'Shanti ke liye'),
  _Collection('South Side', 'tamil', 'Tamil aur Telugu'),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _category = 'All';
  bool? _online;
  bool _loadingOnline = false;
  String? _onlineError;
  List<Song> _trending = [];
  List<Song> _rising = [];
  List<Song> _forYou = [];
  List<Song> _categorySongs = [];
  String? _busyQuery;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final device = context.read<DeviceMusicService>();
    unawaited(device.load());
    final online = await NetworkService.isOnline();
    if (!mounted) return;
    setState(() => _online = online);
    if (online) {
      await _loadOnline();
    } else {
      setState(() => _onlineError = 'Internet nahi hai — device ke gaane chal rahe hain.');
    }
  }

  Future<void> _loadOnline({String? genre}) async {
    if (_loadingOnline) return;
    setState(() {
      _loadingOnline = true;
      _onlineError = null;
    });
    try {
      final service = context.read<OnlineMusicService>();
      final library = context.read<LibraryService>();
      final seed = library.topArtist ?? _recentSeed(library);
      final results = await Future.wait<List<Song>>([
        service.trendingToday(),
        service.newRising(),
        seed == null ? Future<List<Song>>.value(const <Song>[]) : service.search(seed, limit: 12),
        (genre == null || genre == 'All')
            ? Future<List<Song>>.value(const <Song>[])
            : service.browse(genre: genre),
      ]);
      if (!mounted) return;
      setState(() {
        _trending = results[0];
        _rising = results[1];
        _forYou = results[2];
        if (genre != null) _categorySongs = results[3];
        _online = true;
      });
    } on OnlineUnavailable {
      if (!mounted) return;
      setState(() {
        _online = false;
        _onlineError = 'Online songs nahi mile — device ke gaane dikha rahe hain.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _onlineError = 'Online load nahi hua. Neeche kheencho aur retry karo.');
    } finally {
      if (mounted) setState(() => _loadingOnline = false);
    }
  }

  String? _recentSeed(LibraryService library) {
    for (final song in library.recent) {
      final artist = song.artist.trim();
      if (artist.isNotEmpty && artist != 'Unknown artist' && artist != 'Creative Commons') {
        return artist;
      }
    }
    return null;
  }

  List<Song> _filter(List<Song> songs) {
    if (_category == 'All' || _online == true) return songs;
    final q = _category.toLowerCase();
    return songs
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            (s.album ?? '').toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _play(List<Song> songs, int index) async {
    if (songs.isEmpty || index >= songs.length) return;
    final player = context.read<PlayerService>();
    final library = context.read<LibraryService>();
    unawaited(player.playSongs(songs, index));
    unawaited(library.addRecent(songs[index]));
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
          subtitle: '${songs.length} songs · online',
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
    final online = _online == true;
    final deviceSongs = _filter(device.songs);
    final recent = library.recent.take(4).toList();

    return GradientBg(
      child: RefreshIndicator(
        color: AppColors.lime,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          final isOnline = await NetworkService.isOnline();
          if (!mounted) return;
          setState(() => _online = isOnline);
          if (isOnline) {
            await _loadOnline(genre: _category == 'All' ? null : _category);
          } else {
            setState(() => _onlineError = 'Internet nahi hai — device ke gaane chal rahe hain.');
          }
          await device.load(force: true);
        },
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 230),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _header(context, library),
            if (_online == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
              ),
            if (_online == false && _onlineError != null) _offlineCard(context),
            if (online && _trending.isNotEmpty)
              ..._songRow('Trending Today', 'Audius · live', _trending),
            if (online && _rising.isNotEmpty)
              ..._songRow('New & Rising', 'Fresh uploads', _rising),
            if (online && _forYou.isNotEmpty)
              ..._songRow('Aapke liye', 'Aapke sune hue artists se', _forYou),
            if (online) ...[
              const SectionHeader(title: 'Select Categories'),
              CategoryChips(
                categories: kCategories,
                selected: _category,
                onSelected: (value) {
                  setState(() => _category = value);
                  _loadOnline(genre: value == 'All' ? null : value);
                },
              ),
              if (_loadingOnline && _category != 'All' && _categorySongs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 26),
                  child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
                ),
              if (_category != 'All' && _categorySongs.isNotEmpty)
                ..._songRow(_category, 'Online picks', _categorySongs),
              const SectionHeader(title: 'New Collection'),
              _collections(context),
            ],
            SectionHeader(
              title: online ? 'On this device' : 'Popular Songs',
              actionLabel: deviceSongs.isEmpty ? null : 'See all',
              onAction: deviceSongs.isEmpty
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SongListScreen(
                          title: online ? 'On this device' : 'Popular Songs',
                          subtitle: '${deviceSongs.length} songs · device',
                          songs: deviceSongs,
                        ),
                      )),
            ),
            _deviceBlock(context, device, deviceSongs),
            if (recent.isNotEmpty) ...[
              SectionHeader(
                title: 'Recently Played',
                actionLabel: 'History',
                onAction: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SongListScreen(
                    title: 'History',
                    subtitle: '${library.recent.length} songs',
                    songs: library.recent,
                    emptyMessage: 'Abhi tak kuch suna nahi.',
                  ),
                )),
              ),
              ...recent.asMap().entries.map((entry) {
                final song = entry.value;
                return SongTile(
                  song: song,
                  onTap: () => _play(recent, entry.key),
                  onMore: () => showSongMenu(context, song),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, LibraryService library) {
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

  Widget _offlineCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: AppCard(
        color: AppColors.cardSoft,
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _onlineError ?? 'Offline',
                style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.45),
              ),
            ),
            TextButton(
              onPressed: _loadingOnline ? null : () => _loadOnline(),
              child: const Text('Retry', style: TextStyle(color: AppColors.lime, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _songRow(String title, String subtitle, List<Song> songs) {
    return [
      SectionHeader(
        title: title,
        actionLabel: 'See all',
        onAction: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SongListScreen(
            title: title,
            subtitle: '${songs.length} songs · $subtitle',
            songs: songs,
          ),
        )),
      ),
      SizedBox(
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
      ),
    ];
  }

  Widget _collections(BuildContext context) {
    return SizedBox(
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
                            const Icon(Icons.explore_rounded, size: 13, color: AppColors.lime),
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
    );
  }

  Widget _deviceBlock(BuildContext context, DeviceMusicService device, List<Song> songs) {
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
                    ? '30 second se lambi audio files hi dikhti hain. Online section se free songs bhi chala sakte ho.'
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
