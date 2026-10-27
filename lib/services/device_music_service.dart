import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../models/song.dart';

/// Reads the phone's own audio library. Only files longer than 30 seconds are
/// kept, so notification sounds and voice notes never show up as songs.
class DeviceMusicService extends ChangeNotifier {
  static const minDuration = Duration(seconds: 30);

  final OnAudioQuery _query = OnAudioQuery();
  List<Song> _songs = [];
  bool _loading = false;
  bool _permissionDenied = false;
  bool _loadedOnce = false;
  String? _error;

  List<Song> get songs => _songs;
  bool get isLoading => _loading;
  bool get permissionDenied => _permissionDenied;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loadedOnce && !force) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      var granted = false;
      try {
        granted = await _query.permissionsStatus();
        if (!granted) granted = await _query.permissionsRequest();
      } catch (_) {
        granted = false;
      }
      if (!granted) {
        _permissionDenied = true;
        _songs = [];
        _loading = false;
        _loadedOnce = true;
        notifyListeners();
        return;
      }
      _permissionDenied = false;
      final raw = await _query.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      final list = <Song>[];
      for (final model in raw) {
        final ms = model.duration ?? 0;
        if (ms < minDuration.inMilliseconds) continue;
        list.add(_toSong(model));
      }
      _songs = list;
    } catch (e) {
      _error = 'Device songs read nahi ho paye';
      if (kDebugMode) debugPrint('device scan failed: $e');
    } finally {
      _loading = false;
      _loadedOnce = true;
      notifyListeners();
    }
  }

  Song _toSong(SongModel model) {
    final path = model.data ?? '';
    final uri = path.startsWith('/')
        ? Uri.file(path).toString()
        : (model.uri ?? '');
    final artist = (model.artist ?? '').trim();
    return Song(
      id: 'device:${model.id}',
      deviceId: model.id,
      albumId: model.albumId,
      title: model.title.trim().isEmpty ? 'Unknown track' : model.title.trim(),
      artist: artist.isEmpty || artist == '<unknown>' ? 'Unknown artist' : artist,
      album: model.album,
      uri: uri,
      duration: Duration(milliseconds: model.duration ?? 0),
      isOnline: false,
    );
  }

  List<Song> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _songs;
    return _songs
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q) ||
            (s.album ?? '').toLowerCase().contains(q))
        .toList();
  }
}

/// Lazily loads and caches embedded artwork for device songs.
class ArtworkCache {
  ArtworkCache._();

  static final Map<int, Uint8List?> _cache = {};
  static final OnAudioQuery _query = OnAudioQuery();

  static Future<Uint8List?> load(int id) async {
    if (_cache.containsKey(id)) return _cache[id];
    try {
      final bytes = await _query.queryArtwork(
        id,
        ArtworkType.AUDIO,
        size: 300,
        format: ArtworkFormat.JPEG,
      );
      _cache[id] = bytes;
      return bytes;
    } catch (_) {
      _cache[id] = null;
      return null;
    }
  }

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;
}
