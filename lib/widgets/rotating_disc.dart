import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The vinyl-style disc from the design: artwork inside, slow rotation while
/// playing, and a lime progress ring around it.
class RotatingDisc extends StatefulWidget {
  const RotatingDisc({
    super.key,
    required this.child,
    required this.spinning,
    required this.progress,
    this.size = 280,
    this.extraTurns = 0,
  });

  final Widget child;
  final bool spinning;
  final double progress;
  final double size;

  /// Extra rotation (in turns) added by hand, e.g. when the disc is used as a
  /// volume knob.
  final double extraTurns;

  @override
  State<RotatingDisc> createState() => _RotatingDiscState();
}

class _RotatingDiscState extends State<RotatingDisc> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 24));

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant RotatingDisc oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spinning && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inner = widget.size * 0.72;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(widget.size),
            painter: _RingPainter(progress: widget.progress),
          ),
          Container(
            width: widget.size * 0.9,
            height: widget.size * 0.9,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFF243014), Color(0xFF0D1208)],
                stops: [0.55, 1.0],
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => Transform.rotate(
              angle: (_controller.value + widget.extraTurns) * 2 * math.pi,
              child: child,
            ),
            child: Container(
              width: inner,
              height: inner,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: const [
                  BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 10)),
                ],
                border: Border.all(color: const Color(0x22FFFFFF), width: 1),
              ),
              child: ClipOval(child: widget.child),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: Color(0xFF10160A), shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0x1FFFFFFF);
    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [AppColors.lime, AppColors.limeSoft],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, track);
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      active,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.progress != progress;
}
