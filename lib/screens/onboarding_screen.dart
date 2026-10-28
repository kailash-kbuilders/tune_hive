import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/slide_to_start.dart';
import 'root_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    context.read<LibraryService>().completeOnboarding();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const RootShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    return Scaffold(
      body: GradientBg(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'TuneHive',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text.withOpacity(0.85),
                    letterSpacing: 0.4,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: FadeTransition(
                      opacity: fade,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.88, end: 1).animate(fade),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 320,
                              width: 320,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [Color(0x44B9F04A), Color(0x00000000)],
                                ),
                              ),
                            ),
                            Image.asset(
                              'assets/images/logo.png',
                              height: 275,
                              width: 275,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(fade),
                  child: FadeTransition(
                    opacity: fade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Start Your\nSonic Journey',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 30, height: 1.18),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tumhare phone ke saare gaane — ek clean, minimal player me. Koi account nahi, koi internet nahi.',
                          style: TextStyle(fontSize: 12.5, height: 1.6, color: AppColors.muted.withOpacity(0.95)),
                        ),
                        const SizedBox(height: 28),
                        SlideToStart(
                          label: 'Slide to start',
                          onCompleted: _start,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Slider ko aage kheencho — music turant shuru.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.muted.withOpacity(0.8)),
                        ),
                        const SizedBox(height: 26),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
