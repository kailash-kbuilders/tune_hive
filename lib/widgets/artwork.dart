import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/device_music_service.dart';
import '../theme/app_theme.dart';

/// Album art for a song: the embedded artwork of the file, or a quiet
/// gradient placeholder when the file has none.
class SongArtwork extends StatelessWidget {
  const SongArtwork({
    super.key,
    required this.song,
    this.size = 56,
    this.radius = 14,
  });

  final Song song;
  final double size;
  final double radius;

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF33441C), Color(0xFF141B0D)],
        ),
      ),
      child: Icon(
        Icons.graphic_eq_rounded,
        size: size * 0.38,
        color: AppColors.lime.withOpacity(0.75),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deviceId = song.deviceId;
    final child = deviceId == null
        ? _fallback()
        : FutureBuilder<Uint8List?>(
            future: ArtworkCache.load(deviceId),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              if (bytes == null || bytes.isEmpty) return _fallback();
              return Image.memory(
                bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              );
            },
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}
