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
  Timer? _debounce;
  String _scope = 'Device';
  String _query = '';
  List<Song> _online = [];
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Online first: if the device has internet, search the live catalogue.
    NetworkService.isOnline().then((online) {
      if (!mounted || !online) return;
      setState(() => _scope = 'Online');
    });
  }

  static const _suggestions = [
    'Bollywood',
    'Hindi',
    'Punjabi',
    'Ghazal',
    'Bhakti',
    'Tamil',
    'Indie',
    'Lofi',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    if (_scope != 'Online') return;
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _online = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 650), _searchOnline);
  }

  Future<void> _searchOnline() async {
    final term = _controller.text.trim();
    if (term.length < 2) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final songs = await context.read<OnlineMusicService>().search(term);
      if (!mounted) return;
      setState(() => _online = songs);
      if (songs.isEmpty) setState(() => _error = 'Kuch nahi mila — koi aur term try karo.');
    } on OnlineUnavailable {
      if (!mounted) return;
      setState(() => _error = 'Internet nahi hai. Device tab se apne gaane chala lo.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Search fail ho gaya. Dobara try karo.');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _play(List<Song> songs, int index) async {
    if (songs.isEmpty) return;
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
    final results = _scope == 'Device' ? device.search(_query) : _online;

    return GradientBg(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text('Search', style: Theme.of(context).textTheme.headlineMedium),
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
                        onChanged: _onChanged,
                        onSubmitted: (_) {
                          if (_scope == 'Online') _searchOnline();
                        },
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
                          _onChanged('');
                          setState(() => _online = []);
                        },
                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _ScopeChip(
                    label: 'Device',
                    icon: Icons.phone_android_rounded,
                    active: _scope == 'Device',
                    onTap: () => setState(() => _scope = 'Device'),
                  ),
                  const SizedBox(width: 10),
                  _ScopeChip(
                    label: 'Online · Free',
                    icon: Icons.public_rounded,
                    active: _scope == 'Online',
                    onTap: () {
                      setState(() => _scope = 'Online');
                      if (_query.trim().length >= 2) _searchOnline();
                    },
                  ),
                ],
              ),
            ),
            if (_scope == 'Online' && _query.trim().length < 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _suggestions
                      .map((term) => GestureDetector(
                            onTap: () {
                              _controller.text = term;
                              _onChanged(term);
                              _searchOnline();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.cardSoft,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.line),
                              ),
                              child: Text(term,
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                            ),
                          ))
                      .toList(),
                ),
              ),
            if (_searching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
              ),
            if (_scope == 'Online' && _error != null && !_searching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error!,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5)),
              ),
            Expanded(
              child: results.isEmpty
                  ? EmptyState(
                      icon: _scope == 'Device'
                          ? Icons.phone_android_rounded
                          : Icons.public_rounded,
                      title: _scope == 'Device' ? 'Koi gaana nahi mila' : 'Online search',
                      message: _scope == 'Device'
                          ? 'Device ke gaane yahan dikhenge. Online tab se free Creative Commons music bhi search kar sakte ho.'
                          : 'Do akshar likho — Audius aur Internet Archive se free songs aa jayenge.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 200),
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

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.lime : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.lime : AppColors.line),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF10160A) : AppColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? const Color(0xFF10160A) : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
