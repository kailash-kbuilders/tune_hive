import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'rotating_disc.dart';

/// The vinyl disc, doubling as a volume knob: turn it with a finger and the
/// volume follows. The level appears beside the disc only while turning.
class DiscWithVolume extends StatefulWidget {
  const DiscWithVolume({
    super.key,
    required this.child,
    required this.spinning,
    required this.progress,
    required this.volume,
    required this.onVolumeChanged,
    this.size = 250,
  });

  final Widget child;
  final bool spinning;
  final double progress;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final double size;

  @override
  State<DiscWithVolume> createState() => _DiscWithVolumeState();
}

class _DiscWithVolumeState extends State<DiscWithVolume> {
  double _turns = 0;
  double? _lastAngle;
  late double _volume = widget.volume;
  bool _show = false;
  Timer? _hide;

  @override
  void didUpdateWidget(covariant DiscWithVolume oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_show) _volume = widget.volume;
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  Offset get _center => Offset(widget.size / 2, widget.size / 2);

  double _angleOf(Offset local) =>
      math.atan2(local.dy - _center.dy, local.dx - _center.dx);

  void _start(DragStartDetails details) {
    _lastAngle = _angleOf(details.localPosition);
    _hide?.cancel();
    setState(() => _show = true);
  }

  void _update(DragUpdateDetails details) {
    final angle = _angleOf(details.localPosition);
    final previous = _lastAngle;
    _lastAngle = angle;
    if (previous == null) return;
    var delta = angle - previous;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    final turns = delta / (2 * math.pi);
    final next = (_volume + turns * 1.6).clamp(0.0, 1.0);
    setState(() {
      _turns += turns * 0.55;
      _volume = next;
    });
    widget.onVolumeChanged(next);
  }

  void _end(DragEndDetails details) {
    _lastAngle = null;
    _hide?.cancel();
    _hide = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _show = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onPanStart: _start,
            onPanUpdate: _update,
            onPanEnd: _end,
            child: RotatingDisc(
              spinning: widget.spinning,
              progress: widget.progress,
              size: widget.size,
              extraTurns: _turns,
              child: widget.child,
            ),
          ),
          Positioned(
            right: -30,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _show ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _volume <= 0.01
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        size: 15,
                        color: AppColors.lime,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 58,
                        width: 5,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0x33FFFFFF),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            FractionallySizedBox(
                              heightFactor: _volume.clamp(0.02, 1.0),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.lime,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${(_volume * 100).round()}',
                        style: const TextStyle(fontSize: 9.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
