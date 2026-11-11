import 'package:supabase_flutter/supabase_flutter.dart';

import 'env.dart';

SupabaseClient get supabase {
  try {
    return Supabase.instance.client;
  } catch (e) {
    return SupabaseClient(
      Env.supabaseUrl,
      Env.supabaseAnonKey,
    );
  }
}
