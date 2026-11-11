class Env {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xwfixqgmuhzqbfdsiqmt.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh3Zml4cWdtdWh6cWJmZHNpcW10Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyMzQyNjIsImV4cCI6MjEwODgxMDI2Mn0.PJ17S9wHdLdF0kmADTVO2SS59h2aMpoXCe8A-cLmn5c',
  );
}
