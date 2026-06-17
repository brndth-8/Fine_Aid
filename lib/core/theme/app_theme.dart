import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color darkMaroon = Color(0xFF780000);
  static const Color deepRed = Color(0xFF690000);
  static const Color lightGray = Color(0xFFE1E1E1);
  static const Color lightPinkGray = Color(0xFFF0E1E1);
  static const Color offWhite = Color(0xFFD2D2D2);
  static const Color mutedRose = Color(0xFFA56969);

  static TextTheme _textTheme(ColorScheme colorScheme) {
    final body = GoogleFonts.inter();
    final display = GoogleFonts.fredoka();
    final accent = GoogleFonts.notoSerif();

    return TextTheme(
      displayLarge: display.copyWith(fontSize: 32, fontWeight: FontWeight.w400),
      displayMedium: display.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w400,
      ),
      displaySmall: display.copyWith(fontSize: 24, fontWeight: FontWeight.w400),
      headlineLarge: display.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w400,
      ),
      headlineMedium: display.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w400,
      ),
      headlineSmall: display.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w400,
      ),
      titleLarge: body.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
      titleMedium: body.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
      titleSmall: body.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
      bodyLarge: body.copyWith(fontSize: 16),
      bodyMedium: body.copyWith(fontSize: 14),
      bodySmall: accent.copyWith(fontSize: 12),
      labelLarge: body.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
      labelMedium: body.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
      labelSmall: body.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
    );
  }

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: darkMaroon,
      brightness: Brightness.light,
      primary: darkMaroon,
      secondary: deepRed,
      surface: Colors.white,
      surfaceContainerHighest: lightGray,
      surfaceContainerHigh: lightPinkGray,
      surfaceContainer: offWhite,
      tertiary: mutedRose,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightGray,
      textTheme: _textTheme(
        colorScheme,
      ).apply(bodyColor: Colors.black87, displayColor: darkMaroon),
      appBarTheme: AppBarTheme(
        backgroundColor: darkMaroon,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.fredoka(fontSize: 20, color: Colors.white),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkMaroon,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
      cardTheme: CardThemeData(
        color: lightPinkGray,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: darkMaroon,
      brightness: Brightness.dark,
      primary: mutedRose,
      secondary: deepRed,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: _textTheme(
        colorScheme,
      ).apply(bodyColor: Colors.white, displayColor: mutedRose),
      appBarTheme: AppBarTheme(
        backgroundColor: deepRed,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.fredoka(fontSize: 20, color: Colors.white),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: mutedRose,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
