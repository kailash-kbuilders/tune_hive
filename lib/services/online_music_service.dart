import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/song.dart';

class OnlineUnavailable implements Exception {
  const OnlineUnavailable();
}

/// Free, legal music from the Internet Archive's Creative Commons audio
/// collections. No API key, no account, no login.
class OnlineMusicService {
  OnlineMusicService();

  final Map<String, List<Song>> _cache = {};

  Future<List<Song>> browse({String? genre, int limit = 14}) async {
    final key = 'g:${genre ?? 'popular'}:$limit';
    final cached = _cache[key];
    if (cached != null) return cached;
    final query = genre == null || genre.toLowerCase() == 'all'
        ? 'collection:(netlabels) AND mediatype:(audio)'
        : '"$genre" AND mediatype:(audio)';
    final songs = await _run(query, limit);
    _cache[key] = songs;
    return songs;
  }

  Future<List<Song>> search(String term, {int limit = 24}) async {
    final q = term.trim();
    if (q.isEmpty) return browse(limit: limit);
    final key = 's:$q:$limit';
    final cached = _cache[key];
    if (cached != null) return cached;
    final songs = await _run('$q AND mediatype:(audio)', limit);
    _cache[key] = songs;
    return songs;
  }

  Future<List<Song>> _run(String query, int limit) async {
    final uri = Uri.https('archive.org', '/advancedsearch.php', <String, dynamic>{
      'q': query,
      'fl[]': <String>['identifier', 'title', 'creator', 'year'],
      'rows': '$limit',
      'page': '1',
      'output': 'json',
      'sort[]': 'downloads desc',
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
