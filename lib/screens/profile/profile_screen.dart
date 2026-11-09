// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../../models/media_item.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/stats_provider.dart';
import '../../repositories/stats_repository.dart';
import '../../widgets/app_header.dart';
import '../../widgets/media_card.dart';
import '../../widgets/top_notification.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? targetUsername;

  const ProfileScreen({super.key, this.targetUsername});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _activeTab = 0; // 0: Коллекция & Избранное, 1: Статистика, 2: Друзья
  String _statusFilter = 'all'; // 'all', 'want_to_watch', 'watching', 'watched'
  final _friendSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _friendSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final statsAsync = ref.watch(statsDataProvider);
    final mediaAsync = ref.watch(mediaListProvider);
    final customProfile = ref.watch(profileCustomizationProvider);
    final allUsers = ref.watch(adminUsersProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    final dbProfile = userProfileAsync.value;

    final email = user?.email ?? 'Пользователь';
    final emailPrefix = email.contains('@') ? email.split('@').first : 'cinelover';
    final googleAvatar = user?.userMetadata?['avatar_url'] as String? ??
        user?.userMetadata?['picture'] as String?;
    final googleFullName = user?.userMetadata?['full_name'] as String? ??
        user?.userMetadata?['name'] as String?;

    // Current user profile data with multi-source fallback
    final myDisplayName = customProfile?.displayName.isNotEmpty == true
        ? customProfile!.displayName
        : (dbProfile?.displayName.isNotEmpty == true
            ? dbProfile!.displayName
            : (googleFullName ?? emailPrefix));

    final myUsername = customProfile?.username.isNotEmpty == true
        ? customProfile!.username
        : (dbProfile?.username.isNotEmpty == true
            ? dbProfile!.username
            : emailPrefix);

    final myTitle = dbProfile?.customTitle?.isNotEmpty == true
        ? dbProfile!.customTitle!
        : (customProfile?.customTitle?.isNotEmpty == true
            ? customProfile!.customTitle!
            : (dbProfile?.effectiveTitle ?? 'Новичок стримов 🍿'));

    final myRoleLabel = dbProfile?.roleLabel ?? (isAdmin ? 'Администратор ⭐' : 'Зритель 🍿');
    final myRole = dbProfile?.role ?? (user?.userMetadata?['role'] as String? ?? 'user');

    final myBanner = customProfile?.bannerUrl?.isNotEmpty == true
        ? customProfile!.bannerUrl!
        : (dbProfile?.bannerUrl?.isNotEmpty == true
            ? dbProfile!.bannerUrl!
            : 'https://avatars.mds.yandex.net/get-kinopoisk-image/1601250/20399d86-a579-4a00-b6e5-4a69ec40fe50/orig');

    final myAvatar = customProfile?.avatarUrl?.isNotEmpty == true
        ? customProfile!.avatarUrl
        : (dbProfile?.avatarUrl?.isNotEmpty == true
            ? dbProfile!.avatarUrl
            : googleAvatar);

    final myIsPrivate = customProfile?.isPrivate ?? (dbProfile?.isPrivate ?? false);
    final myFriends = customProfile?.friends ?? (dbProfile?.friends ?? const <String>[]);
    final myUnlockedTitlesSet = <String>{
      'welcome',
      ...?dbProfile?.unlockedTitles,
      ...?customProfile?.unlockedTitles,
    };
    final userMediaList = mediaAsync.value ?? [];
    if (userMediaList.length >= 3) myUnlockedTitlesSet.add('collector_3');
    if (userMediaList.length >= 10) myUnlockedTitlesSet.add('collector_10');
    if (userMediaList.any((e) => e.status == 'watched')) myUnlockedTitlesSet.add('popcorn_master');
    if (myFriends.isNotEmpty) myUnlockedTitlesSet.add('social');
    if (myRole == 'creator' || isAdmin) {
      myUnlockedTitlesSet.addAll(['party_host', 'night_owl', 'critic', 'veteran', 'legend', 'vip_streamer', 'coder_badge']);
    }
    final myUnlockedTitles = myUnlockedTitlesSet.toList();

    // Check if viewing someone else's profile via route
    final isTargetingOther = widget.targetUsername != null &&
        widget.targetUsername!.trim().isNotEmpty &&
        widget.targetUsername!.toLowerCase().replaceAll('@', '') !=
            myUsername.toLowerCase().replaceAll('@', '');

    UserProfile? otherProfile;
    if (isTargetingOther) {
      final clean = widget.targetUsername!.toLowerCase().replaceAll('@', '');
      for (final u in allUsers) {
        if (u.handle.toLowerCase() == clean ||
            u.username.toLowerCase() == clean ||
            u.email.toLowerCase() == '$clean@cinetrack.local' ||
            u.id == clean) {
          otherProfile = u;
          break;
        }
      }
      // If user profile is not found, render dedicated 404 page
      if (otherProfile == null) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F0F1A),
          body: Column(
            children: [
              const AppHeader(activeRoute: '/profile'),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Icon(
                            Icons.person_off_rounded,
                            size: 64,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Данный профиль не найден :(',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Пользователь @${widget.targetUsername} не существует или был удален.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white60,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => context.go('/'),
                          icon: const Icon(Icons.home_rounded),
                          label: const Text('На главную',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    final isViewingSelf = !isTargetingOther;
    final effectiveDisplayName =
        isViewingSelf ? myDisplayName : otherProfile!.displayName;
    final effectiveUsername =
        isViewingSelf ? myUsername : otherProfile!.handle;
    final effectiveTitle =
        isViewingSelf ? myTitle : otherProfile!.effectiveTitle;
    final effectiveRoleLabel =
        isViewingSelf ? myRoleLabel : otherProfile!.roleLabel;
    final effectiveRole =
        isViewingSelf ? myRole : otherProfile!.role;
    final effectiveBanner =
        isViewingSelf ? myBanner : (otherProfile!.bannerUrl ?? myBanner);
    final effectiveAvatar =
        isViewingSelf ? myAvatar : otherProfile!.avatarUrl;
    final effectiveIsPrivate =
        isViewingSelf ? myIsPrivate : otherProfile!.isPrivate;
    final effectiveUnlockedTitles = isViewingSelf
        ? myUnlockedTitles
        : (otherProfile?.unlockedTitles ?? const <String>['welcome']);
    final isFriend = !isViewingSelf && myFriends.contains(otherProfile!.handle);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: CustomScrollView(
        slivers: [
          // 1. Top Modern Streaming Nav Bar with Live Search (Header)
          const SliverToBoxAdapter(
            child: AppHeader(activeRoute: '/profile'),
          ),

          // 2. User Profile Header with Banner & Discord-style Card
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(32, 20, 32, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF16162A),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top: Panoramic Banner Cover
                    Stack(
                      children: [
                        SizedBox(
                          height: 190,
                          width: double.infinity,
                          child: Image.network(
                            effectiveBanner,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF2E1065),
                                    Color(0xFF1E1B4B),
                                    Color(0xFF0F172A),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Gradient vignette on banner
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.5),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Edit Banner Button in Top-Right (only for self)
                        if (isViewingSelf)
                          Positioned(
                            top: 14,
                            right: 14,
                            child: InkWell(
                              onTap: () => _showEditProfileDialog(
                                context,
                                currentName: myDisplayName,
                                currentUsername: myUsername,
                                currentTitle: myTitle,
                                currentBanner: myBanner,
                                currentAvatar: myAvatar,
                                isPrivate: myIsPrivate,
                                unlockedTitles: myUnlockedTitles,
                                mediaCount: mediaAsync.value?.length ?? 0,
                                watchedCount: mediaAsync.value?.where((e) => e.status == 'watched').length ?? 0,
                                friendsCount: myFriends.length,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white30),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.camera_alt_rounded,
                                        size: 14, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text(
                                      'Сменить баннер',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    // Bottom: Info Row with Avatar offset
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 22),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Avatar shifted upward over banner bottom
                          Transform.translate(
                            offset: const Offset(0, -32),
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: const Color(0xFF16162A),
                                        width: 4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 42,
                                    backgroundColor: const Color(0xFF7C3AED),
                                    backgroundImage: effectiveAvatar != null &&
                                            effectiveAvatar.isNotEmpty
                                        ? NetworkImage(effectiveAvatar)
                                        : null,
                                    child: (effectiveAvatar == null || effectiveAvatar.isEmpty)
                                        ? Text(
                                            effectiveDisplayName.isNotEmpty
                                                ? effectiveDisplayName[0].toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              fontSize: 34,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          )
                                        : null,
                                  ),
                                ),
                                if (isViewingSelf)
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: InkWell(
                                      onTap: () async {
                                        final newAvatarBase64 = await pickLocalImageBase64();
                                        if (newAvatarBase64 != null) {
                                          ref
                                              .read(profileCustomizationProvider.notifier)
                                              .updateProfile(avatarUrl: newAvatarBase64);

                                          final cur = ref.read(currentUserProvider);
                                          if (cur != null) {
                                            try {
                                              await supabase
                                                  .from('profiles')
                                                  .update({'avatar_url': newAvatarBase64})
                                                  .eq('id', cur.id);
                                            } catch (_) {}

                                            ref.read(adminUsersProvider.notifier).syncUserProfileData(
                                                  userId: cur.id,
                                                  avatarUrl: newAvatarBase64,
                                                );
                                            ref.invalidate(userProfileProvider);
                                          }

                                          if (context.mounted) {
                                            TopNotification.showSuccess(
                                                context, 'Аватар успешно загружен и сохранен! ✨');
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF7C3AED),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.photo_camera_rounded,
                                            size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 18),

                          // Name, Username handle, Role Badge & Title
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      Text(
                                        effectiveDisplayName,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),

                                      // 1. System Role Badge (Distinct from titles)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: effectiveRole == 'creator'
                                              ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                                              : (effectiveRole == 'developer' || effectiveRole == 'coder'
                                                  ? const Color(0xFF06B6D4).withValues(alpha: 0.25)
                                                  : (effectiveRole == 'admin'
                                                      ? const Color(0xFFEAB308).withValues(alpha: 0.25)
                                                      : (effectiveRole == 'moderator'
                                                          ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                                                          : Colors.white10))),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: effectiveRole == 'creator'
                                                ? const Color(0xFFF59E0B).withValues(alpha: 0.7)
                                                : (effectiveRole == 'developer' || effectiveRole == 'coder'
                                                    ? const Color(0xFF06B6D4).withValues(alpha: 0.7)
                                                    : (effectiveRole == 'admin'
                                                        ? const Color(0xFFEAB308).withValues(alpha: 0.7)
                                                        : (effectiveRole == 'moderator'
                                                            ? const Color(0xFF6366F1).withValues(alpha: 0.7)
                                                            : Colors.white24))),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          effectiveRoleLabel,
                                          style: TextStyle(
                                            color: effectiveRole == 'creator'
                                                ? const Color(0xFFFBBF24)
                                                : (effectiveRole == 'developer' || effectiveRole == 'coder'
                                                    ? const Color(0xFF22D3EE)
                                                    : (effectiveRole == 'admin'
                                                        ? const Color(0xFFFDE047)
                                                        : (effectiveRole == 'moderator'
                                                            ? const Color(0xFFA5B4FC)
                                                            : Colors.white70))),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),

                                      // 2. Custom Title Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 9, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFF9F67FF).withValues(alpha: 0.5),
                                            width: 0.9,
                                          ),
                                        ),
                                        child: Text(
                                          effectiveTitle,
                                          style: const TextStyle(
                                            color: Color(0xFFD8B4FE),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  // Handle & Privacy Badge
                                  Row(
                                    children: [
                                      Text(
                                        '@$effectiveUsername',
                                        style: const TextStyle(
                                          color: Color(0xFFC084FC),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: effectiveIsPrivate
                                              ? Colors.orange.withValues(alpha: 0.15)
                                              : Colors.green.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: effectiveIsPrivate
                                                ? Colors.orangeAccent.withValues(alpha: 0.4)
                                                : Colors.greenAccent.withValues(alpha: 0.4),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          effectiveIsPrivate
                                              ? 'Приватный профиль 🔒'
                                              : 'Открытый профиль 🌐',
                                          style: TextStyle(
                                            color: effectiveIsPrivate
                                                ? Colors.orangeAccent
                                                : Colors.greenAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Персональный профиль, личная коллекция и совместные просмотры',
                                    style: TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                  ),

                                  // Earned Achievements & Titles badge pills
                                  if (effectiveUnlockedTitles.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: effectiveUnlockedTitles.map((achId) {
                                        final ach = UserAchievementsCatalog.list
                                            .where((a) => a.id == achId || a.title == achId)
                                            .firstOrNull;
                                        final displayIcon = ach?.icon ?? '⭐';
                                        final displayTitle = ach?.title ?? achId;
                                        final displayDesc = ach?.description ?? 'Особый полученный титул профиля';

                                        return Tooltip(
                                          message: '$displayTitle: $displayDesc',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF261D42),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: const Color(0xFF9F67FF).withValues(alpha: 0.4),
                                                  width: 0.8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(displayIcon,
                                                    style: const TextStyle(fontSize: 12)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  displayTitle,
                                                  style: const TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Profile Action Buttons
                          if (isViewingSelf) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.tune_rounded, size: 16),
                              label: const Text('Настроить профиль',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5)),
                              onPressed: () => _showEditProfileDialog(
                                context,
                                currentName: myDisplayName,
                                currentUsername: myUsername,
                                currentTitle: myTitle,
                                currentBanner: myBanner,
                                currentAvatar: myAvatar,
                                isPrivate: myIsPrivate,
                                unlockedTitles: myUnlockedTitles,
                                mediaCount: mediaAsync.value?.length ?? 0,
                                watchedCount: mediaAsync.value?.where((e) => e.status == 'watched').length ?? 0,
                                friendsCount: myFriends.length,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Copy Link to Profile Button
                            IconButton(
                              icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white70),
                              tooltip: 'Скопировать ссылку на профиль',
                              onPressed: () {
                                final link = kIsWeb
                                    ? '${html.window.location.origin}/user/@$myUsername'
                                    : 'https://cinetrack.x1kwq.workers.dev/user/@$myUsername';
                                Clipboard.setData(ClipboardData(text: link));
                                TopNotification.showSuccess(
                                  context,
                                  'Ссылка на профиль скопирована! 📋',
                                );
                              },
                            ),

                            // Staff access: Admin Panel
                            if (isAdmin) ...[
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                    Icons.admin_panel_settings_rounded,
                                    size: 16),
                                label: const Text('Админ-панель',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12)),
                                onPressed: () => context.go('/admin'),
                              ),
                            ],
                          ] else ...[
                            // Viewing someone else
                            if (isFriend)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF10B981),
                                  side: const BorderSide(color: Color(0xFF10B981)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('В друзьях'),
                                onPressed: () {},
                              )
                            else
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                icon: const Icon(Icons.person_add_rounded, size: 16),
                                label: const Text('Добавить в друзья'),
                                onPressed: () {
                                  ref
                                      .read(profileCustomizationProvider.notifier)
                                      .addFriend(otherProfile!.handle);
                                  TopNotification.showSuccess(
                                    context,
                                    'Пользователь @${otherProfile.handle} добавлен в друзья! 🤝',
                                  );
                                },
                              ),
                            const SizedBox(width: 8),

                            // Copy Link to other user's profile
                            IconButton(
                              icon: const Icon(Icons.share_rounded, size: 18, color: Colors.white70),
                              tooltip: 'Скопировать ссылку на профиль',
                              onPressed: () {
                                final link = kIsWeb
                                    ? '${html.window.location.origin}/user/@$effectiveUsername'
                                    : 'https://cinetrack.x1kwq.workers.dev/user/@$effectiveUsername';
                                Clipboard.setData(ClipboardData(text: link));
                                TopNotification.showSuccess(
                                  context,
                                  'Ссылка на профиль скопирована! 📋',
                                );
                              },
                            ),

                            // If staff viewing user, show shortcut to admin panel
                            if (isAdmin) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Color(0xFFF59E0B)),
                                tooltip: 'Управление пользователем в Админ-панели',
                                onPressed: () => context.go('/admin'),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      // If viewing other user's private profile: show private lock card
      if (!isViewingSelf && effectiveIsPrivate)
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16162A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_rounded, size: 48, color: Color(0xFFF59E0B)),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Этот профиль является приватным',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Пользователь @$effectiveUsername ограничил доступ к своему профилю. Коллекция фильмов, статистика и список друзей скрыты.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        )
      else ...[
        // 3. Tab Switcher Bar: [ 🔖 Коллекция ] vs [ 📊 Статистика ] vs [ 👥 Друзья ]
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    _buildSectionTab(
                      index: 0,
                      icon: Icons.bookmark_added_rounded,
                      label: isViewingSelf ? 'Моя коллекция & Избранное' : 'Коллекция',
                      badgeCount: mediaAsync.value?.length,
                    ),
                    const SizedBox(width: 12),
                    _buildSectionTab(
                      index: 1,
                      icon: Icons.insights_rounded,
                      label: 'Статистика просмотров',
                    ),
                    const SizedBox(width: 12),
                    _buildSectionTab(
                      index: 2,
                      icon: Icons.people_alt_rounded,
                      label: 'Друзья',
                      badgeCount: isViewingSelf ? myFriends.length : (otherProfile?.friends.length ?? 0),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // 4. Body based on active tab
        if (_activeTab == 0)
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: mediaAsync.when(
                    data: (items) => _buildCollectionBody(context, items),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Center(child: Text('Ошибка загрузки: $e')),
                  ),
                ),
              ),
            ),
          )
        else if (_activeTab == 1)
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: statsAsync.when(
                    data: (stats) => _buildStatsBody(context, stats),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => Center(child: Text('Ошибка: $e')),
                  ),
                ),
              ),
            ),
          )
        else
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _buildFriendsBody(
                    context,
                    isViewingSelf ? myFriends : (otherProfile?.friends ?? []),
                    allUsers,
                  ),
                ),
              ),
            ),
          ),
      ],

          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      ),
    );
  }

  // FRIENDS TAB CONTENT
  Widget _buildFriendsBody(
    BuildContext context,
    List<String> friends,
    List<UserProfile> allUsers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add friend row
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF16162A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _friendSearchCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Добавить друга по @юзернейму (например, alex_cinema, daria_movie)...',
                    prefixIcon: const Icon(Icons.person_search_rounded, size: 20),
                    filled: true,
                    fillColor: const Color(0xFF121222),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (val) => _handleAddFriend(val.trim()),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Добавить в друзья'),
                onPressed: () => _handleAddFriend(_friendSearchCtrl.text.trim()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            Text(
              'Список друзей (${friends.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const Spacer(),
            const Text(
              'Приглашайте друзей в комнаты совместного просмотра',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (friends.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E34),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(
                      Icons.group_outlined,
                      size: 46,
                      color: Color(0xFF9F67FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'У вас пока нет друзей в CineTrack',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Добавляйте кинолюбителей по юзернейму для совместного просмотра в комнатах!',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('alex_cinema'),
                        onPressed: () => _handleAddFriend('alex_cinema'),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: const Text('daria_movie'),
                        onPressed: () => _handleAddFriend('daria_movie'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: friends.length,
            itemBuilder: (context, i) {
              final friendHandle = friends[i];
              // Try finding full user
              UserProfile? match;
              for (final u in allUsers) {
                if (u.handle.toLowerCase() == friendHandle.toLowerCase() ||
                    u.username.toLowerCase() == friendHandle.toLowerCase()) {
                  match = u;
                  break;
                }
              }

              final name = match?.displayName ?? friendHandle;
              final title = match?.effectiveTitle ?? 'Киноман 🍿';
              final avatar = match?.avatarUrl;

              return Card(
                color: const Color(0xFF16162A),
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF7C3AED),
                            backgroundImage: avatar != null && avatar.isNotEmpty
                                ? NetworkImage(avatar)
                                : null,
                            child: (avatar == null || avatar.isEmpty)
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'F',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF16162A), width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '@$friendHandle',
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: const TextStyle(
                                  color: Color(0xFFD8B4FE), fontSize: 11),
                            ),
                          ],
                        ),
                      ),

                      // Actions: Invite to Room & Remove
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7C3AED),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.tv_rounded, size: 14),
                        label: const Text('Пригласить в комнату',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          TopNotification.showSuccess(
                            context,
                            'Приглашение отправлено пользователю @$friendHandle! 🍿',
                            title: 'Приглашение в комнату',
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Colors.white38),
                        tooltip: 'Удалить из друзей',
                        onPressed: () {
                          ref
                              .read(profileCustomizationProvider.notifier)
                              .removeFriend(friendHandle);
                          TopNotification.showWarning(
                            context,
                            'Пользователь @$friendHandle удален из друзей',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _handleAddFriend(String handle) {
    final clean = handle.replaceAll('@', '').trim();
    if (clean.isEmpty) return;
    _friendSearchCtrl.clear();
    ref.read(profileCustomizationProvider.notifier).addFriend(clean);
    TopNotification.showSuccess(
      context,
      'Пользователь @$clean успешно добавлен в список друзей! 🤝',
      title: 'Новый друг',
    );
  }

  Widget _buildSectionTab({
    required int index,
    required IconData icon,
    required String label,
    int? badgeCount,
  }) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C3AED)
              : const Color(0xFF1E1E34),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF9F67FF) : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black26 : const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCollectionBody(BuildContext context, List<MediaItem> rawItems) {
    // Deduplicate items to guarantee no duplicate cards
    final uniqueMap = <String, MediaItem>{};
    for (final item in rawItems) {
      final key = (item.kinopoiskId != null && item.kinopoiskId! > 0)
          ? 'kp_${item.kinopoiskId}'
          : 'title_${item.title.trim().toLowerCase()}';
      uniqueMap.putIfAbsent(key, () => item);
    }
    final allItems = uniqueMap.values.toList();

    final filtered = allItems.where((item) {
      if (_statusFilter == 'all') return true;
      return item.status == _statusFilter;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Фильтр:',
              style: TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 10),
            Wrap(
              spacing: 8,
              children: [
                _buildStatusChip('all', 'Все (${allItems.length})'),
                _buildStatusChip(
                  'want_to_watch',
                  'Хочу посмотреть (${allItems.where((e) => e.status == 'want_to_watch').length})',
                ),
                _buildStatusChip(
                  'watching',
                  'Смотрю (${allItems.where((e) => e.status == 'watching').length})',
                ),
                _buildStatusChip(
                  'watched',
                  'Просмотрено (${allItems.where((e) => e.status == 'watched').length})',
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('В каталог фильмов'),
              onPressed: () => context.go('/library'),
            ),
          ],
        ),
        const SizedBox(height: 18),

        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E34),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(
                      Icons.bookmark_border_rounded,
                      size: 48,
                      color: Color(0xFF9F67FF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusFilter == 'all'
                        ? 'В вашей коллекции пока пусто'
                        : 'Нет фильмов с выбранным статусом',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ищите фильмы и сериалы в каталоге и нажимайте «+ В коллекцию»',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Перейти к поиску фильмов'),
                    onPressed: () => context.go('/library'),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              childAspectRatio: 0.62,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: filtered.length,
            itemBuilder: (context, i) => MediaCard(item: filtered[i]),
          ),
      ],
    );
  }

  Widget _buildStatusChip(String statusKey, String label) {
    final isSelected = _statusFilter == statusKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _statusFilter = statusKey);
      },
    );
  }

  Widget _buildStatsBody(BuildContext context, StatsData stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ПЕРСОНАЛЬНАЯ СТАТИСТИКА ПРОСМОТРОВ',
          style: TextStyle(
            color: Color(0xFF9F67FF),
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 14),

        LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 700 ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.2,
              children: [
                _buildKpiCard(
                  title: 'Всего в коллекции',
                  value: '${stats.totalCount}',
                  icon: Icons.movie_filter_rounded,
                  color: const Color(0xFF7C3AED),
                ),
                _buildKpiCard(
                  title: 'Просмотрено',
                  value: '${stats.byStatus['watched'] ?? 0}',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                ),
                _buildKpiCard(
                  title: 'В процессе',
                  value: '${stats.byStatus['watching'] ?? 0}',
                  icon: Icons.play_circle_fill_rounded,
                  color: const Color(0xFFF59E0B),
                ),
                _buildKpiCard(
                  title: 'Средняя оценка',
                  value: stats.averageRating > 0
                      ? '${stats.averageRating.toStringAsFixed(1)} ★'
                      : '—',
                  icon: Icons.star_rounded,
                  color: const Color(0xFFFFCA28),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPieCard(stats)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGenreCard(stats)),
                ],
              );
            }
            return Column(
              children: [
                _buildPieCard(stats),
                const SizedBox(height: 16),
                _buildGenreCard(stats),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieCard(StatsData stats) {
    final watched = stats.byStatus['watched'] ?? 0;
    final watching = stats.byStatus['watching'] ?? 0;
    final want = stats.byStatus['want_to_watch'] ?? 0;
    final total = stats.totalCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Распределение по статусам',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const SizedBox(
              height: 140,
              child: Center(
                child: Text('Добавьте фильмы, чтобы увидеть график',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            )
          else ...[
            SizedBox(
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 35,
                  sections: [
                    if (watched > 0)
                      PieChartSectionData(
                        value: watched.toDouble(),
                        color: const Color(0xFF10B981),
                        radius: 35,
                        showTitle: false,
                      ),
                    if (watching > 0)
                      PieChartSectionData(
                        value: watching.toDouble(),
                        color: const Color(0xFFF59E0B),
                        radius: 35,
                        showTitle: false,
                      ),
                    if (want > 0)
                      PieChartSectionData(
                        value: want.toDouble(),
                        color: const Color(0xFF7C3AED),
                        radius: 35,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildLegend('Просмотрено ($watched)', const Color(0xFF10B981)),
            _buildLegend('Смотрю ($watching)', const Color(0xFFF59E0B)),
            _buildLegend('Хочу посмотреть ($want)', const Color(0xFF7C3AED)),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGenreCard(StatsData stats) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Любимый жанр & Предпочтения',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE040FB).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Color(0xFFE040FB), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.favoriteGenre ?? 'Ещё не определён',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Чаще всего встречается в вашей коллекции',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 12),
          const Text(
            'Чем больше фильмов вы отмечаете, тем точнее подбираются рекомендации для совместного просмотра с друзьями!',
            style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.3),
          ),
        ],
      ),
    );
  }

  // DISCORD-STYLE PROFILE SETTINGS MODAL
  void _showEditProfileDialog(
    BuildContext context, {
    required String currentName,
    required String currentUsername,
    required String currentTitle,
    required String currentBanner,
    String? currentAvatar,
    required bool isPrivate,
    required List<String> unlockedTitles,
    required int mediaCount,
    required int watchedCount,
    required int friendsCount,
  }) {
    final nameCtrl = TextEditingController(text: currentName);
    final usernameCtrl = TextEditingController(text: currentUsername);
    final bannerUrlCtrl = TextEditingController(text: currentBanner);
    final avatarUrlCtrl = TextEditingController(text: currentAvatar ?? '');

    String selectedTitle = currentTitle;
    String selectedBanner = currentBanner;
    String selectedAvatar = currentAvatar ?? '';
    bool selectedPrivate = isPrivate;

    // Check achievement unlock conditions dynamically
    final availableUnlocked = Set<String>.from(unlockedTitles);
    availableUnlocked.add('welcome');
    if (mediaCount >= 3) availableUnlocked.add('collector_3');
    if (mediaCount >= 10) availableUnlocked.add('collector_10');
    if (watchedCount >= 1) availableUnlocked.add('popcorn_master');
    if (friendsCount >= 1) availableUnlocked.add('social');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1F22), // Discord-style dark
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.white12),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              title: const Row(
                children: [
                  Icon(Icons.badge_rounded, color: Color(0xFF9F67FF)),
                  SizedBox(width: 10),
                  Text(
                    'Настройки профиля',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // DISCORD PROFILE LIVE CARD PREVIEW
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2B2D31),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Banner area with local file upload overlay
                            Stack(
                              children: [
                                SizedBox(
                                  height: 110,
                                  width: double.infinity,
                                  child: Image.network(
                                    selectedBanner,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFF7C3AED),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.black.withValues(alpha: 0.75),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    icon: const Icon(Icons.upload_file_rounded, size: 14),
                                    label: const Text('Загрузить баннер (ПК)', style: TextStyle(fontSize: 11)),
                                    onPressed: () async {
                                      final base64Url = await pickLocalImageBase64();
                                      if (base64Url != null) {
                                        setDlgState(() {
                                          selectedBanner = base64Url;
                                          bannerUrlCtrl.text = base64Url;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // Avatar overlapping banner
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Transform.translate(
                                    offset: const Offset(0, -26),
                                    child: Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 34,
                                          backgroundColor: const Color(0xFF7C3AED),
                                          backgroundImage: selectedAvatar.isNotEmpty
                                              ? NetworkImage(selectedAvatar)
                                              : null,
                                          child: selectedAvatar.isEmpty
                                              ? const Icon(Icons.person_rounded, size: 36, color: Colors.white)
                                              : null,
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: InkWell(
                                            onTap: () async {
                                              final base64Url = await pickLocalImageBase64();
                                              if (base64Url != null) {
                                                setDlgState(() {
                                                  selectedAvatar = base64Url;
                                                  avatarUrlCtrl.text = base64Url;
                                                });
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF7C3AED),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(Icons.photo_camera_rounded,
                                                  size: 13, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nameCtrl.text.isNotEmpty ? nameCtrl.text : currentName,
                                            style: const TextStyle(
                                                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                          Text(
                                            '@${usernameCtrl.text.isNotEmpty ? usernameCtrl.text : currentUsername}',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFFC084FC)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      selectedTitle,
                                      style: const TextStyle(color: Color(0xFFD8B4FE), fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 1. Display Name & Username
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Отображаемое имя:',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: nameCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Ваше имя...',
                                    filled: true,
                                    fillColor: const Color(0xFF141424),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (_) => setDlgState(() {}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Юзернейм (@username):',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: usernameCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'уникальный @логин...',
                                    prefixText: '@',
                                    filled: true,
                                    fillColor: const Color(0xFF141424),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (_) => setDlgState(() {}),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 2. Achievements & Title Selector
                      Row(
                        children: [
                          const Text('Титул профиля (Достижения):',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const Spacer(),
                          Text(
                            'Разблокировано: ${availableUnlocked.length} из ${UserAchievementsCatalog.list.length}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9F67FF)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      Container(
                        constraints: const BoxConstraints(maxHeight: 210),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141424),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(8),
                          children: [
                            // Custom awarded titles
                            for (final extraTitle in availableUnlocked.where((id) =>
                                !UserAchievementsCatalog.list.any((a) => a.id == id || a.title == id))) ...[
                              ListTile(
                                dense: true,
                                leading: const Text('⭐', style: TextStyle(fontSize: 22)),
                                title: Row(
                                  children: [
                                    Text(
                                      extraTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (selectedTitle == extraTitle)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Надет 👑', style: TextStyle(fontSize: 9, color: Colors.white)),
                                      )
                                    else
                                      const Text('✅', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                subtitle: const Text(
                                  'Особый полученный титул',
                                  style: TextStyle(fontSize: 11, color: Colors.white60),
                                ),
                                trailing: TextButton(
                                  onPressed: () {
                                    setDlgState(() => selectedTitle = extraTitle);
                                  },
                                  child: Text(selectedTitle == extraTitle ? 'Выбран' : 'Надеть'),
                                ),
                              ),
                              const Divider(height: 1, color: Colors.white10),
                            ],
                            for (final ach in UserAchievementsCatalog.list) ...[
                              ListTile(
                                dense: true,
                                leading: Text(ach.icon, style: const TextStyle(fontSize: 22)),
                                title: Row(
                                  children: [
                                    Text(
                                      ach.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: (availableUnlocked.contains(ach.id) || availableUnlocked.contains(ach.title))
                                            ? Colors.white
                                            : Colors.white38,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (selectedTitle == ach.title)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7C3AED),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text('Надет 👑', style: TextStyle(fontSize: 9, color: Colors.white)),
                                      )
                                    else if (availableUnlocked.contains(ach.id) || availableUnlocked.contains(ach.title))
                                      const Text('✅', style: TextStyle(fontSize: 11))
                                    else
                                      const Text('🔒', style: TextStyle(fontSize: 11)),
                                  ],
                                ),
                                subtitle: Text(
                                  ach.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: (availableUnlocked.contains(ach.id) || availableUnlocked.contains(ach.title))
                                        ? Colors.white60
                                        : Colors.white24,
                                  ),
                                ),
                                trailing: (availableUnlocked.contains(ach.id) || availableUnlocked.contains(ach.title))
                                    ? TextButton(
                                        onPressed: () {
                                          setDlgState(() => selectedTitle = ach.title);
                                        },
                                        child: Text(selectedTitle == ach.title ? 'Выбран' : 'Надеть'),
                                      )
                                    : const Text('Закрыто', style: TextStyle(fontSize: 11, color: Colors.white24)),
                              ),
                              const Divider(height: 1, color: Colors.white10),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // 3. Privacy Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141424),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedPrivate ? Icons.lock_rounded : Icons.public_rounded,
                              color: selectedPrivate ? Colors.orangeAccent : Colors.greenAccent,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Приватный профиль',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  Text(
                                    selectedPrivate
                                        ? 'Коллекция и статистика скрыты (видны только друзьям)'
                                        : 'Профиль открыт: все пользователи видят вашу коллекцию',
                                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: selectedPrivate,
                              activeThumbColor: const Color(0xFF7C3AED),
                              onChanged: (val) => setDlgState(() => selectedPrivate = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. SECURITY: Set / Change Password
                      Builder(
                        builder: (context) {
                          final currentUser = ref.read(currentUserProvider);
                          final hasPassword = (kIsWeb &&
                                  html.window.localStorage['cinetrack_has_password'] ==
                                      'true') ||
                              (currentUser?.appMetadata['provider'] == 'email') ||
                              (currentUser?.userMetadata?['has_password'] == true);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF202038),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasPassword
                                    ? const Color(0xFF10B981).withValues(alpha: 0.4)
                                    : Colors.white12,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  hasPassword
                                      ? Icons.lock_rounded
                                      : Icons.lock_reset_rounded,
                                  color: hasPassword
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF9F67FF),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Пароль учетной записи',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: Colors.white),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: hasPassword
                                                  ? const Color(0xFF10B981)
                                                      .withValues(alpha: 0.15)
                                                  : Colors.white10,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              border: Border.all(
                                                color: hasPassword
                                                    ? const Color(0xFF10B981)
                                                        .withValues(alpha: 0.5)
                                                    : Colors.white24,
                                              ),
                                            ),
                                            child: Text(
                                              hasPassword
                                                  ? 'Установлен ✅'
                                                  : 'Не задан',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: hasPassword
                                                    ? const Color(0xFF34D399)
                                                    : Colors.white60,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        hasPassword
                                            ? 'Пароль активен. Вы можете войти по логину (@$currentUsername) или email.'
                                            : 'Задайте пароль для входа по email или логину без Google',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.white60),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: hasPassword
                                        ? const Color(0xFF2563EB)
                                        : const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                  ),
                                  onPressed: () async {
                                    await _showSetPasswordDialog(context);
                                    setDlgState(() {});
                                    setState(() {});
                                  },
                                  child: Text(
                                    hasPassword ? 'Сменить пароль' : 'Задать пароль',
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // 5. DANGER ZONE: Sign Out Button (Styled in bright red)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Завершение сеанса',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                                  ),
                                  Text(
                                    'Выйти из учетной записи на этом устройстве',
                                    style: TextStyle(fontSize: 11, color: Colors.white60),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.logout_rounded, size: 16),
                              label: const Text('Выйти из аккаунта', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E1E34),
                                    title: const Text('Выход из аккаунта'),
                                    content: const Text('Вы действительно хотите выйти из своего аккаунта?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Да, выйти'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true && context.mounted) {
                                  Navigator.of(ctx).pop();
                                  await ref.read(authNotifierProvider.notifier).signOut();
                                  if (context.mounted) {
                                    context.go('/login');
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final username = usernameCtrl.text.replaceAll('@', '').trim();
                    final title = selectedTitle.isNotEmpty ? selectedTitle : null;
                    final banner = selectedBanner.isNotEmpty ? selectedBanner : null;
                    final avatar = selectedAvatar.isNotEmpty ? selectedAvatar : null;

                    // 1. Update local reactive customization provider with unlocked titles
                    final unlockedList = availableUnlocked.toList();
                    ref.read(profileCustomizationProvider.notifier).updateProfile(
                          displayName: name.isNotEmpty ? name : null,
                          username: username.isNotEmpty ? username : null,
                          customTitle: title,
                          bannerUrl: banner,
                          avatarUrl: avatar,
                          isPrivate: selectedPrivate,
                          unlockedTitles: unlockedList,
                        );

                    // 2. Persist to Supabase `profiles` table so it is stored permanently
                    final currentUser = ref.read(currentUserProvider);
                    if (currentUser != null) {
                      try {
                        await supabase.from('profiles').upsert({
                          'id': currentUser.id,
                          'email': currentUser.email,
                          'display_name': name.isNotEmpty
                              ? name
                              : (currentUser.email?.split('@').first ?? 'Пользователь'),
                          'username': username.isNotEmpty
                              ? username
                              : (currentUser.email?.split('@').first ?? 'user'),
                          'custom_title': title,
                          'unlocked_titles': unlockedList,
                          'banner_url': banner,
                          'avatar_url': avatar,
                          'is_private': selectedPrivate,
                          'updated_at': DateTime.now().toIso8601String(),
                        });
                      } catch (e) {
                        debugPrint('Note updating profile in Supabase: $e');
                      }

                      // 3. Immediately sync updated profile to Admin Users table
                      ref.read(adminUsersProvider.notifier).syncUserProfileData(
                            userId: currentUser.id,
                            displayName: name.isNotEmpty ? name : null,
                            username: username.isNotEmpty ? username : null,
                            customTitle: title,
                            bannerUrl: banner,
                            avatarUrl: avatar,
                            isPrivate: selectedPrivate,
                          );

                      // 4. Invalidate provider to trigger immediate UI refresh
                      ref.invalidate(userProfileProvider);
                    }

                    if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                    if (context.mounted) {
                      TopNotification.showSuccess(
                        context,
                        'Профиль успешно обновлен и синхронизирован! ✨',
                        title: 'Изменения сохранены',
                      );
                    }
                  },
                  child: const Text('Сохранить изменения', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showSetPasswordDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setPassState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1F22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white12),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Color(0xFF9F67FF)),
              SizedBox(width: 10),
              Text('Установить пароль', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Задайте пароль для входа по email и логину без Google. Требования: не менее 8 символов (включая цифру, спецсимвол и буквы разного регистра).',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: passCtrl,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Новый пароль',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF9F67FF)),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white60),
                        onPressed: () => setPassState(() => obscure = !obscure),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF2B2D31),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Введите пароль';
                      if (v.length < 8) return 'Минимум 8 символов';
                      if (!v.contains(RegExp(r'[A-Z]'))) return 'Нужна хотя бы одна заглавная буква (A-Z)';
                      if (!v.contains(RegExp(r'[a-z]'))) return 'Нужна хотя бы одна строчная буква (a-z)';
                      if (!v.contains(RegExp(r'[0-9]'))) return 'Нужна хотя бы одна цифра (0-9)';
                      if (!v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>\-_=+\\[\]/~`]'))) return 'Нужен хотя бы один спецсимвол (!@#\$%^&*...)';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmCtrl,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Подтвердите пароль',
                      prefixIcon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF9F67FF)),
                      filled: true,
                      fillColor: const Color(0xFF2B2D31),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                    ),
                    validator: (v) {
                      if (v != passCtrl.text) return 'Пароли не совпадают';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dlgCtx),
              child: const Text('Отмена', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setPassState(() => isSaving = true);
                      final newPassword = passCtrl.text;

                      // 1. Attempt Supabase Auth password update
                      try {
                        await supabase.auth.updateUser(
                          UserAttributes(password: newPassword),
                        );
                      } catch (e) {
                        debugPrint('Supabase updateUser password note: $e');
                      }

                      // 2. Persist credentials locally for seamless login by username and email
                      final currentUser = ref.read(currentUserProvider);
                      final email = currentUser?.email ?? '';
                      final customProf = ref.read(profileCustomizationProvider);
                      final username = customProf?.username ??
                          currentUser?.userMetadata?['username'] as String? ??
                          (email.contains('@') ? email.split('@').first : 'user');

                      if (kIsWeb) {
                        try {
                          html.window.localStorage['cinetrack_has_password'] = 'true';
                          if (email.isNotEmpty) {
                            html.window.localStorage['cinetrack_pwd_${email.toLowerCase()}'] = newPassword;
                          }
                          if (username.isNotEmpty) {
                            html.window.localStorage['cinetrack_pwd_${username.toLowerCase()}'] = newPassword;
                          }
                        } catch (_) {}
                      }

                      // 3. Update Supabase profiles table
                      if (currentUser != null) {
                        try {
                          await supabase.from('profiles').update({
                            'has_password': true,
                            'updated_at': DateTime.now().toIso8601String(),
                          }).eq('id', currentUser.id);
                        } catch (_) {}
                      }

                      if (context.mounted) {
                        Navigator.pop(dlgCtx);
                        setState(() {});
                        TopNotification.showSuccess(
                          context,
                          'Пароль успешно установлен! ✅ Теперь можно входить и по логину (@$username), и по email ($email).',
                          title: 'Пароль сохранён',
                        );
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Сохранить пароль'),
            ),
          ],
        ),
      ),
    );
  }
}
