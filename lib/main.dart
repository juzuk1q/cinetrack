import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ru', null);

  await Supabase.initialize(
    url: 'https://xwfixqgmuhzqbfdsiqmt.supabase.co',
    // ignore: deprecated_member_use
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh3Zml4cWdtdWh6cWJmZHNpcW10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyMzQyNjIsImV4cCI6MjEwODgxMDI2Mn0.PJ17S9wHdLdF0kmADTVO2SS59h2aMpoXCe8A-cLmn5c',
  );

  runApp(
    const ProviderScope(
      child: CineTrackApp(),
    ),
  );
}
