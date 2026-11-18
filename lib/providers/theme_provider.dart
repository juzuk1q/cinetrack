import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemeStorageKey = 'cinetrack_theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kThemeStorageKey);
      if (saved == 'light') {
        state = ThemeMode.light;
      } else if (saved == 'dark') {
        state = ThemeMode.dark;
      }
    } catch (e) {
      debugPrint('Error reading saved theme: $e');
    }
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setTheme(ThemeMode.light);
    } else {
      setTheme(ThemeMode.dark);
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kThemeStorageKey,
        mode == ThemeMode.light ? 'light' : 'dark',
      );
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
