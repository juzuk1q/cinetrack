import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Color palette
  static const Color _primary = Color(0xFF7C3AED);       // violet-600
  static const Color _primaryLight = Color(0xFF9F67FF);  // lighter violet
  static const Color _secondary = Color(0xFFE040FB);     // purple accent
  static const Color _background = Color(0xFF0F0F1A);    // near-black
  static const Color _surface = Color(0xFF1A1A2E);       // card bg
  static const Color _surfaceVariant = Color(0xFF252540); // elevated card
  static const Color _onSurface = Color(0xFFE2E2F0);
  static const Color _onBackground = Color(0xFFF0F0FF);
  static const Color _error = Color(0xFFCF6679);
  static const Color _success = Color(0xFF4CAF50);
  static const Color _warning = Color(0xFFFFB74D);

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: _primary,
      primaryContainer: Color(0xFF3D1A78),
      secondary: _secondary,
      secondaryContainer: Color(0xFF6A1A7A),
      surface: _surface,
      error: _error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: _onSurface,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: _background,
    cardColor: _surface,
    dividerColor: Colors.white12,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: _surface,
      foregroundColor: _onBackground,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: _onBackground,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      iconTheme: IconThemeData(color: _onBackground),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 4,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white10, width: 0.8),
      ),
    ),

    // ElevatedButton
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 3,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primaryLight,
        side: const BorderSide(color: _primary, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),

    // TextButton
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primaryLight,
      ),
    ),

    // InputDecoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _error, width: 2),
      ),
      labelStyle: const TextStyle(color: Colors.white60),
      hintStyle: const TextStyle(color: Colors.white30),
      prefixIconColor: Colors.white54,
      suffixIconColor: Colors.white54,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: _surfaceVariant,
      selectedColor: _primary.withValues(alpha: 0.35),
      labelStyle: const TextStyle(color: _onSurface, fontSize: 13),
      side: const BorderSide(color: Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    ),

    // FloatingActionButton
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: CircleBorder(),
    ),

    // NavigationRail
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: _surface,
      selectedIconTheme: const IconThemeData(color: _primaryLight),
      unselectedIconTheme: const IconThemeData(color: Colors.white38),
      selectedLabelTextStyle: const TextStyle(
        color: _primaryLight,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: Colors.white38,
        fontSize: 13,
      ),
      indicatorColor: _primary.withValues(alpha: 0.25),
      elevation: 0,
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _surfaceVariant,
      contentTextStyle: const TextStyle(color: _onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: Colors.white12,
      thickness: 1,
      space: 1,
    ),

    // Text
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: _onBackground, fontWeight: FontWeight.w800),
      displayMedium: TextStyle(color: _onBackground, fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(color: _onBackground, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: _onBackground, fontWeight: FontWeight.w600),
      headlineSmall: TextStyle(color: _onBackground, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: _onBackground, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: _onSurface, fontWeight: FontWeight.w500),
      titleSmall: TextStyle(color: _onSurface),
      bodyLarge: TextStyle(color: _onSurface),
      bodyMedium: TextStyle(color: _onSurface),
      bodySmall: TextStyle(color: Colors.white60),
      labelLarge: TextStyle(color: _onSurface, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: Colors.white60),
      labelSmall: TextStyle(color: Colors.white38, fontSize: 11),
    ),
  );

  // Semantic colors for status
  static Color statusColor(String status) {
    switch (status) {
      case 'watching':
        return _warning;
      case 'watched':
        return _success;
      case 'want_to_watch':
      default:
        return _primaryLight;
    }
  }

  // Type badge colors
  static Color typeColor(String type) {
    switch (type) {
      case 'series':
        return const Color(0xFF29B6F6);
      case 'cartoon':
        return const Color(0xFFFFCA28);
      case 'movie':
      default:
        return _secondary;
    }
  }
}
