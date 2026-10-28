import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/song.dart';

class OnlineUnavailable implements Exception {
  const OnlineUnavailable();
}

/// Online music with two legal sources:
///  1. Audius — a free streaming network where artists upload their own music.
///     No API key, trending + search + real audio streams.
///  2. Internet Archive — Creative Commons audio, used as a fallback when
///     Audius cannot be reached.
class OnlineMusicService {
  OnlineMusicService();

  static const String _appName = 'TuneHive';
  static const String _kJamendoKey = 'jamendo_client_id';
  static const String _audiusIndex = 'https://api.audius.co';
  static const String _indiaFilter =
      '(hindi OR bollywood OR punjabi OR tamil OR telugu OR indian OR ghazal OR bhajan)';

  final Map<String, List<Song>> _cache = {};
  String? _audiusBase;
  DateTime? _baseAt;
  String? _clientId;

  /// Jamendo client id. Saved from Settings, cached here for the session.
  set clientId(String? value) {
    _clientId = (value == null || value.trim().isEmpty) ? null : value.trim();
    _cache.clear();
  }

  Future<String?> _jamendoKey() async {
    if (_clientId != null) return _clientId;
    // Baked into the build — the normal case for a released APK.
    if (kBuiltInJamendoClientId.trim().isNotEmpty) {
      _clientId = kBuiltInJamendoClientId.trim();
      return _clientId;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_kJamendoKey);
      _clientId = (stored == null || stored.isEmpty) ? null : stored;
    } catch (_) {
      _clientId = null;
    }
    return _clientId;
  }

  /// Tries each source in order and returns the first non-empty result.
  Future<List<Song>> _chain(List<Future<List<Song>> Function()> steps) async {
    Object? lastError;
    for (final step in steps) {
      try {
        final songs = await step();
        if (songs.isNotEmpty) return songs;
      } catch (error) {
        lastError = error;
      }
    }
    if (lastError != null) throw const OnlineUnavailable();
    throw const OnlineUnavailable();
  }

  // ---------------------------------------------------------------- Jamendo --

  Future<List<Song>> _jamendo(Map<String, String> params) async {
    final key = await _jamendoKey();
    if (key == null) throw const OnlineUnavailable();
    final uri = Uri.https('api.jamendo.com', '/v3.0/tracks/', <String, String>{
      'client_id': key,
      'format': 'json',
      'limit': '20',
      'include': 'musicinfo',
      'audioformat': 'mp32',
      'imagesize': '400',
      ...params,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw const OnlineUnavailable();
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const OnlineUnavailable();
    final headers = decoded['headers'];
    if (headers is Map && headers['status'] == 'failed') throw const OnlineUnavailable();
    final results = decoded['results'];
    if (results is! List) throw const OnlineUnavailable();
    final songs = <Song>[];
    for (final item in results) {
      if (item is! Map) continue;
      final song = _jamendoSong(Map<String, dynamic>.from(item));
      if (song != null) songs.add(song);
    }
    if (songs.isEmpty) throw const OnlineUnavailable();
    return songs;
  }

  Song? _jamendoSong(Map<String, dynamic> track) {
    final audio = track['audio']?.toString();
    final id = track['id']?.toString();
    if (audio == null || audio.isEmpty || id == null || id.isEmpty) return null;
    String? genre;
    final musicinfo = track['musicinfo'];
    if (musicinfo is Map) {
      final tags = musicinfo['tags'];
      if (tags is Map) {
        final genres = tags['genres'];
        if (genres is List && genres.isNotEmpty) genre = genres.first.toString();
      }
    }
    return Song(
      id: 'jamendo:$id',
      title: track['name']?.toString() ?? 'Untitled',
      artist: track['artist_name']?.toString() ?? 'Jamendo artist',
      album: track['album_name']?.toString(),
      uri: audio,
      duration: Duration(seconds: (track['duration'] as num?)?.toInt() ?? 0),
      artworkUrl: track['image']?.toString(),
      isOnline: true,
      genre: genre,
    );
  }

  // ---------------------------------------------------------------- Audius --

  Future<String> _base() async {
    final base = _audiusBase;
    final at = _baseAt;
    if (base != null && at != null && DateTime.now().difference(at).inMinutes < 30) {
      return base;
    }
    final response =
        await http.get(Uri.parse(_audiusIndex)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw const OnlineUnavailable();
    final decoded = jsonDecode(response.body);
    final hosts = decoded is Map ? decoded['data'] : null;
    if (hosts is! List || hosts.isEmpty) throw const OnlineUnavailable();
    _audiusBase = hosts.first.toString();
    _baseAt = DateTime.now();
    return _audiusBase!;
  }

  Future<List<Song>> _audius(String path, Map<String, String> params) async {
    final base = await _base();
    final uri = Uri.parse('$base$path').replace(queryParameters: {
      'app_name': _appName,
      ...params,
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw const OnlineUnavailable();
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const OnlineUnavailable();
    final data = decoded['data'];
    if (data is! List) throw const OnlineUnavailable();
    final songs = <Song>[];
    for (final item in data) {
      if (item is! Map) continue;
      final song = _audiusSong(Map<String, dynamic>.from(item), base);
      if (song != null) songs.add(song);
    }
    return songs;
  }

  Song? _audiusSong(Map<String, dynamic> track, String base) {
    final id = track['id'];
    if (id == null) return null;
    final artwork = track['artwork'];
    String? art;
    if (artwork is Map) {
      art = (artwork['480x480'] ?? artwork['150x150'] ?? artwork['1000x1000'])?.toString();
    }
    final user = track['user'];
    final artist = user is Map ? (user['name']?.toString() ?? 'Audius artist') : 'Audius artist';
    final seconds = (track['duration'] as num?)?.toInt() ?? 0;
    return Song(
      id: 'audius:$id',
      title: track['title']?.toString() ?? 'Untitled',
      artist: artist,
      album: 'Audius',
      uri: '$base/v1/tracks/$id/stream?app_name=$_appName',
      duration: Duration(seconds: seconds),
      artworkUrl: art,
      isOnline: true,
      genre: track['genre']?.toString(),
    );
  }

  // ------------------------------------------------- Deezer / iTunes (no key) --

  /// Deezer's public endpoints need no account. They return official 30 second
  /// clips — enough to browse and discover, and completely legal.
  Future<List<Song>> _deezer(String path, Map<String, String> params) async {
    final uri = Uri.https('api.deezer.com', path, params);
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw const OnlineUnavailable();
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const OnlineUnavailable();
    final data = decoded['data'];
    if (data is! List) throw const OnlineUnavailable();
    final songs = <Song>[];
    for (final item in data) {
      if (item is! Map) continue;
      final song = _deezerSong(Map<String, dynamic>.from(item));
      if (song != null) songs.add(song);
    }
    if (songs.isEmpty) throw const OnlineUnavailable();
    return songs;
  }

  Song? _deezerSong(Map<String, dynamic> track) {
    final preview = track['preview']?.toString();
    final id = track['id']?.toString();
    if (preview == null || preview.isEmpty || id == null) return null;
    final artist = track['artist'];
    final album = track['album'];
    String? cover;
    if (album is Map) cover = album['cover_medium']?.toString();
    return Song(
      id: 'deezer:$id',
      title: track['title']?.toString() ?? 'Untitled',
      artist: artist is Map ? (artist['name']?.toString() ?? 'Deezer artist') : 'Deezer artist',
      album: album is Map ? album['title']?.toString() : null,
      uri: preview,
      duration: const Duration(seconds: 30),
      artworkUrl: cover,
      isOnline: true,
      isPreview: true,
    );
  }

  /// Apple's public iTunes Search API — no key, full Indian catalogue, also
  /// returns official 30 second previews.
  Future<List<Song>> _itunes(String term,
      {int limit = 25, int offset = 0, bool newestFirst = false}) async {
    final uri = Uri.https('itunes.apple.com', '/search', <String, String>{
      'term': term,
      'country': 'in',
      'media': 'music',
      'entity': 'song',
      'limit': '$limit',
      if (offset > 0) 'offset': '$offset',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw const OnlineUnavailable();
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const OnlineUnavailable();
    final results = decoded['results'];
    if (results is! List) throw const OnlineUnavailable();
    final entries = <Map<String, dynamic>>[];
    final songs = <Song>[];
    for (final item in results) {
      if (item is! Map) continue;
      final track = Map<String, dynamic>.from(item);
      final song = _itunesSong(track);
      if (song == null) continue;
      entries.add(track);
      songs.add(song);
    }
    if (songs.isEmpty) throw const OnlineUnavailable();
    if (newestFirst) {
      final order = <String, String>{};
      for (var i = 0; i < entries.length; i++) {
        order[songs[i].id] = (entries[i]['releaseDate'] ?? '').toString();
      }
      songs.sort((a, b) => (order[b.id] ?? '').compareTo(order[a.id] ?? ''));
    }
    return songs;
  }

  Song? _itunesSong(Map<String, dynamic> track) {
    final preview = track['previewUrl']?.toString();
    final id = track['trackId']?.toString();
    if (preview == null || preview.isEmpty || id == null) return null;
    final art = track['artworkUrl100']?.toString();
    final ms = (track['trackTimeMillis'] as num?)?.toInt() ?? 0;
    return Song(
      id: 'itunes:$id',
      title: track['trackName']?.toString() ?? 'Untitled',
      artist: track['artistName']?.toString() ?? 'Apple Music artist',
      album: track['collectionName']?.toString(),
      uri: preview,
      duration: Duration(milliseconds: ms == 0 ? 30000 : ms),
      artworkUrl: art == null ? null : art.replaceAll('100x100', '400x400'),
      isOnline: true,
      isPreview: true,
      genre: track['primaryGenreName']?.toString(),
    );
  }

  // --------------------------------------------------------------- public ---

  /// Trending this week. Jamendo (if a key is set) gives full songs, then
  /// Audius, then Deezer's public chart.
  Future<List<Song>> trendingToday({int limit = 16}) => _cached('trending-in', () => _chain([
        () => _deezer('/search', {'q': 'hindi songs', 'limit': '$limit'}),
        () => _itunes('hindi songs', limit: limit),
        () => _jamendo({'order': 'popularity_week', 'fuzzytags': 'indian', 'limit': '$limit'}),
        () => _run('$_indiaFilter AND mediatype:(audio)', limit, sort: 'downloads desc'),
        () => _audius('/v1/tracks/trending', {'time': 'week', 'limit': '$limit'}),
      ]));

  /// Newest releases first — the freshest Indian songs we can legally reach.
  Future<List<Song>> newRising({int limit = 16}) => _cached('rising-in', () => _chain([
        () => _itunes('hindi new songs', limit: limit, newestFirst: true),
        () => _deezer('/search', {'q': 'new hindi songs', 'limit': '$limit'}),
        () => _jamendo({'order': 'releasedate_desc', 'limit': '$limit'}),
        () => _run('$_indiaFilter AND mediatype:(audio)', limit, sort: 'publicdate desc'),
        () => _audius('/v1/tracks/trending', {'time': 'month', 'limit': '$limit'}),
      ]));

  /// Category browsing (Hindi, Punjabi, Party …).
  Future<List<Song>> browse({String? genre, int limit = 16, int offset = 0}) async {
    final term = genre?.toLowerCase().trim();
    if (term == null || term == 'all') return trendingToday(limit: limit);
    return _cached('g:$term:$limit:$offset', () => _chain([
          () => _jamendo({'fuzzytags': _tagFor(term), 'limit': '$limit', 'offset': '$offset'}),
          () => _audius('/v1/tracks/search',
              {'query': _audiusTerm(term), 'limit': '$limit', 'offset': '$offset'}),
          () => _deezer('/search',
              {'q': _audiusTerm(term), 'limit': '$limit', 'index': '$offset'}),
          () => _itunes(_audiusTerm(term), limit: limit, offset: offset),
          () => _run('${_alias(term)} AND mediatype:(audio)', limit, offset: offset),
        ]));
  }

  /// Search across every source, ranked so the closest match comes first.
  Future<List<Song>> search(String term, {int limit = 24, int offset = 0}) async {
    final query = term.trim();
    if (query.isEmpty) return trendingToday(limit: limit);
    return _cached('s:$query:$limit:$offset', () async {
      final songs = await _chain([
        () => _jamendo({'search': query, 'limit': '$limit', 'offset': '$offset'}),
        () => _audius('/v1/tracks/search',
            {'query': query, 'limit': '$limit', 'offset': '$offset'}),
        () => _deezer('/search', {'q': query, 'limit': '$limit', 'index': '$offset'}),
        () => _itunes(query, limit: limit, offset: offset),
        () => _run('$query AND mediatype:(audio)', limit, offset: offset),
      ]);
      return offset == 0 ? _rank(songs, query) : songs;
    });
  }

  Future<List<Song>> _cached(String key, Future<List<Song>> Function() load) async {
    final cached = _cache[key];
    if (cached != null) return cached;
    final songs = await load();
    if (songs.isNotEmpty) _cache[key] = songs;
    return songs;
  }

  /// Closest title matches first, so a search does not open with junk.
  List<Song> _rank(List<Song> songs, String term) {
    final q = term.toLowerCase();
    final ranked = List<Song>.from(songs);
    ranked.sort((a, b) => _score(b, q).compareTo(_score(a, q)));
    return ranked;
  }

  int _score(Song song, String q) {
    final title = song.title.toLowerCase();
    if (title == q) return 4;
    if (title.startsWith(q)) return 3;
    if (title.contains(q)) return 2;
    if (song.artist.toLowerCase().contains(q)) return 1;
    return 0;
  }

  static String _tagFor(String term) {
    switch (term) {
      case 'hindi':
      case 'bollywood':
        return 'bollywood';
      case 'bhakti':
        return 'devotional';
      case 'ghazal':
        return 'sufi';
      case 'hip-hop':
        return 'hiphop';
      default:
        return term;
    }
  }

  static String _audiusTerm(String term) {
    switch (term) {
      case 'hindi':
        return 'bollywood';
      case 'bhakti':
        return 'devotional';
      case 'ghazal':
        return 'sufi';
      default:
        return term;
    }
  }

  static String _alias(String term) {
    const aliases = {
      'hindi': '(hindi OR bollywood OR filmi)',
      'bollywood': '(bollywood OR filmi OR hindi)',
      'punjabi': '(punjabi OR bhangra)',
      'tamil': '(tamil OR kollywood)',
      'telugu': '(telugu OR tollywood)',
      'ghazal': '(ghazal OR sufi)',
      'bhakti': '(bhakti OR bhajan OR devotional)',
      'party': '(party OR dance)',
      'sad': '(sad OR emotional)',
      'chill': '(chill OR lofi OR ambient)',
      'hip-hop': '(hip hop OR rap)',
      'jazz': '(jazz OR blues)',
      'focus': '(piano OR instrumental OR classical)',
    };
    return aliases[term] ?? '"$term"';
  }

  // ------------------------------------------------------- Internet Archive --

  Future<List<Song>> _run(String query, int limit,
      {String sort = 'downloads desc', int offset = 0}) async {
    final uri = Uri.https('archive.org', '/advancedsearch.php', <String, dynamic>{
      'q': query,
      'fl[]': <String>['identifier', 'title', 'creator', 'year'],
      'rows': '$limit',
      'page': '${offset ~/ (limit == 0 ? 1 : limit) + 1}',
      'output': 'json',
      'sort[]': sort,
    });
    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const OnlineUnavailable();
    }
    if (response.statusCode != 200) throw const OnlineUnavailable();
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const OnlineUnavailable();
    final body = decoded['response'];
    if (body is! Map<String, dynamic>) throw const OnlineUnavailable();
    final docs = (body['docs'] as List?) ?? const [];
    final results = await Future.wait(docs.map((doc) {
      if (doc is! Map) return Future<Song?>.value(null);
      return _resolve(Map<String, dynamic>.from(doc));
    }));
    return results.whereType<Song>().toList();
  }

  Future<Song?> _resolve(Map<String, dynamic> doc) async {
    final identifier = doc['identifier'];
    if (identifier is! String || identifier.isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse('https://archive.org/metadata/$identifier'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final meta = jsonDecode(response.body);
      if (meta is! Map<String, dynamic>) return null;
      final files = (meta['files'] as List?) ?? const [];
      Map<String, dynamic>? mp3;
      for (final file in files) {
        if (file is! Map) continue;
        final name = (file['name'] ?? '').toString();
        if (name.toLowerCase().endsWith('.mp3')) {
          mp3 = Map<String, dynamic>.from(file);
          break;
        }
      }
      if (mp3 == null) return null;
      final name = (mp3['name'] ?? '').toString();
      if (name.isEmpty) return null;
      final encoded = name.split('/').map(Uri.encodeComponent).join('/');
      final url = 'https://archive.org/download/$identifier/$encoded';
      final title = _text(doc['title']) ?? _text(meta['metadata']?['title']) ?? identifier;
      final artist = _text(doc['creator']) ?? _text(meta['metadata']?['creator']) ?? 'Creative Commons';
      return Song(
        id: 'ia:$identifier',
        title: title,
        artist: artist,
        album: 'Internet Archive',
        uri: url,
        duration: _parseLength(mp3['length'] ?? meta['metadata']?['length']),
        artworkUrl: 'https://archive.org/services/img/$identifier',
        isOnline: true,
        genre: 'Creative Commons',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('archive resolve failed: $e');
      return null;
    }
  }

  static String? _text(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is List) {
      final parts = value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty);
      if (parts.isEmpty) return null;
      return parts.take(2).join(', ');
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Duration _parseLength(dynamic raw) {
    if (raw == null) return Duration.zero;
    final text = raw.toString().trim();
    if (text.isEmpty) return Duration.zero;
    if (text.contains(':')) {
      final parts = text.split(':').map((p) => int.tryParse(p) ?? 0).toList();
      if (parts.length == 2) return Duration(minutes: parts[0], seconds: parts[1]);
      if (parts.length == 3) {
        return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
      }
      return Duration.zero;
    }
    final seconds = double.tryParse(text);
    if (seconds == null) return Duration.zero;
    return Duration(milliseconds: (seconds * 1000).round());
  }
}
