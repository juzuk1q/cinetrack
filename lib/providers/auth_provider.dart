// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';

/// Helper to pick a local image file from PC or smartphone, auto-crop to target aspect ratio and scale down
Future<String?> pickAndCropImageBase64({
  required double targetAspectRatio, // e.g. 1.0 for avatar, 3.0 for banner (1200x400)
  required int targetWidth,          // e.g. 400 for avatar, 1200 for banner
  required int targetHeight,         // e.g. 400 for avatar, 400 for banner
  double quality = 0.85,
}) async {
  if (!kIsWeb) return null;
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..multiple = false;

  uploadInput.click();

  uploadInput.onChange.listen((event) {
    final files = uploadInput.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files[0];
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.listen((_) {
      final rawDataUrl = reader.result;
      if (rawDataUrl is! String) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final img = html.ImageElement()..src = rawDataUrl;
      img.onLoad.listen((_) {
        try {
          final naturalWidth = img.naturalWidth;
          final naturalHeight = img.naturalHeight;
          if (naturalWidth == 0 || naturalHeight == 0) {
            if (!completer.isCompleted) completer.complete(rawDataUrl);
            return;
          }

          // Calculate center crop with target aspect ratio
          final currentRatio = naturalWidth / naturalHeight;
          num sx = 0, sy = 0, sw = naturalWidth, sh = naturalHeight;

          if (currentRatio > targetAspectRatio) {
            // Source is wider than target -> crop sides
            sw = (naturalHeight * targetAspectRatio).round();
            sx = ((naturalWidth - sw) / 2).round();
          } else {
            // Source is taller than target -> crop top/bottom
            sh = (naturalWidth / targetAspectRatio).round();
            sy = ((naturalHeight - sh) / 2).round();
          }

          final canvas = html.CanvasElement(width: targetWidth, height: targetHeight);
          final ctx = canvas.context2D;
          ctx.drawImageScaledFromSource(img, sx, sy, sw, sh, 0, 0, targetWidth, targetHeight);

          final croppedDataUrl = canvas.toDataUrl('image/jpeg', quality);
          if (!completer.isCompleted) completer.complete(croppedDataUrl);
        } catch (_) {
          if (!completer.isCompleted) completer.complete(rawDataUrl);
        }
      });

      img.onError.listen((_) {
        if (!completer.isCompleted) completer.complete(rawDataUrl);
      });
    });

    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  return completer.future;
}

/// Helper to pick a local image file from user's computer or phone on Web and convert to base64 Data URL
Future<String?> pickLocalImageBase64() async {
  return pickAndCropImageBase64(
    targetAspectRatio: 3.0,
    targetWidth: 1200,
    targetHeight: 400,
  );
}

// Repository provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// Auth state notifier (ChangeNotifier for GoRouter refresh)
class AuthStateNotifier extends ChangeNotifier {
  AuthStateNotifier(this._repo) {
    _subscription = _repo.authStateChanges.listen((_) {
      notifyListeners();
    });
  }
  final AuthRepository _repo;
  late final StreamSubscription<AuthState> _subscription;

  void triggerUpdate() {
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final authStateProvider = ChangeNotifierProvider<AuthStateNotifier>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthStateNotifier(repo);
});

// Current user
final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  final repo = ref.watch(authRepositoryProvider);
  return repo.currentUser;
});

// Profile Customization State Notifier (local persistence + Supabase)
class ProfileCustomizationNotifier extends StateNotifier<UserProfile?> {
  ProfileCustomizationNotifier() : super(null) {
    _loadFromLocal();
  }

  void _loadFromLocal() {
    try {
      if (kIsWeb) {
        final raw = html.window.localStorage['cinetrack_custom_profile'];
        if (raw != null && raw.isNotEmpty) {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final prof = UserProfile.fromJson(data);
          // Purge legacy bugged dummy profile if present
          if (prof.username == 'cinelover' || prof.displayName == 'Пользователь') {
            html.window.localStorage.remove('cinetrack_custom_profile');
          } else {
            state = prof;
          }
        }
      }
    } catch (_) {}
  }

  void updateProfile({
    String? displayName,
    String? username,
    String? customTitle,
    String? bannerUrl,
    String? avatarUrl,
    bool? isPrivate,
    List<String>? friends,
    List<String>? unlockedTitles,
  }) {
    if (state == null) {
      state = UserProfile(
        id: 'user-local',
        email: 'user@cinetrack.local',
        displayName: displayName ?? '',
        username: username ?? '',
        createdAt: DateTime.now(),
        customTitle: customTitle,
        bannerUrl: bannerUrl,
        avatarUrl: avatarUrl,
        isPrivate: isPrivate ?? false,
        friends: friends ?? const [],
        unlockedTitles: unlockedTitles ?? const ['welcome'],
      );
    } else {
      state = state!.copyWith(
        displayName: (displayName != null && displayName.isNotEmpty) ? displayName : state!.displayName,
        username: (username != null && username.isNotEmpty) ? username : state!.username,
        customTitle: customTitle,
        bannerUrl: bannerUrl,
        avatarUrl: avatarUrl,
        isPrivate: isPrivate,
        friends: friends,
        unlockedTitles: unlockedTitles,
      );
    }

    _persist();
  }

  void addFriend(String friendUsername, {UserProfile? currentProfile}) {
    final clean = friendUsername.replaceAll('@', '').trim();
    if (clean.isEmpty) return;

    if (state == null && currentProfile != null) {
      state = currentProfile;
    }

    final currentFriends = List<String>.from(state?.friends ?? currentProfile?.friends ?? []);
    if (!currentFriends.contains(clean)) {
      currentFriends.add(clean);
      // Unlock social achievement
      final unlocked = List<String>.from(state?.unlockedTitles ?? currentProfile?.unlockedTitles ?? ['welcome']);
      if (!unlocked.contains('social')) {
        unlocked.add('social');
      }
      updateProfile(friends: currentFriends, unlockedTitles: unlocked);
    }
  }

  void removeFriend(String friendUsername) {
    final clean = friendUsername.replaceAll('@', '').trim();
    final currentFriends = List<String>.from(state?.friends ?? []);
    currentFriends.remove(clean);
    updateProfile(friends: currentFriends);
  }

  void equipTitle(String title) {
    updateProfile(customTitle: title);
  }

  void unlockAchievement(String achievementId) {
    final unlocked = List<String>.from(state?.unlockedTitles ?? ['welcome']);
    if (!unlocked.contains(achievementId)) {
      unlocked.add(achievementId);
      updateProfile(unlockedTitles: unlocked);
    }
  }

  void _persist() {
    try {
      if (kIsWeb && state != null) {
        html.window.localStorage['cinetrack_custom_profile'] =
            jsonEncode(state!.toJson());
      }
    } catch (_) {}
  }
}

final profileCustomizationProvider =
    StateNotifierProvider<ProfileCustomizationNotifier, UserProfile?>((ref) {
  return ProfileCustomizationNotifier();
});

// Current User Profile Provider
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final email = user.email ?? '';
  final emailPrefix = email.contains('@') ? email.split('@').first : 'user';
  final googleFullName = user.userMetadata?['full_name'] as String? ??
      user.userMetadata?['name'] as String? ??
      user.userMetadata?['display_name'] as String?;
  final googleAvatar = user.userMetadata?['avatar_url'] as String? ??
      user.userMetadata?['picture'] as String?;

  try {
    final res = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (res != null) {
      final prof = UserProfile.fromJson(res);

      // Check restrictions (ban / active freeze)
      if (prof.isRestricted) {
        debugPrint('Active user account is restricted (${prof.isBlocked ? "blocked" : "frozen"}). Enforcing sign out.');
        Future.microtask(() => ref.read(authRepositoryProvider).signOut());
      }

      // Automatically sync missing avatar or display name from Google
      bool needDbUpdate = false;
      final updateData = <String, dynamic>{};

      if ((prof.avatarUrl == null || prof.avatarUrl!.isEmpty) &&
          googleAvatar != null &&
          googleAvatar.isNotEmpty) {
        updateData['avatar_url'] = googleAvatar;
        needDbUpdate = true;
      }

      if ((prof.displayName.isEmpty || prof.displayName == 'Пользователь') &&
          googleFullName != null &&
          googleFullName.isNotEmpty) {
        updateData['display_name'] = googleFullName;
        needDbUpdate = true;
      }

      if (prof.username.isEmpty) {
        updateData['username'] = emailPrefix;
        needDbUpdate = true;
      }

      if (needDbUpdate) {
        supabase
            .from('profiles')
            .update(updateData)
            .eq('id', user.id)
            .then((_) {})
            .catchError((_) {});
      }

      return prof;
    } else {
      // Check if user was deleted from Supabase Auth
      try {
        final authRes = await supabase.auth.getUser();
        if (authRes.user == null) {
          Future.microtask(() => ref.read(authRepositoryProvider).signOut());
          return null;
        }
      } catch (authErr) {
        final errStr = authErr.toString().toLowerCase();
        if (errStr.contains('does not exist') ||
            errStr.contains('not found') ||
            errStr.contains('invalid') ||
            errStr.contains('bad_jwt') ||
            errStr.contains('401') ||
            errStr.contains('403')) {
          Future.microtask(() => ref.read(authRepositoryProvider).signOut());
          return null;
        }
      }
    }
  } catch (e) {
    debugPrint('Error fetching user profile from profiles table: $e');
  }

  // Fallback while DB profile is loading
  return UserProfile(
    id: user.id,
    email: email,
    displayName: googleFullName ?? emailPrefix,
    username: user.userMetadata?['username'] as String? ?? emailPrefix,
    avatarUrl: googleAvatar,
    role: 'user',
    createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
  );
});

// Is Admin boolean provider (true for admin)
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (p) => p?.isAdmin ?? false,
    orElse: () => false,
  );
});

// Is Staff boolean provider (true for moderator or admin)
final isStaffProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (p) => p?.isModerator ?? false,
    orElse: () => false,
  );
});

// Admin Users State Notifier (Real-time reactivity from database)
class AdminUsersNotifier extends StateNotifier<List<UserProfile>> {
  AdminUsersNotifier(this._ref) : super([]) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    try {
      final res = await supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      final list = (res as List<dynamic>)
          .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
          .toList();

      state = list;
    } catch (e) {
      debugPrint('Note: Supabase profiles load note: $e');
    }
  }

  void syncUserProfileData({
    required String userId,
    String? displayName,
    String? username,
    String? customTitle,
    String? bannerUrl,
    String? avatarUrl,
    bool? isPrivate,
  }) {
    state = [
      for (final u in state)
        if (u.id == userId || (u.email.isNotEmpty && u.email == _ref.read(currentUserProvider)?.email))
          u.copyWith(
            displayName: displayName ?? u.displayName,
            username: username ?? u.username,
            customTitle: customTitle ?? u.customTitle,
            bannerUrl: bannerUrl ?? u.bannerUrl,
            avatarUrl: avatarUrl ?? u.avatarUrl,
            isPrivate: isPrivate ?? u.isPrivate,
          )
        else
          u,
    ];
  }

  Future<bool> updateRole(String userId, String newRole) async {
    try {
      await supabase.rpc('set_user_role', params: {
        'target_user_id': userId,
        'new_role': newRole,
      });
      await _init();
      _ref.invalidate(userProfileProvider);
      return true;
    } catch (e) {
      debugPrint('Error updating role in profiles table: $e');
      rethrow;
    }
  }

  Future<bool> updateUserTitle(
    String userId,
    String? newTitle, {
    List<String>? unlockedTitles,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'custom_title': newTitle,
      };
      if (unlockedTitles != null) {
        updateData['unlocked_titles'] = unlockedTitles;
      }
      await supabase.from('profiles').update(updateData).eq('id', userId);
      await _init();
      _ref.invalidate(userProfileProvider);
      return true;
    } catch (e) {
      debugPrint('Error updating user title in profiles table: $e');
      rethrow;
    }
  }

  Future<bool> blockOrFreezeUser(
    String userId, {
    required bool isFreeze,
    required String reason,
    Duration? duration,
  }) async {
    final until = (isFreeze && duration != null) ? DateTime.now().add(duration) : null;
    try {
      await supabase.rpc('freeze_or_block_user', params: {
        'target_user_id': userId,
        'set_frozen': isFreeze,
        'set_blocked': !isFreeze,
        'reason': reason,
        'freeze_until': until?.toIso8601String(),
      });
      await _init();
      _ref.invalidate(userProfileProvider);
      return true;
    } catch (e) {
      debugPrint('Error freezing/blocking user: $e');
      rethrow;
    }
  }

  Future<bool> unblockUser(String userId) async {
    try {
      await supabase.rpc('freeze_or_block_user', params: {
        'target_user_id': userId,
        'set_frozen': false,
        'set_blocked': false,
        'reason': null,
        'freeze_until': null,
      });
      await _init();
      _ref.invalidate(userProfileProvider);
      return true;
    } catch (e) {
      debugPrint('Error unblocking user: $e');
      rethrow;
    }
  }

  void refresh() {
    _init();
  }
}

final adminUsersProvider =
    StateNotifierProvider<AdminUsersNotifier, List<UserProfile>>((ref) {
  return AdminUsersNotifier(ref);
});

// Update role helper
Future<bool> updateUserRole(WidgetRef ref, String userId, String newRole) async {
  final success = await ref.read(adminUsersProvider.notifier).updateRole(userId, newRole);
  ref.invalidate(userProfileProvider);
  return success;
}

// Auth actions notifier
class AuthNotifier extends StateNotifier<AsyncValue<void>> {
  AuthNotifier(this._repo) : super(const AsyncValue.data(null));

  final AuthRepository _repo;

  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.signIn(username: username, password: password),
    );
  }

  Future<void> signUp({
    required String username,
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.signUp(
        username: username,
        email: email,
        password: password,
        displayName: displayName,
      ),
    );
  }

  Future<void> signInWithOAuth(OAuthProvider provider) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.signInWithOAuth(provider),
    );
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.signOut());
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<void>>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});
