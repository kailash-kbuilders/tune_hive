import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The olive background from the design: a soft glow at the top that fades
/// into near-black at the bottom.
class GradientBg extends StatelessWidget {
  const GradientBg({super.key, required this.child, this.glow = true});

  final Widget child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgTop, AppColors.bg, AppColors.bg],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          if (glow)
            Positioned(
              top: -160,
              left: -80,
              right: -80,
              child: IgnorePointer(
                child: Container(
                  height: 380,
                  decoration: const BoxDecoration(
                    gradient: RadialGradient(
                      colors: [Color(0x33B9F04A), Color(0x00000000)],
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

/// Standard rounded surface used for every card in the app.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
