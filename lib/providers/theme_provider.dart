// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kThemeStorageKey = 'cinetrack_theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(_initialTheme());

  static ThemeMode _initialTheme() {
    if (kIsWeb) {
      try {
        final saved = html.window.localStorage[_kThemeStorageKey];
        if (saved == 'light') return ThemeMode.light;
        if (saved == 'dark') return ThemeMode.dark;
      } catch (e) {
        debugPrint('Error reading saved theme: $e');
      }
    }
    return ThemeMode.dark;
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setTheme(ThemeMode.light);
    } else {
      setTheme(ThemeMode.dark);
    }
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    if (kIsWeb) {
      try {
        html.window.localStorage[_kThemeStorageKey] =
            mode == ThemeMode.light ? 'light' : 'dark';
      } catch (e) {
        debugPrint('Error saving theme: $e');
      }
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
