import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
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
  // Lock-screen controls + background playback.
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.tunehive.playback',
    androidNotificationChannelName: 'TuneHive playback',
    androidNotificationOngoing: true,
  );
  final library = LibraryService();
  await library.load();
  runApp(TuneHiveApp(library: library));
}

class TuneHiveApp extends StatelessWidget {
  const TuneHiveApp({super.key, required this.library});

  final LibraryService library;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LibraryService>.value(value: library),
        ChangeNotifierProvider<PlayerService>(create: (_) => PlayerService()),
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
