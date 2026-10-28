import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import 'device_music_service.dart';

enum TrackRepeatMode { off, all, one }

/// The playback engine and the lock-screen / notification service in one.
///
/// It extends BaseAudioHandler so the notification shows only previous,
/// play/pause and next — no stop button — and every track gets a softly
/// blurred version of its artwork as the notification image.
class PlayerService extends BaseAudioHandler with QueueHandler, SeekHandler, ChangeNotifier {
  PlayerService() {
    _init();
  }

  final AndroidEqualizer _equalizer = AndroidEqualizer();
  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer]),
  );

  final List<Song> _songs = [];
  final Map<String, Uri?> _artCache = {};

  Song? _current;
  bool _shuffle = false;
  TrackRepeatMode _repeat = TrackRepeatMode.off;
  double _speed = 1.0;
  bool _loadingTrack = false;
  String? _error;

  Timer? _sleepTimer;
  Timer? _sleepTicker;
  Timer? _positionTicker;
  DateTime? _sleepAt;
  bool _stopAtTrackEnd = false;

  AudioPlayer get player => _player;
  Song? get current => _current;
  List<Song> get songs => List.unmodifiable(_songs);
  bool get shuffleOn => _shuffle;
  TrackRepeatMode get repeatMode => _repeat;
  double get speed => _speed;
  String? get error => _error;
  bool get isLoadingTrack => _loadingTrack;
  bool get isPlaying => _player.playing;
  bool get stopAtTrackEnd => _stopAtTrackEnd;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  DateTime? get sleepAt => _sleepAt;

  Duration? get sleepRemaining {
    final at = _sleepAt;
    if (at == null) return null;
    final left = at.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  bool get equalizerSupported => !kIsWeb && Platform.isAndroid;
  bool get equalizerEnabled => _equalizer.enabled;

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // Audio focus is best effort.
    }

    _player.playerStateStream.listen((state) {
      _broadcastState();
      if (state.processingState == ProcessingState.completed) {
        _handleCompleted();
      }
      if (!state.playing) unawaited(_saveQueue());
      notifyListeners();
    });

    _player.currentIndexStream.listen((index) {
      if (index == null || index < 0 || index >= _songs.length) return;
      _current = _songs[index];
      mediaItem.add(_mediaItemFor(_current!));
      unawaited(_refreshArt(_current!));
      _broadcastState();
      unawaited(_saveQueue());
      notifyListeners();
    });

    _player.errorStream.listen((error) {
      _error = error.message ?? 'Playback error';
      notifyListeners();
    });

    _positionTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_player.playing) _broadcastState();
    });
  }

  // --------------------------------------------------------- persistence ---

  /// The queue survives app restarts — it is written to disk after every
  /// track change and pause, and restored when the app opens again.
  Future<void> _saveQueue() async {
    if (_songs.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'queue_songs', jsonEncode(_songs.map((song) => song.toJson()).toList()));
      await prefs.setInt('queue_index', _player.currentIndex ?? 0);
      await prefs.setInt('queue_pos', _player.position.inMilliseconds);
    } catch (_) {
      // Saving is best effort.
    }
  }

  Future<void> restoreQueue() async {
    if (_songs.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('queue_songs');
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final songs = decoded
          .whereType<Map>()
          .map((item) => Song.fromJson(Map<String, dynamic>.from(item)))
          .where((song) => song.uri.isNotEmpty)
          .toList();
      if (songs.isEmpty) return;
      _songs
        ..clear()
        ..addAll(songs);
      var index = prefs.getInt('queue_index') ?? 0;
      if (index < 0 || index >= songs.length) index = 0;
      final position = Duration(milliseconds: prefs.getInt('queue_pos') ?? 0);
      await _loadSources(initialIndex: index, autoPlay: false, position: position);
    } catch (_) {
      // Nothing to restore.
    }
  }

  // ------------------------------------------------------------ playback ---

  /// Replaces the queue and starts at [startIndex].
  Future<void> playSongs(List<Song> songs, int startIndex) async {
    if (songs.isEmpty) return;
    // A tap while the previous track is still loading must not start a second
    // load — that is what made the app feel like it needed two taps.
    if (_loadingTrack) return;
    final selected = songs[startIndex.clamp(0, songs.length - 1)];
    _songs
      ..clear()
      ..addAll(songs.where((song) => song.uri.isNotEmpty));
    if (_songs.isEmpty) return;
    var start = _songs.indexWhere((song) => song.id == selected.id);
    if (start < 0) start = 0;
    await _loadSources(initialIndex: start, autoPlay: true);
  }

  Future<void> _loadSources({
    required int initialIndex,
    required bool autoPlay,
    Duration? position,
  }) async {
    final sources = <AudioSource>[];
    final items = <MediaItem>[];
    for (final song in _songs) {
      final item = _mediaItemFor(song);
      items.add(item);
      sources.add(AudioSource.uri(Uri.parse(song.uri), tag: item));
    }
    if (sources.isEmpty) return;

    _loadingTrack = true;
    _error = null;
    notifyListeners();
    try {
      queue.add(items);
      await _player.setAudioSources(
        sources,
        initialIndex: initialIndex.clamp(0, sources.length - 1),
        initialPosition: position ?? Duration.zero,
      );
      await _player.setSpeed(_speed);
      await _player.setLoopMode(_loopMode);
      await _player.setShuffleModeEnabled(_shuffle);
      if (autoPlay) unawaited(_player.play());
    } catch (_) {
      _error = 'Ye track play nahi ho paya';
    } finally {
      _loadingTrack = false;
      notifyListeners();
    }
  }

  MediaItem _mediaItemFor(Song song) => MediaItem(
        id: song.id,
        title: song.title,
        artist: song.subtitle,
        album: song.album ?? 'TuneHive',
        duration: song.duration.inSeconds > 0 ? song.duration : null,
        artUri: _artCache[song.id],
      );

  Future<void> toggle() async {
    if (_songs.isEmpty) return;
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> next() => skipToNext();

  Future<void> previous() => skipToPrevious();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (_player.hasNext) await _player.seekToNext();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 4 || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
      return;
    }
    await _player.seekToPrevious();
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= _songs.length) return;
    await _player.seek(Duration.zero, index: index);
    if (!_player.playing) await _player.play();
  }

  Future<void> skipForward() => seek(_player.position + const Duration(seconds: 10));

  Future<void> skipBackward() => seek(_player.position - const Duration(seconds: 10));

  Future<void> setSpeed(double value) async {
    _speed = value;
    await _player.setSpeed(value);
    notifyListeners();
  }

  Future<void> setVolume(double value) => _player.setVolume(value);

  void toggleShuffle() {
    _shuffle = !_shuffle;
    unawaited(_player.setShuffleModeEnabled(_shuffle));
    _broadcastState();
    notifyListeners();
  }

  void cycleRepeat() {
    switch (_repeat) {
      case TrackRepeatMode.off:
        _repeat = TrackRepeatMode.all;
        break;
      case TrackRepeatMode.all:
        _repeat = TrackRepeatMode.one;
        break;
      case TrackRepeatMode.one:
        _repeat = TrackRepeatMode.off;
        break;
    }
    unawaited(_player.setLoopMode(_loopMode));
    _broadcastState();
    notifyListeners();
  }

  LoopMode get _loopMode => switch (_repeat) {
        TrackRepeatMode.off => LoopMode.off,
        TrackRepeatMode.all => LoopMode.all,
        TrackRepeatMode.one => LoopMode.one,
      };

  Future<void> addNext(Song song) async {
    if (song.uri.isEmpty) return;
    if (_songs.isEmpty) {
      await playSongs([song], 0);
      return;
    }
    final currentIndex = _player.currentIndex ?? 0;
    _songs.insert((currentIndex + 1).clamp(0, _songs.length), song);
    await _loadSources(
      initialIndex: currentIndex,
      autoPlay: _player.playing,
      position: _player.position,
    );
  }

  /// Drag-and-drop reorder in the queue screen; the current track keeps
  /// playing from where it was.
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _songs.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final currentSong = _current;
    final position = _player.position;
    final playing = _player.playing;
    final song = _songs.removeAt(oldIndex);
    _songs.insert(newIndex.clamp(0, _songs.length), song);
    var index = currentSong == null ? 0 : _songs.indexWhere((s) => s.id == currentSong.id);
    if (index < 0) index = 0;
    await _loadSources(initialIndex: index, autoPlay: playing, position: position);
  }

  void _handleCompleted() {
    if (_stopAtTrackEnd) {
      _stopAtTrackEnd = false;
      _clearSleep();
      _player.pause();
      _player.seek(Duration.zero);
      notifyListeners();
      return;
    }
    if (_repeat == TrackRepeatMode.one) {
      _player.seek(Duration.zero);
      unawaited(_player.play());
      return;
    }
    if (!_player.hasNext) unawaited(_player.pause());
  }

  // ---------------------------------------------------------- equalizer ---

  Future<AndroidEqualizerParameters?> equalizerParameters() async {
    if (!equalizerSupported) return null;
    try {
      return await _equalizer.parameters.timeout(const Duration(seconds: 4));
    } catch (_) {
      return null;
    }
  }

  Future<void> setEqualizerEnabled(bool value) async {
    try {
      await _equalizer.setEnabled(value);
    } catch (_) {
      // Some devices have no equalizer effect.
    }
    notifyListeners();
  }

  // -------------------------------------------------------- sleep timer ---

  void setSleepTimer(Duration? after) {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepTimer = null;
    _sleepTicker = null;
    _sleepAt = null;
    _stopAtTrackEnd = false;
    if (after == null) {
      notifyListeners();
      return;
    }
    _sleepAt = DateTime.now().add(after);
    _sleepTimer = Timer(after, () async {
      await _player.pause();
      _clearSleep();
    });
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sleepAt == null) return;
      if (DateTime.now().isAfter(_sleepAt!)) {
        _clearSleep();
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void sleepAtEndOfTrack() {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepTimer = null;
    _sleepTicker = null;
    _sleepAt = null;
    _stopAtTrackEnd = true;
    notifyListeners();
  }

  void _clearSleep() {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _sleepTimer = null;
    _sleepTicker = null;
    _sleepAt = null;
    _stopAtTrackEnd = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // --------------------------------------------------- notification bits ---

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      androidCompactActionIndices: const [0, 1, 2],
      systemActions: const {MediaAction.seek},
      processingState: _processingState(_player.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
      repeatMode: switch (_repeat) {
        TrackRepeatMode.off => AudioServiceRepeatMode.none,
        TrackRepeatMode.all => AudioServiceRepeatMode.all,
        TrackRepeatMode.one => AudioServiceRepeatMode.one,
      },
      shuffleMode:
          _shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    ));
  }

  AudioProcessingState _processingState(ProcessingState state) => switch (state) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      };

  Future<void> _refreshArt(Song song) async {
    if (!_artCache.containsKey(song.id)) {
      _artCache[song.id] = await _blurredArt(song);
    }
    final art = _artCache[song.id];
    final item = mediaItem.value;
    if (art != null && item != null && item.id == song.id && item.artUri != art) {
      mediaItem.add(item.copyWith(artUri: art));
    }
  }

  Future<Uint8List?> _artBytes(Song song) async {
    try {
      if (song.deviceId != null) return ArtworkCache.load(song.deviceId!);
      final url = song.artworkUrl;
      if (url == null || url.isEmpty) return null;
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  /// A soft blur — readable as art, not a sharp photo.
  Future<Uri?> _blurredArt(Song song) async {
    try {
      final bytes = await _artBytes(song);
      if (bytes == null || bytes.isEmpty) return null;
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 512);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()
        ..imageFilter =
            ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7, tileMode: ui.TileMode.clamp);
      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Rect.fromLTWH(-14, -14, width + 28.0, height + 28.0),
        paint,
      );
      final picture = recorder.endRecording();
      final blurred = await picture.toImage(width, height);
      final data = await blurred.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      blurred.dispose();
      if (data == null) return null;
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/notif_${song.id.hashCode}.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return Uri.file(file.path);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _positionTicker?.cancel();
    _player.dispose();
    super.dispose();
  }
}
