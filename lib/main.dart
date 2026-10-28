import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/onboarding_screen.dart';
import 'screens/root_shell.dart';
import 'services/device_music_service.dart';
import 'services/library_service.dart';
import 'services/online_music_service.dart';
import 'services/player_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final library = LibraryService();
  await library.load();

  // audio_service owns the notification and lock-screen controls. We give it
  // only previous / play-pause / next, so there is no stop button to close the
  // player by accident.
  final playerService = await AudioService.init<PlayerService>(
    builder: PlayerService.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.tunehive.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationChannelDescription: 'Music controls for TuneHive',
      androidNotificationIcon: 'drawable/ic_stat_tunehive',
      notificationColor: Color(0xFFB9F04A),
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationClickStartsActivity: true,
      preloadArtwork: true,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
    ),
  );

  // Bring back whatever was queued last time, paused where it stopped.
  unawaited(playerService.restoreQueue());

  runApp(TuneHiveApp(library: library, playerService: playerService));
}

class TuneHiveApp extends StatelessWidget {
  const TuneHiveApp({super.key, required this.library, required this.playerService});

  final LibraryService library;
  final PlayerService playerService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LibraryService>.value(value: library),
        ChangeNotifierProvider<PlayerService>.value(value: playerService),
        ChangeNotifierProvider<DeviceMusicService>(create: (_) => DeviceMusicService()),
        Provider<OnlineMusicService>(create: (_) => OnlineMusicService()),
      ],
      child: MaterialApp(
        title: 'TuneHive',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: library.onboarded ? const RootShell() : const OnboardingScreen(),
      ),
    );
  }
}
