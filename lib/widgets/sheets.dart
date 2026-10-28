import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' show AndroidEqualizerParameters;
import 'package:provider/provider.dart';

import '../models/song.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';

const List<double> kSpeedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

String speedLabel(double value) {
  if (value == value.roundToDouble()) return '${value.toStringAsFixed(1)}x';
  return '${value.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '')}x';
}

String sleepLabel(Duration d) {
  final total = d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  if (m == 0) return '${s}s';
  return s == 0 ? '${m}m' : '${m}m ${s}s';
}

Widget _sheetHandle() => Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

Widget _sheetTitle(BuildContext context, String title, {String? subtitle}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      ],
    ),
  );
}

Future<void> showSpeedSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            _sheetTitle(sheetContext, 'Playback speed',
                subtitle: 'Podcasts aur audiobooks ke liye kaam aata hai'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kSpeedOptions.map((value) {
                  final active = (player.speed - value).abs() < 0.001;
                  return GestureDetector(
                    onTap: () {
                      player.setSpeed(value);
                      Navigator.of(sheetContext).pop();
                    },
                    child: Container(
                      width: 86,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? AppColors.lime : AppColors.cardSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: active ? AppColors.lime : AppColors.line),
                      ),
                      child: Text(
                        speedLabel(value),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: active ? const Color(0xFF10160A) : AppColors.text,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      );
    },
  );
}

Future<void> showSleepSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  final options = <String, Duration?>{
    'Off': null,
    '5 min': const Duration(minutes: 5),
    '10 min': const Duration(minutes: 10),
    '15 min': const Duration(minutes: 15),
    '30 min': const Duration(minutes: 30),
    '45 min': const Duration(minutes: 45),
    '60 min': const Duration(minutes: 60),
  };
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) {
      final remaining = player.sleepRemaining;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            _sheetTitle(
              sheetContext,
              'Sleep timer',
              subtitle: remaining != null
                  ? 'Bache hue: ${sleepLabel(remaining)}'
                  : player.stopAtTrackEnd
                      ? 'Track khatam hone par rukega'
                      : 'Music band hone ka time chuno',
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ...options.entries.map((entry) {
                    return GestureDetector(
                      onTap: () {
                        player.setSleepTimer(entry.value);
                        Navigator.of(sheetContext).pop();
                      },
                      child: Container(
                        width: 86,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.cardSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () async {
                      Navigator.of(sheetContext).pop();
                      final minutes = await promptForSleepMinutes(context);
                      if (minutes == null) return;
                      player.setSleepTimer(Duration(minutes: minutes));
                    },
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.cardSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Text(
                        'Custom',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      player.sleepAtEndOfTrack();
                      Navigator.of(sheetContext).pop();
                    },
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: player.stopAtTrackEnd ? AppColors.lime : AppColors.cardSoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: player.stopAtTrackEnd ? AppColors.lime : AppColors.line,
                        ),
                      ),
                      child: Text(
                        'End of track',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: player.stopAtTrackEnd ? const Color(0xFF10160A) : AppColors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],
        ),
      );
    },
  );
}

Future<void> showSongMenu(BuildContext context, Song song) async {
  final library = context.read<LibraryService>();
  final player = context.read<PlayerService>();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              title: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                song.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
              ),
            ),
            _MenuRow(
              icon: Icons.playlist_play_rounded,
              label: 'Play next',
              onTap: () {
                player.addNext(song);
                Navigator.of(sheetContext).pop();
              },
            ),
            _MenuRow(
              icon: library.isFavourite(song) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              label: library.isFavourite(song) ? 'Remove from favourites' : 'Add to favourites',
              onTap: () {
                library.toggleFavourite(song);
                Navigator.of(sheetContext).pop();
              },
            ),
            _MenuRow(
              icon: Icons.queue_music_rounded,
              label: 'Add to playlist',
              onTap: () {
                Navigator.of(sheetContext).pop();
                showPlaylistPicker(context, song);
              },
            ),
            _MenuRow(
              icon: Icons.info_outline_rounded,
              label: 'Song info',
              onTap: () {
                Navigator.of(sheetContext).pop();
                showSongInfo(context, song);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Icon(icon, size: 20, color: AppColors.lime),
      title: Text(label, style: const TextStyle(fontSize: 13.5)),
      onTap: onTap,
    );
  }
}

Future<void> showPlaylistPicker(BuildContext context, Song song) async {
  final library = context.read<LibraryService>();
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) {
      final names = library.playlistNames;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            _sheetTitle(sheetContext, 'Add to playlist'),
            if (names.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: Text(
                  'Abhi koi playlist nahi hai — neeche se banao.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            ...names.map((name) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.queue_music_rounded, size: 20, color: AppColors.lime),
                  title: Text(name, style: const TextStyle(fontSize: 13.5)),
                  onTap: () {
                    library.addToPlaylist(name, song);
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('"$name" me add ho gaya')),
                    );
                  },
                )),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.add_rounded, size: 22, color: AppColors.lime),
              title: const Text('New playlist', style: TextStyle(fontSize: 13.5)),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final name = await promptForPlaylistName(context);
                if (name == null) return;
                await library.createPlaylist(name);
                await library.addToPlaylist(name, song);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$name" bana aur gaana add ho gaya')),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

Future<String?> promptForPlaylistName(BuildContext context) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.cardSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('New playlist', style: TextStyle(fontSize: 17)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Playlist ka naam',
          hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
          filled: true,
          fillColor: AppColors.card,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
          child: const Text('Create', style: TextStyle(color: AppColors.lime)),
        ),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.isEmpty) return null;
  return name;
}

Future<void> showSongInfo(BuildContext context, Song song) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.cardSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text(song.title, style: const TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoLine('Artist', song.subtitle),
          _infoLine('Album', song.album ?? '—'),
          _infoLine('Duration', song.durationLabel),
          _infoLine('Source', song.isOnline ? 'Internet Archive (Creative Commons)' : 'Device'),
          if (song.genre != null) _infoLine('Type', song.genre!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close', style: TextStyle(color: AppColors.lime)),
        ),
      ],
    ),
  );
}

Widget _infoLine(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12.5)),
        ),
      ],
    ),
  );
}


// --------------------------------------------------------------- equalizer --

String _freqLabel(double hz) {
  if (hz >= 1000) {
    final k = hz / 1000;
    return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}k';
  }
  return hz.round().toString();
}

Future<void> showEqualizerSheet(BuildContext context) async {
  final player = context.read<PlayerService>();
  final messenger = ScaffoldMessenger.of(context);
  if (!player.equalizerSupported) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Equalizer sirf Android devices pe milta hai')),
    );
    return;
  }
  final params = await player.equalizerParameters();
  if (params == null) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Pehle koi gaana play karo — uske baad equalizer set ho jaata hai'),
      ),
    );
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    builder: (_) => _EqualizerSheet(player: player, params: params),
  );
}

class _EqualizerSheet extends StatefulWidget {
  const _EqualizerSheet({required this.player, required this.params});

  final PlayerService player;
  final AndroidEqualizerParameters params;

  @override
  State<_EqualizerSheet> createState() => _EqualizerSheetState();
}

class _EqualizerSheetState extends State<_EqualizerSheet> {
  late bool _enabled = widget.player.equalizerEnabled;
  late final List<double> _gains =
      widget.params.bands.map((band) => band.gain).toList();

  void _applyPreset(String name) {
    final bands = widget.params.bands;
    final max = widget.params.maxDecibels;
    final min = widget.params.minDecibels;
    for (var i = 0; i < bands.length; i++) {
      double gain;
      switch (name) {
        case 'Bass':
          gain = i <= 1 ? max * 0.75 : (i == 2 ? max * 0.25 : 0);
          break;
        case 'Vocal':
          gain = i == bands.length ~/ 2 ? max * 0.55 : 0;
          break;
        case 'Treble':
          gain = i >= bands.length - 2 ? max * 0.65 : 0;
          break;
        default:
          gain = 0;
      }
      final value = gain.clamp(min, max);
      setState(() => _gains[i] = value);
      bands[i].setGain(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bands = widget.params.bands;
    final min = widget.params.minDecibels;
    final max = widget.params.maxDecibels;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sheetHandle(),
            Row(
              children: [
                Expanded(
                  child: _sheetTitle(
                    context,
                    'Equalizer',
                    subtitle: '${bands.length} bands · sirf is device pe',
                  ),
                ),
                Switch(
                  value: _enabled,
                  activeColor: AppColors.lime,
                  onChanged: (value) async {
                    setState(() => _enabled = value);
                    await widget.player.setEqualizerEnabled(value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final preset in const ['Flat', 'Bass', 'Vocal', 'Treble'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _applyPreset(preset),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.cardSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text(
                          preset,
                          style: const TextStyle(fontSize: 12, color: AppColors.text),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < bands.length; i++)
              Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      _freqLabel(bands[i].centerFrequency),
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _gains[i].clamp(min, max),
                      min: min,
                      max: max,
                      onChanged: (value) {
                        setState(() => _gains[i] = value);
                        bands[i].setGain(value);
                      },
                    ),
                  ),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${_gains[i] > 0 ? '+' : ''}${_gains[i].toStringAsFixed(1)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            Text(
              _enabled
                  ? 'Bands ko upar-neeche karke apna sound banao.'
                  : 'Equalizer band hai — upar switch on kar do.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}


Future<int?> promptForSleepMinutes(BuildContext context) async {
  final controller = TextEditingController();
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.cardSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Sleep timer', style: TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kitne minute baad music band ho?',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Jaise 25',
              hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
              filled: true,
              fillColor: AppColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Set', style: TextStyle(color: AppColors.lime)),
        ),
      ],
    ),
  );
  controller.dispose();
  final minutes = int.tryParse((value ?? '').trim());
  if (minutes == null || minutes <= 0) return null;
  return minutes.clamp(1, 600);
}
