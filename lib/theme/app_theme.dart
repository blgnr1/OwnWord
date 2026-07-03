import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Clean Minimalist Palette
  static const Color bubblegumPink = Color(0xFFFF4081); // Preserved accent
  static const Color skyBlue       = Color(0xFF00E5FF);
  
  // Functional Colors (Restored to fix existing references)
  static const Color grassGreen    = Color(0xFF00C853);
  static const Color sunnyYellow   = Color(0xFFFFD600);
  static const Color sunsetOrange  = Color(0xFFFF5722);
  static const Color electricBlue  = Color(0xFF2979FF);
  static const Color mintGreen     = Color(0xFF00BFA5);

  static const Color softBackground = Color(0xFFF8F9FA); // Ultra-clean premium light gray
  static const Color whiteSurface   = Color(0xFFFFFFFF);
  static const Color textMain       = Color(0xFF1A1A1E); // Sleeker dark text
  static const Color textMuted      = Color(0xFF7A7A85); // Modern muted text

  static List<BoxShadow> get premiumShadow => [
    BoxShadow(
      color: const Color(0xFF1A1A1E).withAlpha(12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF1A1A1E).withAlpha(4),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withAlpha(8),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: softBackground,
      primaryColor: bubblegumPink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: bubblegumPink,
        brightness: Brightness.light,
        surface: whiteSurface,
        primary: bubblegumPink,
        secondary: skyBlue,
      ),
      textTheme: GoogleFonts.nunitoTextTheme().copyWith(
        displayLarge: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: textMain),
        titleLarge: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: textMain),
        bodyLarge: GoogleFonts.nunito(color: textMain, fontSize: 16, fontWeight: FontWeight.w600),
        bodyMedium: GoogleFonts.nunito(color: textMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textMain,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          systemNavigationBarColor: Color(0xFFF8F9FA),
          systemNavigationBarIconBrightness: Brightness.dark,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bubblegumPink,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: bubblegumPink.withAlpha(80),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        ),
      ),
      cardTheme: CardThemeData(
        color: whiteSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: Color(0xFFEFEFEF), width: 1.0),
        ),
      ),
    );
  }
}
