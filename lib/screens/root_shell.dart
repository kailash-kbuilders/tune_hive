import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/mini_player.dart';
import 'favourites_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [
              HomeScreen(),
              SearchScreen(),
              FavouritesScreen(),
              ProfileScreen(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiniPlayer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Container(
                      height: 66,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(33),
                        border: Border.all(color: AppColors.line),
                        boxShadow: const [
                          BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10)),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _NavButton(
                            icon: Icons.home_rounded,
                            active: _index == 0,
                            onTap: () => setState(() => _index = 0),
                          ),
                          _NavButton(
                            icon: Icons.search_rounded,
                            active: _index == 1,
                            onTap: () => setState(() => _index = 1),
                          ),
                          _NavButton(
                            icon: Icons.favorite_rounded,
                            active: _index == 2,
                            onTap: () => setState(() => _index = 2),
                          ),
                          _NavButton(
                            icon: Icons.person_outline_rounded,
                            active: _index == 3,
                            onTap: () => setState(() => _index = 3),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.active, required this.onTap});

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        width: active ? 56 : 46,
        decoration: BoxDecoration(
          color: active ? AppColors.lime : Colors.transparent,
          borderRadius: BorderRadius.circular(23),
        ),
        child: Icon(
          icon,
          size: 22,
          color: active ? const Color(0xFF10160A) : AppColors.muted,
        ),
      ),
    );
  }
}
