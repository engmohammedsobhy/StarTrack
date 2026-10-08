import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseTheme = ThemeData.light();
    return baseTheme.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6200EE),
        brightness: Brightness.light,
        primary: const Color(0xFF6200EE),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme).copyWith(
        bodyMedium: GoogleFonts.plusJakartaSans(color: Colors.black87),
        bodyLarge: GoogleFonts.plusJakartaSans(color: Colors.black87),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark();
    return baseTheme.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFE53935),
        surface: Color(0xFF181818),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: const Color(0xFF0F0F0F),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF181818),
        indicatorColor: Colors.white.withValues(alpha: 0.1),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white);
          }
          return const IconThemeData(color: Colors.grey);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            );
          }
          return GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF181818),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
