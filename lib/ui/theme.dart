import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// PhoneProof visual language: dark, high-contrast, premium "lab instrument".
/// A single calm accent for the UI; green / amber / red are reserved strictly
/// for verdicts and always paired with an icon + label.
class AppColors {
  // Canvas & surfaces
  static const Color canvas = Color(0xFF07090D);
  static const Color surface = Color(0xFF0E1218);
  static const Color surfaceHigh = Color(0xFF151B24);
  static const Color hairline = Color(0x22FFFFFF);

  // Calm UI accent (cyan/teal — instrument readout)
  static const Color accent = Color(0xFF36E2C8);
  static const Color accentDim = Color(0xFF1C8C7E);

  // Verdict palette (colour-blind safe; always with icon + label)
  static const Color good = Color(0xFF3FD07A);
  static const Color caution = Color(0xFFF6C152);
  static const Color risk = Color(0xFFFF6B6B);
  static const Color unknown = Color(0xFF8A93A3);

  // Text
  static const Color text = Color(0xFFF2F5F8);
  static const Color textDim = Color(0xFF9AA4B2);
}

class AppTheme {
  static ThemeData dark() => _build(Brightness.dark);
  static ThemeData light() => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
    ).copyWith(
      surface: isDark ? AppColors.canvas : const Color(0xFFF4F6F9),
      primary: AppColors.accent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.canvas : const Color(0xFFF4F6F9),
      splashFactory: InkRipple.splashFactory,
    );

    final display = GoogleFonts.spaceGrotesk(
      color: isDark ? AppColors.text : const Color(0xFF0B1016),
    );
    final body = GoogleFonts.inter(
      color: isDark ? AppColors.text : const Color(0xFF0B1016),
    );

    return base.copyWith(
      textTheme: base.textTheme
          .copyWith(
            displayLarge: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.w300,
              letterSpacing: -2,
            ),
            headlineMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
            titleLarge: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w600),
            titleMedium: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w500),
            bodyLarge: body,
            bodyMedium: body,
            labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
          )
          .apply(
            bodyColor: display.color,
            displayColor: display.color,
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w600,
          fontSize: 20,
          color: display.color,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: AppColors.hairline),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}

/// Background gradient used behind the whole app for depth.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDark
            ? const RadialGradient(
                center: Alignment(0, -0.7),
                radius: 1.4,
                colors: [Color(0xFF11202A), AppColors.canvas],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF0F6), Color(0xFFF4F6F9)],
              ),
      ),
      child: child,
    );
  }
}
