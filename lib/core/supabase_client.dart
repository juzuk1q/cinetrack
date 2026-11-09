import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseClient get supabase {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return SupabaseClient(
      'https://xwfixqgmuhzqbfdsiqmt.supabase.co',
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh3Zml4cWdtdWh6cWJmZHNpcW10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyMzQyNjIsImV4cCI6MjEwODgxMDI2Mn0.PJ17S9wHdLdF0kmADTVO2SS59h2aMpoXCe8A-cLmn5c',
    );
  }
}

