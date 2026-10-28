import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/device_music_service.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/sheets.dart';
import 'history_screen.dart';
import 'playlists_screen.dart';
import 'queue_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final library = context.read<LibraryService>();
    final controller = TextEditingController(text: library.listenerName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Tumhara naam', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
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
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save', style: TextStyle(color: AppColors.lime)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await library.setListenerName(name);
    }
  }

  void _showSources(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Music sources', style: TextStyle(fontSize: 16)),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Device — phone me rakhi saari audio files (30 second se lambi).',
                style: TextStyle(fontSize: 12.5, height: 1.6),
              ),
              SizedBox(height: 10),
              Text(
                '2. Audius — artists apna music khud upload karte hain, full songs, bina key ke.',
                style: TextStyle(fontSize: 12.5, height: 1.6),
              ),
              SizedBox(height: 10),
              Text(
                '3. Deezer aur Apple Music — inke public endpoints se latest Indian songs ka 30 second official preview chalta hai, bina signup ke. Isliye search me naye gaane turant milte hain.',
                style: TextStyle(fontSize: 12.5, height: 1.6),
              ),
              SizedBox(height: 10),
              Text(
                '4. Internet Archive — Creative Commons aur public-domain recordings.',
                style: TextStyle(fontSize: 12.5, height: 1.6),
              ),
              SizedBox(height: 14),
              Text(
                'YouTube ka music jaan bujh ke shaamil nahi kiya — uske stream bina license use karna app ko Play Store se ban karwa deta hai.',
                style: TextStyle(fontSize: 12, height: 1.6, color: AppColors.muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Samajh gaya', style: TextStyle(color: AppColors.lime)),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('TuneHive', style: TextStyle(fontSize: 16)),
        content: const Text(
          'Version 1.0.0\n\nEk clean, minimal music player — device ke gaane aur free Creative Commons music, ek hi jagah.\n\nPermissions: sirf audio files padhne ki permission. Iske alawa kuch nahi.',
          style: TextStyle(fontSize: 12.5, height: 1.6),
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

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final device = context.watch<DeviceMusicService>();
    final player = context.watch<PlayerService>();
    final sleep = player.sleepRemaining;

    return GradientBg(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 200),
          children: [
            Row(
              children: [
                Container(
                  height: 62,
                  width: 62,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Image.asset('assets/images/logo.png'),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(library.listenerName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                        '${device.songs.length} songs on this device',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _editName(context),
                  icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _StatCard(value: '${device.songs.length}', label: 'Device'),
                const SizedBox(width: 10),
                _StatCard(value: '${library.favourites.length}', label: 'Favourites'),
                const SizedBox(width: 10),
                _StatCard(value: '${library.playlistNames.length}', label: 'Playlists'),
              ],
            ),
            const SizedBox(height: 26),
            const _GroupLabel('Library'),
            _Tile(
              icon: Icons.queue_music_rounded,
              title: 'Playlists',
              subtitle: '${library.playlistNames.length} playlists',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
              ),
            ),
            _Tile(
              icon: Icons.history_rounded,
              title: 'History',
              subtitle: library.topArtist == null
                  ? '${library.recent.length} songs'
                  : '${library.recent.length} songs · ${library.topArtist}',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              ),
            ),
            _Tile(
              icon: Icons.queue_rounded,
              title: 'Current queue',
              subtitle: '${player.songs.length} songs',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QueueScreen()),
              ),
            ),
            const SizedBox(height: 18),
            const _GroupLabel('Playback'),
            _Tile(
              icon: Icons.nightlight_round,
              title: 'Sleep timer',
              subtitle: sleep != null
                  ? 'Bache hue ${sleepLabel(sleep)}'
                  : player.stopAtTrackEnd
                      ? 'Track khatam hone par rukega'
                      : 'Off',
              onTap: () => showSleepSheet(context),
            ),
            _Tile(
              icon: Icons.speed_rounded,
              title: 'Playback speed',
              subtitle: speedLabel(player.speed),
              onTap: () => showSpeedSheet(context),
            ),
            _Tile(
              icon: Icons.graphic_eq_rounded,
              title: 'Equalizer',
              subtitle: player.equalizerSupported
                  ? 'Bass, vocal aur treble adjust karo'
                  : 'Sirf Android devices pe',
              onTap: () => showEqualizerSheet(context),
            ),
            const SizedBox(height: 18),
            const _GroupLabel('About'),
            _Tile(
              icon: Icons.public_rounded,
              title: 'Music sources',
              subtitle: 'Device + Audius + Internet Archive',
              onTap: () => _showSources(context),
            ),
            _Tile(
              icon: Icons.lock_outline_rounded,
              title: 'Permissions',
              subtitle: 'Sirf audio access',
              onTap: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: AppColors.cardSoft,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  title: const Text('Permissions', style: TextStyle(fontSize: 16)),
                  content: const Text(
                    'TuneHive sirf ek permission maangta hai: audio files padhna, taaki device ke gaane dikh sakein.\n\nNotification permission sirf background playback ke liye hai (lock screen controls). Camera, contacts, location — kuch nahi.',
                    style: TextStyle(fontSize: 12.5, height: 1.6),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close', style: TextStyle(color: AppColors.lime)),
                    ),
                  ],
                ),
              ),
            ),
            _Tile(
              icon: Icons.info_outline_rounded,
              title: 'About TuneHive',
              subtitle: 'Version 1.0.0',
              onTap: () => _showAbout(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: 18,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: AppColors.cardSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: AppColors.lime),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.lime)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
