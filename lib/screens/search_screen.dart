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

const int _pageSize = 20;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  Timer? _debounce;

  String _scope = 'Online';
  String _query = '';
  bool _online = true;
  List<Song> _results = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _searching = false;
  bool _loadingMore = false;
  String? _error;

  static const _suggestions = [
    'Bollywood',
    'Arijit Singh',
    'Punjabi',
    'Ghazal',
    'Bhakti',
    'Tamil',
    'Indie',
    'Lofi',
  ];

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    NetworkService.isOnline().then((online) {
      if (!mounted) return;
      setState(() {
        _online = online;
        // Online is primary when there is internet, device when there is not.
        _scope = online ? 'Online' : 'Device';
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scope != 'Online' || !_online) return;
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) {
      _searchOnline(reset: false);
    }
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    if (_scope != 'Online') return;
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _searchOnline());
  }

  Future<void> _searchOnline({bool reset = true}) async {
    final term = _controller.text.trim();
    if (term.length < 2) return;
    if (reset) {
      setState(() {
        _searching = true;
        _results = [];
        _offset = 0;
        _hasMore = true;
        _error = null;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }
    try {
      final songs = await context
          .read<OnlineMusicService>()
          .search(term, limit: _pageSize, offset: _offset);
      if (!mounted) return;
      final known = _results.map((song) => song.id).toSet();
      final fresh = songs.where((song) => !known.contains(song.id)).toList();
      setState(() {
        _results.addAll(fresh);
        _offset += _pageSize;
        _hasMore = songs.isNotEmpty && fresh.isNotEmpty;
        if (_results.isEmpty) _error = 'Kuch nahi mila — koi aur term try karo.';
      });
    } on OnlineUnavailable {
      if (!mounted) return;
      setState(() {
        _hasMore = false;
        _error = 'Internet nahi hai. Device tab se apne gaane chala lo.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasMore = false;
        _error = 'Search fail ho gaya. Dobara try karo.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
          _loadingMore = false;
        });
      }
    }
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

  void _switchScope(String scope) {
    setState(() => _scope = scope);
    if (scope == 'Online' && _controller.text.trim().length >= 2 && _results.isEmpty) {
      _searchOnline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = context.watch<DeviceMusicService>();
    final player = context.watch<PlayerService>();
    final online = _scope == 'Online' && _online;
    final deviceResults = device.search(_query);
    final songs = online ? _results : deviceResults;

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
                          setState(() => _results = []);
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
                  if (_online) ...[
                    _ScopeChip(
                      label: 'Online',
                      icon: Icons.public_rounded,
                      active: _scope == 'Online',
                      onTap: () => _switchScope('Online'),
                    ),
                    const SizedBox(width: 10),
                    _ScopeChip(
                      label: 'Device',
                      icon: Icons.phone_android_rounded,
                      active: _scope == 'Device',
                      onTap: () => _switchScope('Device'),
                    ),
                  ] else ...[
                    _ScopeChip(
                      label: 'Device',
                      icon: Icons.phone_android_rounded,
                      active: _scope == 'Device',
                      onTap: () => _switchScope('Device'),
                    ),
                    const SizedBox(width: 10),
                    _ScopeChip(
                      label: 'Online (offline)',
                      icon: Icons.wifi_off_rounded,
                      active: false,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Internet nahi hai — device ke gaane chal rahe hain')),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            if (online && _query.trim().length < 2)
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
            if (online && _error != null && !_searching)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error!,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5)),
              ),
            Expanded(
              child: songs.isEmpty
                  ? EmptyState(
                      icon: online ? Icons.public_rounded : Icons.phone_android_rounded,
                      title: online ? 'Online search' : 'Koi gaana nahi mila',
                      message: online
                          ? 'Do akshar likho — matching songs aa jayenge, aur neeche scroll karte jao to aur aate rahenge.'
                          : 'Device ke gaane yahan dikhenge. Net ho to online search khud primary ban jaata hai.',
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.only(top: 8, bottom: 220),
                      itemCount: songs.length + (_loadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= songs.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.lime),
                              ),
                            ),
                          );
                        }
                        final song = songs[index];
                        return SongTile(
                          song: song,
                          isCurrent: player.current?.id == song.id,
                          onTap: () => _play(songs, index),
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
