// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';

class EmailConfirmationRequiredException implements Exception {
  final String email;
  EmailConfirmationRequiredException(this.email);
  @override
  String toString() => 'Ссылка для активации отправлена на $email';
}

class AuthRepository {
  AuthRepository() {
    _initLocalSession();
  }

  static const String _kActiveUserKey = 'cinetrack_active_user';
  static const String _kSavedUsersKey = 'cinetrack_saved_users';

  final _authStreamController = StreamController<AuthState>.broadcast();
  User? _localCurrentUser;

  void _initLocalSession() {
    if (!kIsWeb) return;
    try {
      final raw = html.window.localStorage[_kActiveUserKey];
      if (raw != null && raw.isNotEmpty) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _localCurrentUser = _createUserFromJson(data);
      }
    } catch (e) {
      debugPrint('Error restoring local auth session: $e');
    }
  }

  User _createUserFromJson(Map<String, dynamic> data) {
    final username = data['username'] as String? ?? 'user';
    final role = data['role'] as String? ?? 'user';
    final displayName = data['display_name'] as String? ?? username;
    final email = data['email'] as String? ?? '$username@cinetrack.local';

    return User(
      id: data['id'] as String? ?? 'u_${username.toLowerCase()}',
      appMetadata: const {'provider': 'cinetrack'},
      userMetadata: {
        'display_name': displayName,
        'role': role,
        'username': username,
      },
      aud: 'authenticated',
      createdAt: data['created_at'] as String? ?? DateTime.now().toIso8601String(),
      email: email,
    );
  }

  void _persistSession(User user, String username, String role) {
    _localCurrentUser = user;
    if (kIsWeb) {
      try {
        final map = {
          'id': user.id,
          'username': username,
          'display_name': user.userMetadata?['display_name'] ?? username,
          'role': role,
          'email': user.email,
          'created_at': user.createdAt,
        };
        html.window.localStorage[_kActiveUserKey] = jsonEncode(map);
      } catch (e) {
        debugPrint('Error persisting local auth session: $e');
      }
    }
  }

  Future<User> signIn({
    required String username,
    required String password,
  }) async {
    final cleanInput = username.trim().replaceAll('@', '').toLowerCase();
    if (cleanInput.isEmpty) {
      throw 'Введите имя пользователя или email';
    }
    if (password.isEmpty) {
      throw 'Введите пароль';
    }

    String targetEmail = cleanInput;
    String targetUsername = cleanInput;
    String? displayName;
    String role = 'user';
    String? targetUserId;

    // 1. Resolve username to email if input is not already an email
    if (!cleanInput.contains('@')) {
      // A) Query Supabase profiles table for matching username or display_name
      try {
        final prof = await supabase
            .from('profiles')
            .select()
            .or('username.ilike.$cleanInput,display_name.ilike.$cleanInput')
            .maybeSingle();
        if (prof != null) {
          targetEmail = (prof['email'] as String? ?? '').toLowerCase();
          targetUsername = (prof['username'] as String? ?? cleanInput).toLowerCase();
          displayName = prof['display_name'] as String?;
          role = prof['role'] as String? ?? 'user';
          targetUserId = prof['id'] as String?;
        }
      } catch (e) {
        debugPrint('Supabase profile lookup note: $e');
      }

      // B) Query localStorage admin users if email is still unresolved
      if (!targetEmail.contains('@') && kIsWeb) {
        try {
          final raw = html.window.localStorage['cinetrack_admin_users'];
          if (raw != null && raw.isNotEmpty) {
            final list = jsonDecode(raw) as List<dynamic>;
            for (final u in list) {
              final uName = (u['username'] ?? '').toString().toLowerCase();
              final uDisplay = (u['display_name'] ?? '').toString().toLowerCase();
              if (uName == cleanInput || uDisplay == cleanInput) {
                targetEmail = (u['email'] ?? '').toString().toLowerCase();
                targetUsername = uName;
                displayName = u['display_name'] as String?;
                role = u['role'] as String? ?? 'user';
                targetUserId = u['id'] as String?;
                break;
              }
            }
          }
        } catch (_) {}
      }

      // C) Query localStorage custom profile
      if (!targetEmail.contains('@') && kIsWeb) {
        try {
          final raw = html.window.localStorage['cinetrack_custom_profile'];
          if (raw != null && raw.isNotEmpty) {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            final uName = (map['username'] ?? '').toString().toLowerCase();
            final uDisplay = (map['display_name'] ?? '').toString().toLowerCase();
            if (uName == cleanInput || uDisplay == cleanInput) {
              targetEmail = (map['email'] ?? '').toString().toLowerCase();
              targetUsername = uName;
              displayName = map['display_name'] as String?;
              role = map['role'] as String? ?? 'user';
              targetUserId = map['id'] as String?;
            }
          }
        } catch (_) {}
      }
    } else {
      // Input is an email. Try to fetch associated username and role
      targetEmail = cleanInput;
      try {
        final prof = await supabase
            .from('profiles')
            .select()
            .eq('email', targetEmail)
            .maybeSingle();
        if (prof != null) {
          targetUsername = (prof['username'] as String? ?? targetEmail.split('@').first).toLowerCase();
          displayName = prof['display_name'] as String?;
          role = prof['role'] as String? ?? 'user';
          targetUserId = prof['id'] as String?;
        }
      } catch (_) {}

      if (kIsWeb) {
        try {
          final raw = html.window.localStorage['cinetrack_admin_users'];
          if (raw != null && raw.isNotEmpty) {
            final list = jsonDecode(raw) as List<dynamic>;
            for (final u in list) {
              final uEmail = (u['email'] ?? '').toString().toLowerCase();
              if (uEmail == targetEmail) {
                targetUsername = (u['username'] ?? targetUsername).toString().toLowerCase();
                displayName ??= u['display_name'] as String?;
                role = u['role'] as String? ?? role;
                targetUserId ??= u['id'] as String?;
                break;
              }
            }
          }
        } catch (_) {}
      }
    }

    final emailFormat = targetEmail.contains('@') ? targetEmail : '$targetEmail@cinetrack.local';

    // 2. Try standard Supabase cloud authentication
    User? authenticatedUser;
    try {
      final authRes = await supabase.auth.signInWithPassword(
        email: emailFormat,
        password: password,
      );
      if (authRes.user != null) {
        authenticatedUser = authRes.user;
        final prof = await supabase
            .from('profiles')
            .select('role, display_name')
            .eq('id', authRes.user!.id)
            .maybeSingle();
        if (prof != null) {
          role = prof['role'] as String? ?? role;
          displayName = prof['display_name'] as String? ?? displayName;
        }
      }
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('email not confirmed')) {
        throw 'Почта ещё не подтверждена! Пожалуйста, перейдите по ссылке активации из письма.';
      }
      debugPrint('Supabase cloud signIn attempt note: $e');
    }

    // 3. Database Password Verification (via secure PostgreSQL bcrypt RPC)
    if (authenticatedUser == null) {
      try {
        final res = await supabase.rpc('verify_user_password', params: {
          'login_or_email': cleanInput,
          'input_password': password,
        });
        if (res != null && res is List && res.isNotEmpty) {
          final row = res.first as Map<String, dynamic>;
          final uid = row['user_id'] as String;
          final uEmail = (row['user_email'] as String? ?? targetEmail).trim();
          final uUsername = (row['user_username'] as String? ?? targetUsername).trim();
          final uDisplayName = row['user_display_name'] as String? ?? displayName ?? uUsername;
          final uRole = row['user_role'] as String? ?? role;
          final isBlocked = row['user_is_blocked'] as bool? ?? false;
          final isFrozen = row['user_is_frozen'] as bool? ?? false;

          if (isBlocked) {
            throw 'Ваш аккаунт заблокирован администрацией.';
          }

          final user = User(
            id: uid,
            appMetadata: const {'provider': 'cinetrack'},
            userMetadata: {
              'display_name': uDisplayName,
              'role': uRole,
              'username': uUsername,
              'has_password': true,
              'is_frozen': isFrozen,
            },
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
            email: uEmail.contains('@') ? uEmail : '$uUsername@cinetrack.local',
          );

          _persistSession(user, uUsername, uRole);
          _authStreamController.add(const AuthState(AuthChangeEvent.signedIn, null));
          return user;
        }
      } catch (e) {
        if (e is String) rethrow;
        debugPrint('verify_user_password RPC note: $e');
      }
    }

    // 4. Fallback: Check local stored password credentials (specifically for accounts linked or created with password)
    if (authenticatedUser == null && kIsWeb) {
      final savedPwdByEmail = targetEmail.contains('@')
          ? html.window.localStorage['cinetrack_pwd_${targetEmail.toLowerCase()}']
          : null;
      final savedPwdByUsername =
          html.window.localStorage['cinetrack_pwd_${targetUsername.toLowerCase()}'];
      final savedPwdByInput =
          html.window.localStorage['cinetrack_pwd_$cleanInput'];

      if ((savedPwdByEmail != null && savedPwdByEmail == password) ||
          (savedPwdByUsername != null && savedPwdByUsername == password) ||
          (savedPwdByInput != null && savedPwdByInput == password)) {
        final user = User(
          id: targetUserId ?? 'u_${targetUsername.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}',
          appMetadata: const {'provider': 'cinetrack'},
          userMetadata: {
            'display_name': displayName ?? targetUsername,
            'role': role,
            'username': targetUsername,
            'has_password': true,
          },
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          email: targetEmail.contains('@') ? targetEmail : '$targetUsername@cinetrack.local',
        );

        _persistSession(user, targetUsername, role);
        _authStreamController.add(const AuthState(AuthChangeEvent.signedIn, null));
        return user;
      }
    }

    if (authenticatedUser != null) {
      _persistSession(authenticatedUser, targetUsername, role);
      _authStreamController.add(const AuthState(AuthChangeEvent.signedIn, null));
      return authenticatedUser;
    }

    throw 'Неверный логин, почта или пароль.';
  }

  Future<User> signUp({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim();
    if (cleanUsername.isEmpty) {
      throw 'Введите имя пользователя';
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw 'Введите корректный адрес электронной почты';
    }
    if (cleanUsername.length < 3) {
      throw 'Имя пользователя должно быть не менее 3 символов';
    }

    const role = 'user';
    final finalDisplayName = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : username.trim();

    // Supabase cloud signup
    try {
      final res = await supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {'display_name': finalDisplayName, 'username': cleanUsername},
      );
      if (res.user != null) {
        try {
          await supabase.rpc('set_user_password', params: {
            'target_user_id': res.user!.id,
            'new_password': password,
          });
        } catch (_) {}
      }
      if (res.session == null && res.user != null) {
        // Email confirmation is required by Supabase!
        throw EmailConfirmationRequiredException(cleanEmail);
      }
    } catch (e) {
      if (e is EmailConfirmationRequiredException) rethrow;
      final err = e.toString().toLowerCase();
      if (err.contains('already registered') || err.contains('user already exists')) {
        throw 'Пользователь с такой почтой уже зарегистрирован';
      } else if (err.contains('weak') || err.contains('password should contain')) {
        throw 'Пароль не соответствует требованиям: от 8 символов, заглавная, строчная буква, цифра и спецсимвол';
      }
      debugPrint('Supabase cloud sign up note: $e');
    }

    // Save locally
    if (kIsWeb) {
      try {
        final existingRaw = html.window.localStorage[_kSavedUsersKey] ?? '{}';
        final existing = jsonDecode(existingRaw) as Map<String, dynamic>;
        existing[cleanUsername] = {
          'username': cleanUsername,
          'email': cleanEmail,
          'role': role,
          'display_name': finalDisplayName,
          'created_at': DateTime.now().toIso8601String(),
        };
        html.window.localStorage[_kSavedUsersKey] = jsonEncode(existing);
        html.window.localStorage['cinetrack_pwd_${cleanEmail.toLowerCase()}'] = password;
        html.window.localStorage['cinetrack_pwd_$cleanUsername'] = password;
      } catch (_) {}
    }

    final user = User(
      id: 'u_${cleanUsername.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')}',
      appMetadata: const {'provider': 'cinetrack'},
      userMetadata: {
        'display_name': finalDisplayName,
        'role': role,
        'username': cleanUsername,
      },
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: cleanEmail,
    );

    _persistSession(user, cleanUsername, role);
    _authStreamController.add(const AuthState(AuthChangeEvent.signedIn, null));
    return user;
  }

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    await supabase.auth.signInWithOAuth(
      provider,
      redirectTo: kIsWeb ? html.window.location.origin : null,
      scopes: provider == OAuthProvider.google ? 'email profile' : null,
    );
  }

  Future<void> signOut() async {
    _localCurrentUser = null;
    if (kIsWeb) {
      try {
        html.window.localStorage.remove(_kActiveUserKey);
        html.window.localStorage.remove('cinetrack_custom_profile');
        html.window.localStorage.remove('cinetrack_my_role');
        html.window.localStorage.remove('cinetrack_has_password');
        final keysToRemove = html.window.localStorage.keys
            .where((k) =>
                k.startsWith('cinetrack_my_role_') ||
                k.startsWith('cinetrack_custom_profile_'))
            .toList();
        for (final k in keysToRemove) {
          html.window.localStorage.remove(k);
        }
      } catch (_) {}
    }
    try {
      await supabase.auth.signOut();
    } catch (_) {}
    _authStreamController.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  User? get currentUser {
    if (_localCurrentUser != null) {
      return _localCurrentUser;
    }
    try {
      return supabase.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Session? get currentSession {
    try {
      return supabase.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  Stream<AuthState> get authStateChanges => _authStreamController.stream;
}
