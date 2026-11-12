import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../platform/platform.dart';

class EmailConfirmationRequiredException implements Exception {
  final String email;
  EmailConfirmationRequiredException(this.email);
  @override
  String toString() => 'Ссылка для активации отправлена на $email';
}

class AuthRepository {
  AuthRepository();

  Future<User> signIn({
    required String username,
    required String password,
  }) async {
    final rawInput = username.trim();
    if (rawInput.isEmpty) {
      throw 'Введите имя пользователя или email';
    }
    if (password.isEmpty) {
      throw 'Введите пароль';
    }

    final isEmail = rawInput.contains('@');
    String targetEmail;

    if (isEmail) {
      targetEmail = rawInput.toLowerCase();
    } else {
      // Resolve username to email via secure RPC find_user_email_by_login
      try {
        final res = await supabase.rpc('find_user_email_by_login', params: {
          'user_login': rawInput,
        });
        if (res == null || (res as String).trim().isEmpty) {
          throw 'Пользователь с логином "$rawInput" не найден';
        }
        targetEmail = res.trim().toLowerCase();
      } catch (e) {
        if (e is String) rethrow;
        throw 'Пользователь с логином "$rawInput" не найден';
      }
    }

    // Supabase Auth SignIn
    AuthResponse authRes;
    try {
      authRes = await supabase.auth.signInWithPassword(
        email: targetEmail,
        password: password,
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials')) {
        throw 'Неверный логин, почта или пароль.';
      } else if (msg.contains('email not confirmed')) {
        throw 'Почта ещё не подтверждена! Пожалуйста, перейдите по ссылке активации из письма (проверьте папку «Спам»).';
      } else {
        throw e.message;
      }
    } catch (e) {
      throw 'Ошибка авторизации: $e';
    }

    final user = authRes.user;
    if (user == null) {
      throw 'Не удалось войти в аккаунт';
    }

    // Check account restriction (ban / freeze)
    await _checkAccountRestrictions(user.id);

    return user;
  }

  Future<void> _checkAccountRestrictions(String userId) async {
    try {
      final res = await supabase
          .from('profiles')
          .select('is_blocked, is_frozen, block_reason, block_until')
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        final isBlocked = res['is_blocked'] as bool? ?? false;
        final isFrozen = res['is_frozen'] as bool? ?? false;
        final reason = res['block_reason'] as String?;
        final untilStr = res['block_until'] as String?;
        DateTime? until = untilStr != null ? DateTime.tryParse(untilStr) : null;

        final isCurrentlyFrozen =
            isFrozen && (until == null || DateTime.now().isBefore(until));

        if (isBlocked || isCurrentlyFrozen) {
          await supabase.auth.signOut();
          if (isBlocked) {
            throw 'Ваш аккаунт заблокирован администрацией.${reason != null && reason.isNotEmpty ? " Причина: $reason" : ""}';
          } else {
            throw 'Ваш аккаунт временно заморожен.${reason != null && reason.isNotEmpty ? " Причина: $reason" : ""}';
          }
        }
      }
    } catch (e) {
      if (e is String) rethrow;
      debugPrint('Account restriction check note: $e');
    }
  }

  Future<User> signUp({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cleanUsername = username.trim().toLowerCase().replaceAll('@', '');
    final cleanEmail = email.trim().toLowerCase();

    if (cleanUsername.isEmpty) {
      throw 'Введите имя пользователя';
    }
    if (cleanUsername.length < 3) {
      throw 'Имя пользователя должно содержать не менее 3 символов';
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw 'Введите корректный адрес электронной почты';
    }
    if (password.length < 6) {
      throw 'Пароль должен содержать не менее 6 символов';
    }

    final finalDisplayName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : username.trim();

    AuthResponse res;
    try {
      res = await supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'display_name': finalDisplayName,
          'username': cleanUsername,
          'has_password': true,
        },
      );
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') ||
          msg.contains('user already exists')) {
        throw 'Пользователь с такой почтой уже зарегистрирован';
      } else if (msg.contains('password')) {
        throw 'Пароль слишком простой: используйте не менее 6 символов, буквы и цифры';
      } else {
        throw e.message;
      }
    } catch (e) {
      throw 'Ошибка регистрации: $e';
    }

    if (res.user == null) {
      throw 'Не удалось создать аккаунт';
    }

    if (res.session == null) {
      throw EmailConfirmationRequiredException(cleanEmail);
    }

    return res.user!;
  }

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    await supabase.auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? PlatformHelper.getOrigin() : null,
      scopes: provider == OAuthProvider.google ? 'email profile' : null,
    );
  }

  Future<void> resetPasswordForEmail(String email) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty || !clean.contains('@')) {
      throw 'Введите корректный email для сброса пароля';
    }
    await supabase.auth.resetPasswordForEmail(
      clean,
      redirectTo: kIsWeb ? PlatformHelper.getOrigin() : null,
    );
  }

  Future<void> updatePassword(String newPassword) async {
    if (newPassword.length < 6) {
      throw 'Пароль должен содержать не менее 6 символов';
    }
    await supabase.auth.updateUser(
      UserAttributes(
        password: newPassword,
        data: {'has_password': true},
      ),
    );
  }

  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cinetrack_active_user');
      await prefs.remove('cinetrack_custom_profile');
      await prefs.remove('cinetrack_my_role');
      await prefs.remove('cinetrack_has_password');
      final keys = prefs.getKeys();
      for (final k in keys) {
        if (k.startsWith('cinetrack_pwd_') ||
            k.startsWith('cinetrack_my_role_') ||
            k.startsWith('cinetrack_custom_profile_')) {
          await prefs.remove(k);
        }
      }
    } catch (e) {
      debugPrint('Error purging SharedPreferences on signOut: $e');
    }
    await supabase.auth.signOut();
  }

  User? get currentUser => supabase.auth.currentUser;

  Session? get currentSession => supabase.auth.currentSession;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
}
