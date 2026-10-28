import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/artwork.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/disc_with_volume.dart';
import '../widgets/sheets.dart';
import 'queue_screen.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  double _volume = 1.0;

  void _onVolume(double value) {
    setState(() => _volume = value);
    context.read<PlayerService>().setVolume(value);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final library = context.watch<LibraryService>();
    final song = player.current;

    if (song == null) {
      return Scaffold(
        body: GradientBg(
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Abhi kuch play nahi ho raha',
                      style: TextStyle(fontSize: 14, color: AppColors.muted)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Wapas', style: TextStyle(color: AppColors.lime)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final favourite = library.isFavourite(song);
    final sleep = player.sleepRemaining;

    return Scaffold(
      body: GradientBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => showSongMenu(context, song),
                      icon: const Icon(Icons.more_horiz_rounded, size: 24),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: StreamBuilder<Duration>(
                      stream: player.player.positionStream,
                      builder: (context, snapshot) {
                        final total = player.player.duration?.inMilliseconds ?? 0;
                        final pos = snapshot.data?.inMilliseconds ?? 0;
                        final progress = total <= 0 ? 0.0 : (pos / total).clamp(0.0, 1.0);
                        return DiscWithVolume(
                          spinning: player.isPlaying,
                          progress: progress,
                          size: 248,
                          volume: _volume,
                          onVolumeChanged: _onVolume,
                          child: SongArtwork(song: song, size: 180, radius: 0),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (song.isOnline) ...[
                                const Icon(Icons.public_rounded, size: 12, color: AppColors.muted),
                                const SizedBox(width: 5),
                              ],
                              Flexible(
                                child: Text(
                                  song.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => library.toggleFavourite(song),
                      icon: Icon(
                        favourite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: favourite ? AppColors.lime : AppColors.muted,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _SeekBar(player: player),
                if (player.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      player.error!,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.danger),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _RoundIcon(
                      icon: Icons.shuffle_rounded,
                      active: player.shuffleOn,
                      onTap: player.toggleShuffle,
                    ),
                    _RoundIcon(
                      icon: Icons.skip_previous_rounded,
                      size: 32,
                      onTap: player.previous,
                    ),
                    GestureDetector(
                      onTap: player.toggle,
                      child: Container(
                        height: 76,
                        width: 76,
                        decoration: BoxDecoration(
                          color: AppColors.lime,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.lime.withOpacity(0.28),
                              blurRadius: 26,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: player.isLoadingTrack
                            ? const Padding(
                                padding: EdgeInsets.all(26),
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4, color: Color(0xFF10160A)),
                              )
                            : Icon(
                                player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 38,
                                color: const Color(0xFF10160A),
                              ),
                      ),
                    ),
                    _RoundIcon(
                      icon: Icons.skip_next_rounded,
                      size: 32,
                      onTap: player.next,
                    ),
                    _RoundIcon(
                      icon: player.repeatMode == TrackRepeatMode.one
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      active: player.repeatMode != TrackRepeatMode.off,
                      onTap: player.cycleRepeat,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Pill(
                      label: speedLabel(player.speed),
                      icon: Icons.speed_rounded,
                      onTap: () => showSpeedSheet(context),
                    ),
                    _Pill(
                      label: sleep != null
                          ? sleepLabel(sleep)
                          : player.stopAtTrackEnd
                              ? 'End of track'
                              : 'Sleep',
                      icon: Icons.nightlight_round,
                      highlighted: sleep != null || player.stopAtTrackEnd,
                      onTap: () => showSleepSheet(context),
                    ),
                    _RoundIcon(
                      icon: Icons.graphic_eq_rounded,
                      onTap: () => showEqualizerSheet(context),
                    ),
                    _RoundIcon(
                      icon: Icons.replay_10_rounded,
                      onTap: player.skipBackward,
                    ),
                    _RoundIcon(
                      icon: Icons.forward_10_rounded,
                      onTap: player.skipForward,
                    ),
                    _RoundIcon(
                      icon: Icons.queue_music_rounded,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QueueScreen()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({required this.player});

  final PlayerService player;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragging;

  String _format(double milliseconds) {
    if (milliseconds <= 0) return '0:00';
    final total = Duration(milliseconds: milliseconds.round());
    final minutes = total.inMinutes;
    final seconds = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.player.player.positionStream,
      builder: (context, snapshot) {
        final total = widget.player.player.duration?.inMilliseconds.toDouble() ?? 0;
        final position = snapshot.data?.inMilliseconds.toDouble() ?? 0;
        final max = total > 0 ? total : 1.0;
        final value = (_dragging ?? position).clamp(0.0, max);
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                value: value,
                max: max,
                onChanged: (v) => setState(() => _dragging = v),
                onChangeEnd: (v) {
                  widget.player.seek(Duration(milliseconds: v.round()));
                  setState(() => _dragging = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_format(value),
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  Text(total > 0 ? _format(total) : '--:--',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.size = 22,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: size,
        color: active ? AppColors.lime : AppColors.text.withOpacity(0.85),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: highlighted ? AppColors.lime : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: highlighted ? AppColors.lime : AppColors.line),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 13, color: highlighted ? const Color(0xFF10160A) : AppColors.muted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: highlighted ? const Color(0xFF10160A) : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
