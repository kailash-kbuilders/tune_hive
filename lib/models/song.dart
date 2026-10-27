/// A single playable track — either a file on the device or a Creative
/// Commons track streamed from the Internet Archive.
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.uri,
    this.album,
    this.duration = Duration.zero,
    this.artworkUrl,
    this.deviceId,
    this.albumId,
    this.isOnline = false,
    this.genre,
  });

  final String id;
  final String title;
  final String artist;
  final String? album;
  final String uri;
  final Duration duration;
  final String? artworkUrl;
  final int? deviceId;
  final int? albumId;
  final bool isOnline;
  final String? genre;

  String get subtitle {
    if (isOnline) return artist;
    final a = artist.trim();
    return a.isEmpty || a == '<unknown>' ? 'Unknown artist' : a;
  }

  String get durationLabel {
    final d = duration;
    if (d.inSeconds <= 0) return '--:--';
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'uri': uri,
        'duration': duration.inMilliseconds,
        'artworkUrl': artworkUrl,
        'deviceId': deviceId,
        'albumId': albumId,
        'isOnline': isOnline,
        'genre': genre,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Unknown track',
        artist: json['artist'] as String? ?? '',
        album: json['album'] as String?,
        uri: json['uri'] as String? ?? '',
        duration: Duration(milliseconds: (json['duration'] as num?)?.toInt() ?? 0),
        artworkUrl: json['artworkUrl'] as String?,
        deviceId: (json['deviceId'] as num?)?.toInt(),
        albumId: (json['albumId'] as num?)?.toInt(),
        isOnline: json['isOnline'] as bool? ?? false,
        genre: json['genre'] as String?,
      );
}
