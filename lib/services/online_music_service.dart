import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
  static const String _audiusIndex = 'https://api.audius.co';
  static const String _indiaFilter =
      '(hindi OR bollywood OR punjabi OR tamil OR telugu OR indian OR ghazal OR bhajan)';

  final Map<String, List<Song>> _cache = {};
  String? _audiusBase;
  DateTime? _baseAt;

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

  // --------------------------------------------------------------- public ---

  /// What is trending right now on Audius (falls back to the archive).
  Future<List<Song>> trendingToday({int limit = 16}) => _cached('trending', () async {
        try {
          return await _audius('/v1/tracks/trending', {
            'time': 'week',
            'limit': '$limit',
          });
        } catch (_) {
          return _run('$_indiaFilter AND mediatype:(audio)', limit, sort: 'downloads desc');
        }
      });

  /// Fresh uploads / rising tracks this month.
  Future<List<Song>> newRising({int limit = 16}) => _cached('rising', () async {
        try {
          return await _audius('/v1/tracks/trending', {
            'time': 'month',
            'limit': '$limit',
          });
        } catch (_) {
          return _run('$_indiaFilter AND mediatype:(audio)', limit, sort: 'publicdate desc');
        }
      });

  /// Category browsing (Hindi, Punjabi, Party …).
  Future<List<Song>> browse({String? genre, int limit = 16}) async {
    final term = genre?.toLowerCase().trim();
    if (term == null || term == 'all') return trendingToday(limit: limit);
    final key = 'g:$term:$limit';
    return _cached(key, () async {
      try {
        return await _audius('/v1/tracks/search', {
          'query': _audiusTerm(term),
          'limit': '$limit',
        });
      } catch (_) {
        return _run('${_alias(term)} AND mediatype:(audio)', limit);
      }
    });
  }

  Future<List<Song>> search(String term, {int limit = 24}) async {
    final query = term.trim();
    if (query.isEmpty) return trendingToday(limit: limit);
    final key = 's:$query:$limit';
    return _cached(key, () async {
      try {
        final results = await _audius('/v1/tracks/search', {
          'query': query,
          'limit': '$limit',
        });
        if (results.isNotEmpty) return _rank(results, query);
      } catch (_) {
        // fall through to the archive
      }
      final archive = await _run('$query AND mediatype:(audio)', limit);
      return _rank(archive, query);
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

  Future<List<Song>> _run(String query, int limit, {String sort = 'downloads desc'}) async {
    final uri = Uri.https('archive.org', '/advancedsearch.php', <String, dynamic>{
      'q': query,
      'fl[]': <String>['identifier', 'title', 'creator', 'year'],
      'rows': '$limit',
      'page': '1',
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
