import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static String? get fontFamily => GoogleFonts.cabinCondensed().fontFamily;

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.cabinCondensedTextTheme();

    return ThemeData(
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6200EE),
        brightness: Brightness.light,
        primary: const Color(0xFF6200EE),
      ),
      useMaterial3: true,
      textTheme: baseTextTheme.apply(
        fontFamily: fontFamily,
        bodyColor: Colors.black87,
        displayColor: Colors.black87,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.cabinCondensed(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseDarkTextTheme = GoogleFonts.cabinCondensedTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      fontFamily: fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF9B51E0),
        brightness: Brightness.dark,
        primary: Colors.white,
        secondary: Colors.grey,
        surface: const Color(0xFF121212),
      ),
      useMaterial3: true,
      textTheme: baseDarkTextTheme.apply(
        fontFamily: fontFamily,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: const Color(0xFF121212),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.cabinCondensed(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF121212),
        indicatorColor: Colors.white.withValues(alpha: 0.1),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white);
          }
          return const IconThemeData(color: Colors.grey);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.cabinCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            );
          }
          return GoogleFonts.cabinCondensed(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
