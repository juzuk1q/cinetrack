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

/// Helper to pick a local image file from user's computer on Web and convert to base64 Data URL
Future<String?> pickLocalImageBase64() async {
  if (!kIsWeb) return null;
  final completer = Completer<String?>();
  final uploadInput = html.FileUploadInputElement()
    ..accept = 'image/png,image/jpeg,image/webp,image/gif'
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
    reader.onLoadEnd.listen((event) {
      final res = reader.result;
      if (res is String && !completer.isCompleted) {
        completer.complete(res);
      } else if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  return completer.future;
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
    try {
      _supabaseSubscription = supabase.auth.onAuthStateChange.listen((_) {
        notifyListeners();
      });
    } catch (_) {}
  }
  final AuthRepository _repo;
  late final StreamSubscription<AuthState> _subscription;
  StreamSubscription<AuthState>? _supabaseSubscription;

  void triggerUpdate() {
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    _supabaseSubscription?.cancel();
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
          state = UserProfile.fromJson(data);
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
      final defUsername = username ?? 'cinelover';
      state = UserProfile(
        id: 'user-local',
        email: 'user@cinetrack.local',
        displayName: displayName ?? 'Пользователь',
        username: defUsername,
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
        displayName: displayName,
        username: username,
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

  void addFriend(String friendUsername) {
    final clean = friendUsername.replaceAll('@', '').trim();
    if (clean.isEmpty) return;
    final currentFriends = List<String>.from(state?.friends ?? []);
    if (!currentFriends.contains(clean)) {
      currentFriends.add(clean);
      // Unlock social achievement
      final unlocked = List<String>.from(state?.unlockedTitles ?? ['welcome']);
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

  final custom = ref.watch(profileCustomizationProvider);

  final email = user.email ?? '';
  final emailPrefix = email.contains('@') ? email.split('@').first : 'cinelover';
  final googleFullName = user.userMetadata?['full_name'] as String? ??
      user.userMetadata?['name'] as String?;
  final googleAvatar = user.userMetadata?['avatar_url'] as String? ??
      user.userMetadata?['picture'] as String?;

  // Remove legacy un-scoped role if present to avoid role leakage across accounts
  if (kIsWeb) {
    try {
      html.window.localStorage.remove('cinetrack_my_role');
    } catch (_) {}
  }

  // Check saved custom role scoped to THIS user ID
  String? locallySavedRole;
  if (kIsWeb) {
    try {
      locallySavedRole = html.window.localStorage['cinetrack_my_role_${user.id}'];
    } catch (_) {}
  }

  try {
    final res = await supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (res != null) {
      final prof = UserProfile.fromJson(res);
      var effective = prof;

      // Apply locally saved role if higher
      if (locallySavedRole != null &&
          locallySavedRole.isNotEmpty &&
          UserProfile.rankForRole(locallySavedRole) > effective.roleRank) {
        effective = effective.copyWith(role: locallySavedRole);
      }

      // Automatically sync missing avatar or display name from Google
      bool needDbUpdate = false;
      final updateData = <String, dynamic>{};

      if ((effective.avatarUrl == null || effective.avatarUrl!.isEmpty) &&
          googleAvatar != null &&
          googleAvatar.isNotEmpty) {
        effective = effective.copyWith(avatarUrl: googleAvatar);
        updateData['avatar_url'] = googleAvatar;
        needDbUpdate = true;
      }

      if ((effective.displayName.isEmpty || effective.displayName == 'Пользователь') &&
          googleFullName != null &&
          googleFullName.isNotEmpty) {
        effective = effective.copyWith(displayName: googleFullName);
        updateData['display_name'] = googleFullName;
        needDbUpdate = true;
      }

      if (effective.username.isEmpty) {
        effective = effective.copyWith(username: emailPrefix);
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

      if (custom != null) {
        effective = effective.copyWith(
          displayName: custom.displayName.isNotEmpty ? custom.displayName : null,
          username: custom.username.isNotEmpty ? custom.username : null,
          customTitle: (effective.customTitle != null && effective.customTitle!.trim().isNotEmpty)
              ? effective.customTitle
              : custom.customTitle,
          bannerUrl: (custom.bannerUrl != null && custom.bannerUrl!.isNotEmpty)
              ? custom.bannerUrl
              : effective.bannerUrl,
          avatarUrl: (custom.avatarUrl != null && custom.avatarUrl!.isNotEmpty)
              ? custom.avatarUrl
              : effective.avatarUrl,
          isPrivate: custom.isPrivate,
          friends: custom.friends.isNotEmpty ? custom.friends : effective.friends,
        );
      }

      // Merge unlocked titles from DB, custom settings, and dynamic platform achievements
      final mergedUnlocked = <String>{'welcome'};
      mergedUnlocked.addAll(effective.unlockedTitles);
      if (custom != null) {
        mergedUnlocked.addAll(custom.unlockedTitles);
      }
      if (effective.role == 'creator') {
        mergedUnlocked.addAll([
          'welcome',
          'collector_3',
          'collector_10',
          'popcorn_master',
          'party_host',
          'night_owl',
          'critic',
          'social',
          'anime_guru',
          'veteran',
          'legend',
          'vip_streamer',
          'coder_badge',
        ]);
      }
      effective = effective.copyWith(unlockedTitles: mergedUnlocked.toList());
      return effective;
    } else {
      // Profile row does not exist in public.profiles. Check if user was deleted from Supabase Auth!
      try {
        final authRes = await supabase.auth.getUser();
        if (authRes.user == null) {
          debugPrint('User was deleted from Supabase Auth. Triggering signOut...');
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
          debugPrint('User session invalid on server: $authErr. Triggering signOut...');
          Future.microtask(() => ref.read(authRepositoryProvider).signOut());
          return null;
        }
      }
    }
  } catch (e) {
    debugPrint('Error fetching user profile from profiles table: $e');
  }

  // Fallback from auth session or metadata
  var role = user.userMetadata?['role'] as String? ?? 'user';
  if (locallySavedRole != null && locallySavedRole.isNotEmpty) {
    role = locallySavedRole;
  }

  final displayName = custom?.displayName ??
      (user.userMetadata?['display_name'] as String? ?? googleFullName ?? emailPrefix);
  final username = custom?.username ??
      (user.userMetadata?['username'] as String? ?? emailPrefix);
  final avatarUrl = (custom?.avatarUrl != null && custom!.avatarUrl!.isNotEmpty)
      ? custom.avatarUrl
      : googleAvatar;

  return UserProfile(
    id: user.id,
    email: email,
    displayName: displayName,
    username: username,
    role: role,
    createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
    customTitle: custom?.customTitle,
    bannerUrl: custom?.bannerUrl,
    avatarUrl: avatarUrl,
    isPrivate: custom?.isPrivate ?? false,
    friends: custom?.friends ?? const [],
    unlockedTitles: custom?.unlockedTitles ?? const ['welcome', 'legend', 'popcorn_master'],
  );
});

// Is Admin boolean provider (true for admin, developer, and creator)
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (p) {
      if (p != null) return p.isAdmin;
      final r = user.userMetadata?['role'] as String? ?? 'user';
      return r == 'admin' || r == 'creator' || r == 'developer' || r == 'coder';
    },
    orElse: () {
      final r = user.userMetadata?['role'] as String? ?? 'user';
      return r == 'admin' || r == 'creator' || r == 'developer' || r == 'coder';
    },
  );
});

// Is Staff boolean provider (true for moderator, admin, developer, creator)
final isStaffProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return false;

  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.maybeWhen(
    data: (p) => p?.isModerator ?? false,
    orElse: () => false,
  );
});

// Admin Users State Notifier (Real-time reactivity + persistence)
class AdminUsersNotifier extends StateNotifier<List<UserProfile>> {
  AdminUsersNotifier(this._ref) : super([]) {
    _init();
  }

  final Ref _ref;

  List<UserProfile> _syncWithOverrides(List<UserProfile> list) {
    final current = _ref.read(currentUserProvider);
    final custom = _ref.read(profileCustomizationProvider);
    String? localRole;
    if (kIsWeb && current != null) {
      try {
        html.window.localStorage.remove('cinetrack_my_role');
        localRole = html.window.localStorage['cinetrack_my_role_${current.id}'];
      } catch (_) {}
    }

    if (current == null) return list;

    final email = (current.email ?? '').toLowerCase();
    final googleAvatar = current.userMetadata?['avatar_url'] as String? ??
        current.userMetadata?['picture'] as String?;
    final googleName = current.userMetadata?['full_name'] as String? ??
        current.userMetadata?['name'] as String?;

    bool found = false;
    final updated = list.map((u) {
      if (u.id == current.id || u.email.toLowerCase() == email) {
        found = true;
        var r = u.role;
        if (localRole != null &&
            localRole.isNotEmpty &&
            UserProfile.rankForRole(localRole) > u.roleRank) {
          r = localRole;
        }

        return u.copyWith(
          displayName: custom?.displayName.isNotEmpty == true
              ? custom!.displayName
              : (u.displayName.isNotEmpty ? u.displayName : googleName),
          username: custom?.username.isNotEmpty == true
              ? custom!.username
              : u.username,
          avatarUrl: custom?.avatarUrl?.isNotEmpty == true
              ? custom!.avatarUrl
              : (u.avatarUrl?.isNotEmpty == true ? u.avatarUrl : googleAvatar),
          bannerUrl: custom?.bannerUrl?.isNotEmpty == true
              ? custom!.bannerUrl
              : u.bannerUrl,
          customTitle: custom?.customTitle?.isNotEmpty == true
              ? custom!.customTitle
              : u.customTitle,
          role: r,
        );
      }
      return u;
    }).toList();

    if (!found) {
      final emailPrefix = email.contains('@') ? email.split('@').first : 'cinelover';
      final defaultRole = current.userMetadata?['role'] as String? ?? (localRole ?? 'user');
      final newCurrent = UserProfile(
        id: current.id,
        email: current.email ?? '',
        displayName: custom?.displayName.isNotEmpty == true
            ? custom!.displayName
            : (googleName ?? emailPrefix),
        username: custom?.username.isNotEmpty == true
            ? custom!.username
            : emailPrefix,
        role: defaultRole,
        createdAt: DateTime.now(),
        customTitle: custom?.customTitle,
        avatarUrl: custom?.avatarUrl?.isNotEmpty == true ? custom!.avatarUrl : googleAvatar,
        bannerUrl: custom?.bannerUrl,
        unlockedTitles: const ['welcome'],
      );
      updated.insert(0, newCurrent);
    }

    return updated;
  }

  void _init() async {
    // 1. Try to fetch live from Supabase `profiles` table first
    try {
      final res = await supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      final list = (res as List<dynamic>)
          .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
          .toList();

      if (list.isNotEmpty) {
        state = _syncWithOverrides(list);
        _saveToLocal();
        return;
      }
    } catch (e) {
      debugPrint('Note: Supabase profiles load fallback: $e');
    }

    // 2. Load from localStorage if available
    List<UserProfile> loaded = [];
    if (kIsWeb) {
      try {
        final raw = html.window.localStorage['cinetrack_admin_users'];
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          loaded = list
              .map((e) => UserProfile.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        debugPrint('Error reading admin users from localStorage: $e');
      }
    }

    if (loaded.isNotEmpty) {
      state = _syncWithOverrides(loaded);
      _saveToLocal();
      return;
    }

    // 3. Seed default mock community list with rich roles
    final current = _ref.read(currentUserProvider);
    final custom = _ref.read(profileCustomizationProvider);
    final email = current?.email ?? '';
    final defaultRole = current?.userMetadata?['role'] as String? ?? 'user';
    final emailPrefix = email.contains('@') ? email.split('@').first : 'user';

    final defaultList = [
      if (current != null)
        UserProfile(
          id: current.id,
          email: email,
          displayName: current.userMetadata?['display_name'] ?? emailPrefix,
          username: emailPrefix,
          role: defaultRole,
          createdAt: DateTime.now(),
          customTitle: custom?.customTitle,
          unlockedTitles: const ['welcome'],
        ),
      UserProfile(
        id: 'u_dev_1',
        email: 'coder@cinetrack.local',
        displayName: 'Никита Dev',
        username: 'nikita_coder',
        role: 'developer',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        customTitle: 'Архитектор кода 💻',
        unlockedTitles: const ['welcome', 'coder_badge', 'collector_10'],
      ),
      UserProfile(
        id: 'u_mod_1',
        email: 'alex_mod@cinetrack.local',
        displayName: 'Алексей Mod',
        username: 'alex_cinema',
        role: 'moderator',
        createdAt: DateTime.now().subtract(const Duration(days: 4)),
        customTitle: 'Хранитель кинозала 🏛️',
        unlockedTitles: const ['welcome', 'popcorn_master', 'veteran'],
      ),
      UserProfile(
        id: 'u_viewer_2',
        email: 'daria@cinetrack.local',
        displayName: 'Дарья Movie',
        username: 'daria_movie',
        role: 'user',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        customTitle: 'Кинокритик 💬',
        unlockedTitles: const ['welcome', 'critic', 'collector_3'],
      ),
    ];

    state = _syncWithOverrides(defaultList);
    _saveToLocal();
  }

  void _saveToLocal() {
    if (kIsWeb) {
      try {
        html.window.localStorage['cinetrack_admin_users'] =
            jsonEncode(state.map((e) => e.toJson()).toList());
      } catch (_) {}
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
    _saveToLocal();
  }

  Future<bool> updateRole(String userId, String newRole) async {
    state = [
      for (final u in state)
        if (u.id == userId) u.copyWith(role: newRole) else u,
    ];
    _saveToLocal();

    // If changing own role, also cache locally scoped to user id so it survives session refreshes
    final current = _ref.read(currentUserProvider);
    if (current != null && current.id == userId && kIsWeb) {
      try {
        html.window.localStorage['cinetrack_my_role_$userId'] = newRole;
      } catch (_) {}
    }

    try {
      await supabase.from('profiles').update({'role': newRole}).eq('id', userId);
    } catch (e) {
      debugPrint('Note updating role in profiles table: $e');
    }
    _ref.invalidate(userProfileProvider);
    return true;
  }

  Future<bool> updateUserTitle(
    String userId,
    String? newTitle, {
    List<String>? unlockedTitles,
  }) async {
    state = [
      for (final u in state)
        if (u.id == userId)
          u.copyWith(
            customTitle: newTitle,
            unlockedTitles: unlockedTitles ?? u.unlockedTitles,
          )
        else
          u,
    ];
    _saveToLocal();

    // If updating current user's title, immediately sync to reactive customization notifier
    final current = _ref.read(currentUserProvider);
    if (current != null && current.id == userId) {
      _ref.read(profileCustomizationProvider.notifier).updateProfile(
            customTitle: newTitle,
            unlockedTitles: unlockedTitles,
          );
      _ref.invalidate(userProfileProvider);
    }

    try {
      final updateData = <String, dynamic>{
        'custom_title': newTitle,
      };
      if (unlockedTitles != null) {
        updateData['unlocked_titles'] = unlockedTitles;
      }
      await supabase.from('profiles').update(updateData).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating user title in profiles table: $e');
    }
    return true;
  }

  Future<bool> blockOrFreezeUser(
    String userId, {
    required bool isFreeze,
    required String reason,
    Duration? duration,
  }) async {
    final until = (isFreeze && duration != null) ? DateTime.now().add(duration) : null;
    state = [
      for (final u in state)
        if (u.id == userId)
          u.copyWith(
            isBlocked: !isFreeze,
            isFrozen: isFreeze,
            blockReason: reason,
            blockUntil: until,
          )
        else
          u,
    ];
    _saveToLocal();

    try {
      await supabase.from('profiles').update({
        'is_blocked': !isFreeze,
        'is_frozen': isFreeze,
        'block_reason': reason,
        'block_until': until?.toIso8601String(),
      }).eq('id', userId);
    } catch (_) {}
    return true;
  }

  Future<bool> unblockUser(String userId) async {
    state = [
      for (final u in state)
        if (u.id == userId)
          UserProfile(
            id: u.id,
            email: u.email,
            displayName: u.displayName,
            username: u.username,
            role: u.role,
            createdAt: u.createdAt,
            customTitle: u.customTitle,
            bannerUrl: u.bannerUrl,
            avatarUrl: u.avatarUrl,
            isPrivate: u.isPrivate,
            friends: u.friends,
            unlockedTitles: u.unlockedTitles,
            isBlocked: false,
            isFrozen: false,
            blockReason: null,
            blockUntil: null,
          )
        else
          u,
    ];
    _saveToLocal();

    try {
      await supabase.from('profiles').update({
        'is_blocked': false,
        'is_frozen': false,
        'block_reason': null,
        'block_until': null,
      }).eq('id', userId);
    } catch (_) {}
    return true;
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
