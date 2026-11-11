import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color darkMaroon = Color(0xFF780000);
  static const Color deepRed = Color(0xFF690000);
  static const Color lightGray = Color(0xFFE1E1E1);
  static const Color lightPinkGray = Color(0xFFF0E1E1);
  static const Color offWhite = Color(0xFFD2D2D2);
  static const Color mutedRose = Color(0xFFA56969);

  // The typography of the design (UI.pdf): Poppins, Regular and Bold, in
  // these sizes (the PDF's sizes scaled to the phone: 16 for titles and the
  // calendar, 12.5 for form labels and card titles, 12 for body text, 10 for
  // captions). The serif italic is kept for small explanatory notes only: see
  // [noteStyle].
  static TextTheme _textTheme(ColorScheme colorScheme) {
    final poppins = GoogleFonts.poppins();

    return TextTheme(
      displayLarge: poppins.copyWith(fontSize: 32, fontWeight: FontWeight.bold),
      displayMedium: poppins.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      displaySmall: poppins.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
      headlineLarge: poppins.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: poppins.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: poppins.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: poppins.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
      titleMedium: poppins.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
      titleSmall: poppins.copyWith(fontSize: 12.5, fontWeight: FontWeight.bold),
      bodyLarge: poppins.copyWith(fontSize: 14),
      bodyMedium: poppins.copyWith(fontSize: 12),
      bodySmall: poppins.copyWith(fontSize: 10),
      labelLarge: poppins.copyWith(fontSize: 12.5, fontWeight: FontWeight.bold),
      labelMedium: poppins.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
      labelSmall: poppins.copyWith(fontSize: 9),
    );
  }

  /// The small serif italic note (eg "Some details were unclear from this
  /// photo…"): Noto Serif Italic, 9, grey, as in the design.
  static TextStyle noteStyle([Color color = const Color(0xFFB2B2B2)]) =>
      GoogleFonts.notoSerif(
        fontSize: 9,
        fontStyle: FontStyle.italic,
        color: color,
      );

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
      // The design's page colour (#E7E7E7).
      scaffoldBackgroundColor: const Color(0xFFE7E7E7),
      textTheme: _textTheme(
        colorScheme,
      ).apply(bodyColor: Colors.black87, displayColor: darkMaroon),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: darkMaroon,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkMaroon,
          foregroundColor: Colors.white,
          // Pill-shaped, as in the design.
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkMaroon,
          side: const BorderSide(color: darkMaroon, width: 1.5),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          selectedBackgroundColor: const Color(0xFFCCCCCC),
          selectedForegroundColor: Colors.black,
          side: const BorderSide(color: Colors.black87),
          textStyle: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
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
        hintStyle: GoogleFonts.poppins(
          fontSize: 12.5,
          color: const Color(0xFF8F8584),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
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
        centerTitle: true,
        backgroundColor: deepRed,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
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
          textStyle: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
