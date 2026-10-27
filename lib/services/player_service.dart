import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/song.dart';

enum TrackRepeatMode { off, all, one }

/// Owns the single AudioPlayer for the whole app: queue, shuffle, repeat,
/// speed and the sleep timer. Background playback and the lock-screen
/// controls come from just_audio_background.
class PlayerService extends ChangeNotifier {
  PlayerService() {
    _init();
  }

  final AudioPlayer _player = AudioPlayer();
  final List<Song> _queue = [];
  List<int> _order = [];
  int _orderPos = 0;

  Song? _current;
  bool _shuffle = false;
  TrackRepeatMode _repeat = TrackRepeatMode.off;
  double _speed = 1.0;
  bool _loadingTrack = false;
  String? _error;

  Timer? _sleepTimer;
  Timer? _sleepTicker;
  DateTime? _sleepAt;
  bool _stopAtTrackEnd = false;

  AudioPlayer get player => _player;
  Song? get current => _current;
  List<Song> get queue => List.unmodifiable(_queue);
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

  Future<void> _init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (_) {
      // Audio focus is best-effort; playback still works without it.
    }
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _handleCompleted();
      }
      notifyListeners();
    });
    _player.errorStream.listen((e) {
      _error = e.message ?? 'Playback error';
      notifyListeners();
    });
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
    unawaited(next());
  }

  /// Replace the queue and start playing at [startIndex].
  Future<void> playSongs(List<Song> songs, int startIndex) async {
    if (songs.isEmpty) return;
    _queue
      ..clear()
      ..addAll(songs);
    final start = startIndex.clamp(0, _queue.length - 1);
    _order = List<int>.generate(_queue.length, (i) => i);
    if (_shuffle) {
      _order.shuffle();
      _order.remove(start);
      _order.insert(0, start);
      _orderPos = 0;
    } else {
      _orderPos = start;
    }
    await _load(autoPlay: true);
  }

  Future<void> addNext(Song song) async {
    if (_queue.isEmpty) {
      await playSongs([song], 0);
      return;
    }
    _queue.add(song);
    _order.add(_queue.length - 1);
    notifyListeners();
  }

  Future<void> _load({required bool autoPlay}) async {
    if (_order.isEmpty || _queue.isEmpty) return;
    final song = _queue[_order[_orderPos]];
    _current = song;
    _error = null;
    _loadingTrack = true;
    notifyListeners();
    try {
      if (song.uri.isEmpty) throw StateError('Track has no source');
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(song.uri),
          tag: MediaItem(
            id: song.id,
            title: song.title,
            artist: song.subtitle,
            album: song.album ?? 'TuneHive',
            artUri: (song.artworkUrl != null && song.artworkUrl!.isNotEmpty)
                ? Uri.parse(song.artworkUrl!)
                : null,
          ),
        ),
      );
      await _player.setSpeed(_speed);
      if (autoPlay) unawaited(_player.play());
    } catch (_) {
      _error = 'Ye track play nahi ho paya';
    } finally {
      _loadingTrack = false;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    if (_current == null) return;
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

  Future<void> next() async {
    if (_order.isEmpty) return;
    if (_orderPos + 1 < _order.length) {
      _orderPos++;
      await _load(autoPlay: true);
    } else if (_repeat == TrackRepeatMode.all) {
      _orderPos = 0;
      await _load(autoPlay: true);
    } else {
      await _player.pause();
      await _player.seek(Duration.zero);
    }
  }

  Future<void> previous() async {
    if (_order.isEmpty) return;
    if (_player.position.inSeconds > 4) {
      await _player.seek(Duration.zero);
      return;
    }
    if (_orderPos > 0) {
      _orderPos--;
      await _load(autoPlay: true);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  Future<void> playAt(int queueIndex) async {
    final pos = _order.indexOf(queueIndex);
    if (pos < 0) return;
    _orderPos = pos;
    await _load(autoPlay: true);
  }

  /// Drag-and-drop reorder in the queue screen. The currently playing track
  /// keeps playing; only the order around it changes.
  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex > oldIndex) newIndex -= 1;
    final currentId = _current?.id;
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex.clamp(0, _queue.length), song);
    _order = List<int>.generate(_queue.length, (i) => i);
    final currentPos = currentId == null ? -1 : _queue.indexWhere((s) => s.id == currentId);
    _orderPos = currentPos < 0 ? 0 : currentPos;
    notifyListeners();
  }

  Future<void> seek(Duration to) async {
    var target = to;
    if (target.isNegative) target = Duration.zero;
    final total = _player.duration;
    if (total != null && target > total) target = total;
    await _player.seek(target);
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
    if (_queue.isEmpty) {
      notifyListeners();
      return;
    }
    final currentIndex = _order.isEmpty ? 0 : _order[_orderPos];
    if (_shuffle) {
      _order = List<int>.generate(_queue.length, (i) => i)..shuffle();
      _order.remove(currentIndex);
      _order.insert(0, currentIndex);
      _orderPos = 0;
    } else {
      _order = List<int>.generate(_queue.length, (i) => i);
      _orderPos = currentIndex;
    }
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
    notifyListeners();
  }

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

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _sleepTicker?.cancel();
    _player.dispose();
    super.dispose();
  }
}
