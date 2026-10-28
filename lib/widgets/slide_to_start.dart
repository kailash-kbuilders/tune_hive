import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Slide-to-start control for the onboarding screen: drag the lime knob with
/// the arrow all the way to the right to open the app. Letting go early snaps
/// it back.
class SlideToStart extends StatefulWidget {
  const SlideToStart({
    super.key,
    required this.label,
    required this.onCompleted,
  });

  final String label;
  final VoidCallback onCompleted;

  @override
  State<SlideToStart> createState() => _SlideToStartState();
}

class _SlideToStartState extends State<SlideToStart> with SingleTickerProviderStateMixin {
  static const double _knob = 56;
  static const double _pad = 6;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 240));

  bool _completed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _complete() {
    if (_completed) return;
    _completed = true;
    _controller.animateTo(1, duration: const Duration(milliseconds: 120));
    widget.onCompleted();
  }

  void _onUpdate(DragUpdateDetails details, double travel) {
    if (_completed || travel <= 0) return;
    _controller.value = (_controller.value + details.delta.dx / travel).clamp(0.0, 1.0);
    if (_controller.value >= 1) _complete();
  }

  void _onEnd(DragEndDetails details) {
    if (_completed) return;
    if (_controller.value > 0.82) {
      _complete();
    } else {
      _controller.animateTo(0, duration: const Duration(milliseconds: 240), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final travel = (constraints.maxWidth - _knob - _pad * 2).clamp(1.0, double.infinity);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (details) => _onUpdate(details, travel),
          onHorizontalDragEnd: _onEnd,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final value = _controller.value;
              return Container(
                height: _knob + _pad * 2,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: AppColors.line),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: _pad * 2 + _knob + travel * value,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.lime.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(40),
                        ),
                      ),
                    ),
                    Center(
                      child: Opacity(
                        opacity: (1 - value * 1.4).clamp(0.0, 1.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.label,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: AppColors.text.withOpacity(0.9),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.keyboard_double_arrow_right_rounded,
                              size: 17,
                              color: AppColors.muted.withOpacity(0.9),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: _pad + travel * value,
                      top: _pad,
                      child: Container(
                        height: _knob,
                        width: _knob,
                        decoration: BoxDecoration(
                          color: AppColors.lime,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.lime.withOpacity(0.30),
                              blurRadius: 18,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF10160A),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
