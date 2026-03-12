import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ═══════════════════════════════════════════════════════════
// PRINCESS TRACKERS — FUTURISTIC DESIGN SYSTEM
// ═══════════════════════════════════════════════════════════

class C {
  C._();
  static const bg = Color(0xFF03040a);
  static const surface = Color(0xFF0a0e1f);
  static const surfaceLight = Color(0xFF111633);
  static const card = Color(0x0AFFFFFF);
  static const cardBorder = Color(0x14FFFFFF);
  static const cyan = Color(0xFF00d4ff);
  static const purple = Color(0xFF7c6cfc);
  static const green = Color(0xFF00e87a);
  static const pink = Color(0xFFff4c6a);
  static const gold = Color(0xFFffd700);
  static const text = Color(0xFFeef2ff);
  static const textSub = Color(0x99eef2ff);
  static const textDim = Color(0x4Deef2ff);
}

class AppTheme {
  AppTheme._();

  static TextStyle font({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = C.text,
    double spacing = 0,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
      );

  static TextStyle displayFont({
    double size = 24,
    FontWeight weight = FontWeight.w700,
    Color color = C.text,
  }) =>
      GoogleFonts.orbitron(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: C.bg,
        colorScheme: const ColorScheme.dark(
          primary: C.cyan,
          secondary: C.green,
          surface: C.surface,
          error: C.pink,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        useMaterial3: true,
      );

  static const backgroundGradient = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF03040a), Color(0xFF0a0e1f), Color(0xFF050820)],
      stops: [0.0, 0.5, 1.0],
    ),
  );

  static List<BoxShadow> neonGlow(Color color, {double blur = 20, double opacity = 0.3}) => [
        BoxShadow(color: color.withValues(alpha: opacity), blurRadius: blur, spreadRadius: -4),
      ];

  static List<BoxShadow> neonGlowStrong(Color color) => [
        BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: -2),
        BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 60, spreadRadius: -5),
      ];

  static BoxDecoration glassDecoration({
    double radius = 16,
    Color? borderColor,
    double borderOpacity = 0.08,
  }) =>
      BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: borderOpacity),
        ),
      );
}
