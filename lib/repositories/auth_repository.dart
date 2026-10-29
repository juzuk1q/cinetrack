import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';

class AuthRepository {
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    return await supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName ?? email.split('@').first},
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  User? get currentUser => supabase.auth.currentUser;

  Session? get currentSession => supabase.auth.currentSession;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
}
