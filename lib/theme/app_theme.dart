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

  static const Color softBackground = Color(0xFFF2F2F7); // Minimalist Light Gray
  static const Color whiteSurface   = Color(0xFFFFFFFF);
  static const Color textMain       = Color(0xFF1C1C1E); // iOS-style dark text
  static const Color textMuted      = Color(0xFF8E8E93); // iOS-style muted text

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
        titleLarge: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: textMain),
        bodyLarge: GoogleFonts.nunito(color: textMain, fontSize: 16),
        bodyMedium: GoogleFonts.nunito(color: textMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: textMain,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          systemNavigationBarColor: Color(0xFF000000),
          systemNavigationBarIconBrightness: Brightness.light,
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          // No hardcoded fontFamily — inherits from textTheme
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bubblegumPink,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      cardTheme: CardThemeData(
        color: whiteSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.black12, width: 0.5),
        ),
      ),
    );
  }
}
