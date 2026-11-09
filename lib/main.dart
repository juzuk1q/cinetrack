import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Guard against unhandled Flutter framework errors that would leave a black screen
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('CineTrack FlutterError: ${details.exceptionAsString()}');
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_filter_rounded,
                  size: 48, color: Color(0xFF7C3AED)),
              const SizedBox(height: 16),
              const Text(
                'CineTrack',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${details.exception}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    await initializeDateFormatting('ru', null);
  } catch (e) {
    debugPrint('DateFormatting warning: $e');
  }

  try {
    await Supabase.initialize(
      url: 'https://xwfixqgmuhzqbfdsiqmt.supabase.co',
      // ignore: deprecated_member_use
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh3Zml4cWdtdWh6cWJmZHNpcW10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyMzQyNjIsImV4cCI6MjEwODgxMDI2Mn0.PJ17S9wHdLdF0kmADTVO2SS59h2aMpoXCe8A-cLmn5c',
    ).timeout(const Duration(seconds: 4));
  } catch (e) {
    debugPrint('Supabase initialization handled: $e');
  }

  runApp(
    const ProviderScope(
      child: CineTrackApp(),
    ),
  );
}
