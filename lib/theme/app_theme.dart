import 'package:flutter/material.dart';

/// Colours taken from the TuneHive design: deep olive background with a
/// single bright lime accent, everything else quiet.
class AppColors {
  static const bg = Color(0xFF0A0E06);
  static const bgTop = Color(0xFF1A2410);
  static const card = Color(0xFF161D0E);
  static const cardSoft = Color(0xFF1E2713);
  static const lime = Color(0xFFB9F04A);
  static const limeSoft = Color(0xFFD8FF8A);
  static const text = Color(0xFFF5F8EF);
  static const muted = Color(0xFF9BA68B);
  static const line = Color(0x1FFFFFFF);
  static const danger = Color(0xFFFF7A7A);
}

class AppTheme {
  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: AppColors.lime,
      onPrimary: Color(0xFF10160A),
      secondary: AppColors.limeSoft,
      surface: AppColors.card,
      onSurface: AppColors.text,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      dividerColor: AppColors.line,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(fontFamily: 'Poppins', bodyColor: AppColors.text, displayColor: AppColors.text)
          .copyWith(
            headlineMedium: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
                height: 1.25),
            titleLarge: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: AppColors.text),
            titleMedium: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text),
            bodyMedium: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13.5,
                color: AppColors.text,
                height: 1.45),
            bodySmall: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12, color: AppColors.muted),
          ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.cardSoft,
        contentTextStyle:
            TextStyle(fontFamily: 'Poppins', color: AppColors.text, fontSize: 13),
        behavior: SnackBarBehavior.floating,
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.lime,
        inactiveTrackColor: Color(0x33FFFFFF),
        thumbColor: AppColors.lime,
        overlayColor: Color(0x22B9F04A),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 16),
      ),
    );
  }
}
