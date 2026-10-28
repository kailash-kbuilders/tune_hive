import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

/// Favourites, recently played, playlists and the onboarding flag — all kept
/// in SharedPreferences so nothing needs a server.
class LibraryService extends ChangeNotifier {
  static const _kOnboarded = 'onboarded';
  static const _kFavourites = 'favourites';
  static const _kRecent = 'recent';
  static const _kPlaylists = 'playlists';
  static const _kName = 'listener_name';
  static const _kCounts = 'play_counts';

  SharedPreferences? _prefs;
  bool _onboarded = false;
  String _listenerName = 'Music Lover';
  final List<Song> _favourites = [];
  final List<Song> _recent = [];
  final Map<String, List<Song>> _playlists = {};
  final Map<String, int> _playCounts = {};

  bool get onboarded => _onboarded;
  String get listenerName => _listenerName;
  List<Song> get favourites => List.unmodifiable(_favourites);
  List<Song> get recent => List.unmodifiable(_recent);
  List<String> get playlistNames => _playlists.keys.toList();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _onboarded = prefs.getBool(_kOnboarded) ?? false;
    _listenerName = prefs.getString(_kName) ?? 'Music Lover';
    _favourites
      ..clear()
      ..addAll(_decodeList(prefs.getString(_kFavourites)));
    _recent
      ..clear()
      ..addAll(_decodeList(prefs.getString(_kRecent)));
    final rawCounts = prefs.getString(_kCounts);
    if (rawCounts != null) {
      try {
        final map = jsonDecode(rawCounts);
        if (map is Map) {
          map.forEach((key, value) {
            if (key is String && value is num) _playCounts[key] = value.toInt();
          });
        }
      } catch (_) {
        // Corrupt counts — start clean.
      }
    }
    final rawPlaylists = prefs.getString(_kPlaylists);
    if (rawPlaylists != null) {
      try {
        final map = jsonDecode(rawPlaylists);
        if (map is Map) {
          map.forEach((key, value) {
            if (key is String && value is List) {
              _playlists[key] = value
                  .whereType<Map>()
                  .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
                  .toList();
            }
          });
        }
      } catch (_) {
        // Corrupt prefs — start with an empty playlist set.
      }
    }
    notifyListeners();
  }

  List<Song> _decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => Song.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> completeOnboarding() async {
    _onboarded = true;
    notifyListeners();
    await _prefs?.setBool(_kOnboarded, true);
  }

  Future<void> setListenerName(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    _listenerName = clean;
    notifyListeners();
    await _prefs?.setString(_kName, clean);
  }

  bool isFavourite(Song song) => _favourites.any((s) => s.id == song.id);

  Future<void> toggleFavourite(Song song) async {
    final index = _favourites.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      _favourites.removeAt(index);
    } else {
      _favourites.insert(0, song);
    }
    notifyListeners();
    await _prefs?.setString(_kFavourites, jsonEncode(_favourites.map((s) => s.toJson()).toList()));
  }

  Future<void> addRecent(Song song) async {
    _recent.removeWhere((s) => s.id == song.id);
    _recent.insert(0, song);
    if (_recent.length > 50) _recent.removeRange(50, _recent.length);
    _playCounts[song.id] = (_playCounts[song.id] ?? 0) + 1;
    notifyListeners();
    await _prefs?.setString(_kRecent, jsonEncode(_recent.map((s) => s.toJson()).toList()));
    await _prefs?.setString(_kCounts, jsonEncode(_playCounts));
  }

  int playCount(Song song) => _playCounts[song.id] ?? 0;

  /// Most played artist in the history — used to seed "Aapke liye".
  String? get topArtist {
    final counts = <String, int>{};
    for (final song in _recent) {
      final artist = song.artist.trim();
      if (artist.isEmpty || artist == 'Unknown artist' || artist == 'Creative Commons') continue;
      counts[artist] = (counts[artist] ?? 0) + (_playCounts[song.id] ?? 1);
    }
    if (counts.isEmpty) return null;
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  Future<void> clearHistory() async {
    _recent.clear();
    _playCounts.clear();
    notifyListeners();
    await _prefs?.remove(_kRecent);
    await _prefs?.remove(_kCounts);
  }

  List<Song> playlist(String name) => List.unmodifiable(_playlists[name] ?? const []);

  Future<void> createPlaylist(String name) async {
    final clean = name.trim();
    if (clean.isEmpty || _playlists.containsKey(clean)) return;
    _playlists[clean] = [];
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> addToPlaylist(String name, Song song) async {
    final list = _playlists[name];
    if (list == null) {
      _playlists[name] = [song];
    } else if (!list.any((s) => s.id == song.id)) {
      list.add(song);
    }
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> removeFromPlaylist(String name, Song song) async {
    _playlists[name]?.removeWhere((s) => s.id == song.id);
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String name) async {
    _playlists.remove(name);
    notifyListeners();
    await _savePlaylists();
  }

  Future<void> _savePlaylists() async {
    final map = <String, dynamic>{};
    _playlists.forEach((key, value) {
      map[key] = value.map((s) => s.toJson()).toList();
    });
    await _prefs?.setString(_kPlaylists, jsonEncode(map));
  }
}
