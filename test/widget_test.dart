import 'package:flutter_test/flutter_test.dart';
import 'package:tune_hive/models/song.dart';

void main() {
  test('song survives a JSON round trip', () {
    const song = Song(
      id: 'device:1',
      title: 'Test track',
      artist: 'Someone',
      uri: 'file:///music/test.mp3',
      duration: Duration(minutes: 3, seconds: 5),
    );

    final restored = Song.fromJson(song.toJson());

    expect(restored.id, song.id);
    expect(restored.title, song.title);
    expect(restored.duration, song.duration);
    expect(restored.durationLabel, '3:05');
    expect(restored.isOnline, isFalse);
  });

  test('duration label handles unknown length', () {
    const song = Song(id: 'x', title: 't', artist: 'a', uri: 'u');
    expect(song.durationLabel, '--:--');
  });
}
