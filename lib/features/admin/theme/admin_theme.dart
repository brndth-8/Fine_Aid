import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Theme for the admin web portal (main_admin.dart), kept separate from the
/// mobile app's [AppTheme]. The mobile theme mixes Fredoka (headings) and
/// Noto Serif (bodySmall) with Inter (everything else) — fine for the
/// consumer app's branding, but it means admin card labels render in a
/// serif font next to sans-serif headings. This theme standardizes the
/// whole portal on Inter with one explicit type scale, so every widget
/// that just reads `Theme.of(context).textTheme.*` gets a consistent font.
class AdminTheme {
  AdminTheme._();

  static const Color maroon = Color(0xFF690000);
  static const Color maroonDark = Color(0xFF330000);
  static const Color accentBright = Color(0xFFE5484D);

  static TextTheme get _textTheme {
    return TextTheme(
      // Page title, e.g. "Dashboard".
      titleLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.3,
        letterSpacing: -0.3,
        color: Colors.black87,
      ),
      // Section headings, e.g. "Recent activity feed", "System status".
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: Colors.black87,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: Colors.black87,
      ),
      // Card values, e.g. the big "7" / "13" numbers.
      headlineLarge: GoogleFonts.inter(
        fontSize: 26,
        fontWeight: FontWeight.bold,
        height: 1.2,
        color: Colors.black87,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.2,
        color: Colors.black87,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.2,
        color: Colors.black87,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        height: 1.5,
        color: Colors.black87,
      ),
      // Sidebar nav item text.
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        height: 1.4,
        color: Colors.black87,
      ),
      // General compact body text (table cells, list rows). Widgets that
      // want the muted "card label" look (e.g. AdminStatCard's label)
      // apply `.copyWith(color: Colors.grey)` on top of this themselves —
      // this base stays readable since bodySmall is also the default for
      // ordinary row/cell content across every admin table.
      bodySmall: GoogleFonts.inter(
        fontSize: 13,
        height: 1.5,
        color: Colors.black87,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: Colors.black87,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: Colors.black87,
      ),
      // Sidebar section labels, e.g. "OVERVIEW".
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0.8,
        color: Colors.grey,
      ),
    );
  }

  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: maroon,
      brightness: Brightness.light,
      primary: maroon,
      secondary: maroon,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF8F8F8),
      textTheme: _textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: maroon,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: maroon,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
      ),
    );
  }
}
