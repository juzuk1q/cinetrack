import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/user_profile.dart';
import '../../models/watch_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/top_notification.dart';

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchUserCtrl = TextEditingController();
  final _secretCodeCtrl = TextEditingController();
  String _userSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchUserCtrl.dispose();
    _secretCodeCtrl.dispose();
    super.dispose();
  }

  // Manage Titles & Badges Dialog
  void _showManageTitlesDialog(UserProfile targetUser) {
    final titleCtrl = TextEditingController(text: targetUser.customTitle ?? '');
    final currentUnlocked = List<String>.from(targetUser.unlockedTitles);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E34),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.military_tech_rounded, color: Color(0xFFD8B4FE), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Титулы и плюшки: ${targetUser.displayName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Пользователь: @${targetUser.handle} (${targetUser.email})',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Активный отображаемый титул:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      hintText: 'Введите любой титул (например: Кинокритик 👑, VIP 💎)...',
                      filled: true,
                      fillColor: const Color(0xFF141424),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      suffixIcon: titleCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                titleCtrl.clear();
                                setDlgState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Быстрый выбор из каталога достижений CineTrack:',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: UserAchievementsCatalog.list.map((ach) {
                      final isSelected = titleCtrl.text.trim() == ach.title;
                      return ActionChip(
                        avatar: Text(ach.icon, style: const TextStyle(fontSize: 14)),
                        label: Text(
                          ach.title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                        backgroundColor: isSelected
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF141424),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF9F67FF) : Colors.white12,
                        ),
                        onPressed: () {
                          setDlgState(() => titleCtrl.text = ach.title);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 10),
                  const Text(
                    'Разблокированные награды & перки профиля:',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141424),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(6),
                      itemCount: UserAchievementsCatalog.list.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                      itemBuilder: (context, idx) {
                        final ach = UserAchievementsCatalog.list[idx];
                        final hasPerk = currentUnlocked.contains(ach.id);
                        return CheckboxListTile(
                          dense: true,
                          value: hasPerk,
                          activeColor: const Color(0xFF7C3AED),
                          title: Row(
                            children: [
                              Text(ach.icon, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  ach.title,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            ach.description,
                            style: const TextStyle(fontSize: 10, color: Colors.white54),
                          ),
                          onChanged: (val) {
                            setDlgState(() {
                              if (val == true) {
                                if (!currentUnlocked.contains(ach.id)) {
                                  currentUnlocked.add(ach.id);
                                }
                              } else {
                                currentUnlocked.remove(ach.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
              onPressed: () async {
                final newTitle = titleCtrl.text.trim();
                Navigator.of(ctx, rootNavigator: true).pop();

                await ref.read(adminUsersProvider.notifier).updateUserTitle(
                      targetUser.id,
                      newTitle.isNotEmpty ? newTitle : null,
                      unlockedTitles: currentUnlocked,
                    );

                if (!mounted) return;
                TopNotification.showSuccess(
                  context,
                  'Титул «${newTitle.isNotEmpty ? newTitle : "Сброшен"}» успешно сохранен для ${targetUser.displayName} ✨',
                  title: 'Титул обновлен',
                );
              },
              child: const Text('Сохранить титул & плюшки'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockFreezeDialog(UserProfile targetUser) {
    bool isFreeze = true;
    int freezeDays = 7;
    final reasonCtrl = TextEditingController(text: 'Нарушение правил сообщества CineTrack');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E34),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                isFreeze ? Icons.ac_unit_rounded : Icons.block_rounded,
                color: isFreeze ? const Color(0xFF38BDF8) : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 10),
              Text(isFreeze ? 'Заморозка аккаунта' : 'Блокировка аккаунта'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Пользователь: ${targetUser.displayName} (@${targetUser.handle})',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  targetUser.email,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                const Text('Тип ограничения:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.ac_unit_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Заморозка ❄️'),
                          ],
                        ),
                        selected: isFreeze,
                        selectedColor: const Color(0xFF0284C7).withValues(alpha: 0.35),
                        onSelected: (val) {
                          if (val) setDlgState(() => isFreeze = true);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ChoiceChip(
                        label: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.block_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Блокировка 🚫'),
                          ],
                        ),
                        selected: !isFreeze,
                        selectedColor: const Color(0xFFDC2626).withValues(alpha: 0.35),
                        onSelected: (val) {
                          if (val) setDlgState(() => isFreeze = false);
                        },
                      ),
                    ),
                  ],
                ),
                if (isFreeze) ...[
                  const SizedBox(height: 14),
                  const Text('Срок заморозки:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('1 день'),
                        selected: freezeDays == 1,
                        onSelected: (val) => setDlgState(() => freezeDays = 1),
                      ),
                      ChoiceChip(
                        label: const Text('7 дней'),
                        selected: freezeDays == 7,
                        onSelected: (val) => setDlgState(() => freezeDays = 7),
                      ),
                      ChoiceChip(
                        label: const Text('30 дней'),
                        selected: freezeDays == 30,
                        onSelected: (val) => setDlgState(() => freezeDays = 30),
                      ),
                      ChoiceChip(
                        label: const Text('Бессрочно'),
                        selected: freezeDays == 0,
                        onSelected: (val) => setDlgState(() => freezeDays = 0),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Причина ограничения:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Укажите причину (спам, оскорбления, запрещенный контент)...',
                    fillColor: const Color(0xFF141424),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isFreeze ? const Color(0xFF0284C7) : const Color(0xFFEF4444),
              ),
              onPressed: () async {
                final reason = reasonCtrl.text.trim().isEmpty
                    ? 'Нарушение правил платформы'
                    : reasonCtrl.text.trim();
                final duration = (isFreeze && freezeDays > 0)
                    ? Duration(days: freezeDays)
                    : null;

                Navigator.of(ctx, rootNavigator: true).pop();
                await ref.read(adminUsersProvider.notifier).blockOrFreezeUser(
                      targetUser.id,
                      isFreeze: isFreeze,
                      reason: reason,
                      duration: duration,
                    );

                if (!mounted) return;
                TopNotification.showWarning(
                  context,
                  isFreeze
                      ? 'Аккаунт «${targetUser.displayName}» заморожен'
                      : 'Аккаунт «${targetUser.displayName}» заблокирован',
                  title: isFreeze ? 'Заморозка аккаунта ❄️' : 'Блокировка аккаунта 🚫',
                );
              },
              child: Text(isFreeze ? 'Заморозить' : 'Заблокировать'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Column(
        children: [
          const AppHeader(activeRoute: '/admin'),
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: true,
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded,
                            color: Color(0xFFF59E0B), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Панель управления (Админ-центр)',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Синхронизировать пользователей и комнаты с базой данных Supabase',
                      onPressed: () {
                        ref.read(adminUsersProvider.notifier).refresh();
                        ref.invalidate(roomsProvider);
                        ref.invalidate(userProfileProvider);
                        TopNotification.showSuccess(
                          context,
                          'Списки пользователей и комнат обновлены',
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                  ],
                  bottom: TabBar(
                    controller: _tabController,
                    indicatorColor: const Color(0xFF7C3AED),
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.people_alt_rounded, size: 20),
                        text: 'Пользователи & Права',
                      ),
                      Tab(
                        icon: Icon(Icons.meeting_room_rounded, size: 20),
                        text: 'Все комнаты (Модерация)',
                      ),
                    ],
                  ),
                ),
              ],
              body: !isAdmin
                  ? _buildAccessDeniedPlaceholder()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildUsersTab(),
                        _buildRoomsTab(),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedPlaceholder() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(32),
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
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded,
                  size: 42, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 20),
            const Text(
              'Требуются права Администратора',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            const Text(
              'Для входа в панель управления ваш аккаунт должен иметь роль «admin». '
              'Вы можете мгновенно активировать права, введя мастер-ключ.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              ),
              icon: const Icon(Icons.home_rounded, size: 18),
              label: const Text('Вернуться на главную'),
              onPressed: () => context.go('/'),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: USERS & PERMISSIONS
  Widget _buildUsersTab() {
    final profiles = ref.watch(adminUsersProvider);
    final currentUser = ref.watch(currentUserProvider);
    final userProfileAsync = ref.watch(userProfileProvider);

    final currentActor = userProfileAsync.value ??
        profiles.firstWhere(
          (p) =>
              p.id == currentUser?.id ||
              (p.email.isNotEmpty &&
                  currentUser?.email != null &&
                  p.email.toLowerCase() == currentUser!.email!.toLowerCase()),
          orElse: () => UserProfile(
            id: currentUser?.id ?? 'u_current',
            email: currentUser?.email ?? '',
            displayName: 'Вы',
            createdAt: DateTime.now(),
            role: 'creator',
          ),
        );

    final filtered = profiles.where((p) {
      if (_userSearchQuery.isEmpty) return true;
      final q = _userSearchQuery.toLowerCase();
      return p.email.toLowerCase().contains(q) ||
          p.displayName.toLowerCase().contains(q) ||
          p.handle.toLowerCase().contains(q) ||
          p.role.toLowerCase().contains(q) ||
          (p.customTitle != null && p.customTitle!.toLowerCase().contains(q));
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search & summary bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchUserCtrl,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Поиск пользователя по email, юзернейму, имени или титулу...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchUserCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchUserCtrl.clear();
                              setState(() => _userSearchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) =>
                      setState(() => _userSearchQuery = val.trim()),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E34),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt_rounded, size: 16, color: Color(0xFF9F67FF)),
                    const SizedBox(width: 8),
                    Text(
                      'Всего участников: ${profiles.length}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Users table / list
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text('Пользователи не найдены',
                        style: TextStyle(color: Colors.white54)),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final user = filtered[i];
                      return _buildUserCard(user, currentActor, currentUser);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    UserProfile user,
    UserProfile currentActor,
    User? currentUser,
  ) {
    final isSelf = user.id == currentUser?.id ||
        (user.email.isNotEmpty &&
            currentUser?.email != null &&
            user.email.toLowerCase() == currentUser!.email!.toLowerCase());

    final canManage = currentActor.canManage(user);
    final isRestricted = user.isRestricted;

    Color badgeBg;
    Color badgeText;
    Color badgeBorder;

    switch (user.role) {
      case 'creator':
        badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.25);
        badgeText = const Color(0xFFFBBF24);
        badgeBorder = const Color(0xFFF59E0B).withValues(alpha: 0.6);
        break;
      case 'developer':
      case 'coder':
        badgeBg = const Color(0xFF06B6D4).withValues(alpha: 0.25);
        badgeText = const Color(0xFF22D3EE);
        badgeBorder = const Color(0xFF06B6D4).withValues(alpha: 0.6);
        break;
      case 'admin':
        badgeBg = const Color(0xFFEAB308).withValues(alpha: 0.25);
        badgeText = const Color(0xFFFDE047);
        badgeBorder = const Color(0xFFEAB308).withValues(alpha: 0.6);
        break;
      case 'moderator':
        badgeBg = const Color(0xFF6366F1).withValues(alpha: 0.25);
        badgeText = const Color(0xFFA5B4FC);
        badgeBorder = const Color(0xFF6366F1).withValues(alpha: 0.6);
        break;
      case 'user':
      default:
        badgeBg = Colors.white10;
        badgeText = Colors.white70;
        badgeBorder = Colors.white24;
        break;
    }

    return Card(
      color: const Color(0xFF16162A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelf
              ? const Color(0xFF7C3AED).withValues(alpha: 0.8)
              : (user.isBlocked
                  ? const Color(0xFFEF4444).withValues(alpha: 0.6)
                  : (user.isCurrentlyFrozen
                      ? const Color(0xFF38BDF8).withValues(alpha: 0.6)
                      : (user.role == 'creator'
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                          : Colors.white10))),
          width: isSelf ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            // User Avatar (clickable to view public profile)
            Tooltip(
              message: 'Открыть профиль @${user.handle}',
              child: InkWell(
                onTap: () => context.go('/user/${user.handle}'),
                borderRadius: BorderRadius.circular(24),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: user.isBlocked
                      ? const Color(0xFFEF4444)
                      : (user.role == 'creator'
                          ? const Color(0xFFF59E0B)
                          : (user.role == 'admin'
                              ? const Color(0xFFEAB308)
                              : const Color(0xFF7C3AED))),
                  backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child: (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                      ? Text(
                          user.displayName.isNotEmpty
                              ? user.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // User Info (Name, Username, Role Badge, Title, Email)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => context.go('/user/${user.handle}'),
                        child: Text(
                          user.displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '@${user.handle}',
                        style: const TextStyle(
                            color: Color(0xFFC084FC), fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),

                      // System Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeBorder, width: 0.8),
                        ),
                        child: Text(
                          user.fullRoleTitle,
                          style: TextStyle(
                            color: badgeText,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      // "You" badge indicator
                      if (isSelf) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF9F67FF)),
                          ),
                          child: const Text(
                            'ВЫ',
                            style: TextStyle(
                              color: Color(0xFFD8B4FE),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),

                  Row(
                    children: [
                      Text(
                        user.email,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      const SizedBox(width: 10),

                      // Title / Badge display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E1065).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFF9F67FF).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          user.effectiveTitle,
                          style: const TextStyle(
                              color: Color(0xFFE9D5FF), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),

                  // Ban / Freeze notice banner
                  if (user.isBlocked)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '🚫 Заблокирован бессрочно: ${user.blockReason ?? "Нарушение правил"}',
                          style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                  else if (user.isCurrentlyFrozen)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '❄️ Заморожен до ${user.blockUntil != null ? "${user.blockUntil!.day.toString().padLeft(2, '0')}.${user.blockUntil!.month.toString().padLeft(2, '0')}.${user.blockUntil!.year}" : "срока"}: ${user.blockReason ?? "Нарушение правил"}',
                          style: const TextStyle(color: Color(0xFF7DD3FC), fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // 1. Grant Titles & Perks Button
            Tooltip(
              message: canManage || isSelf
                  ? 'Выдать титул или плюшки 🎁'
                  : 'Недостаточно прав для выдачи титулов этому рангу',
              child: IconButton(
                icon: const Icon(Icons.card_giftcard_rounded, size: 20),
                color: (canManage || isSelf) ? const Color(0xFFD8B4FE) : Colors.white24,
                onPressed: (canManage || isSelf)
                    ? () => _showManageTitlesDialog(user)
                    : null,
              ),
            ),
            const SizedBox(width: 6),

            // 2. Role Selector (Strict Hierarchy Protection)
            if (isSelf)
              Tooltip(
                message: 'Ваш текущий ранг (защита от изменения собственной роли)',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E34),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user.fullRoleTitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(width: 4),
                      const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF9F67FF)),
                    ],
                  ),
                ),
              )
            else if (!canManage)
              Tooltip(
                message: 'Ранг равен или выше вашего. Управление недоступно по иерархии.',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E34),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(user.fullRoleTitle, style: const TextStyle(fontSize: 12, color: Colors.white38)),
                      const SizedBox(width: 4),
                      const Icon(Icons.lock_rounded, size: 13, color: Colors.white38),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E34),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF9F67FF).withValues(alpha: 0.4)),
                ),
                child: DropdownButton<String>(
                  value: currentActor.assignableRoles.contains(user.role)
                      ? user.role
                      : currentActor.assignableRoles.first,
                  underline: const SizedBox(),
                  dropdownColor: const Color(0xFF1E1E34),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF9F67FF)),
                  items: currentActor.assignableRoles.map((r) {
                    Color itemColor = Colors.white;
                    if (r == 'creator') itemColor = const Color(0xFFFBBF24);
                    if (r == 'developer') itemColor = const Color(0xFF22D3EE);
                    if (r == 'admin') itemColor = const Color(0xFFFDE047);
                    if (r == 'moderator') itemColor = const Color(0xFFA5B4FC);

                    final dummy = UserProfile(
                      id: '',
                      email: '',
                      displayName: '',
                      createdAt: DateTime.now(),
                      role: r,
                    );

                    return DropdownMenuItem(
                      value: r,
                      child: Text(
                        dummy.fullRoleTitle,
                        style: TextStyle(fontSize: 12, color: itemColor, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (newRole) async {
                    if (newRole == null || newRole == user.role) return;
                    final success =
                        await ref.read(adminUsersProvider.notifier).updateRole(user.id, newRole);
                    if (mounted) {
                      if (success) {
                        TopNotification.showSuccess(
                          context,
                          'Роль для «${user.displayName}» изменена на $newRole',
                          title: 'Роль обновлена',
                        );
                      } else {
                        TopNotification.showError(
                          context,
                          'Не удалось обновить роль пользователя',
                        );
                      }
                    }
                  },
                ),
              ),
            const SizedBox(width: 10),

            // 3. Block / Freeze Button (Self-Ban Prevention + Hierarchy Protection)
            if (isSelf)
              Tooltip(
                message: 'Вы не можете заблокировать собственный аккаунт (защита от самобана)',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white24,
                    side: const BorderSide(color: Colors.white12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.block_rounded, size: 14, color: Colors.white24),
                  label: const Text('Блокировка', style: TextStyle(fontSize: 11.5, color: Colors.white24)),
                  onPressed: null,
                ),
              )
            else if (!canManage)
              Tooltip(
                message: 'Нельзя блокировать равных по рангу или вышестоящих участников',
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white24,
                    side: const BorderSide(color: Colors.white12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.shield_outlined, size: 14, color: Colors.white24),
                  label: const Text('Защищен', style: TextStyle(fontSize: 11.5, color: Colors.white24)),
                  onPressed: null,
                ),
              )
            else if (isRestricted)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.lock_open_rounded, size: 15),
                label: const Text('Разблокировать', style: TextStyle(fontSize: 11.5)),
                onPressed: () async {
                  await ref.read(adminUsersProvider.notifier).unblockUser(user.id);
                  if (mounted) {
                    TopNotification.showSuccess(
                      context,
                      'Ограничения для ${user.displayName} сняты. Аккаунт активен.',
                      title: 'Разблокировано',
                    );
                  }
                },
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444), width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.gavel_rounded, size: 14),
                label: const Text('Блокировка', style: TextStyle(fontSize: 11.5)),
                onPressed: () => _showBlockFreezeDialog(user),
              ),
            const SizedBox(width: 8),

            // 4. Open User Profile in Public View
            Tooltip(
              message: 'Открыть профиль @${user.handle}',
              child: IconButton(
                icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white70),
                onPressed: () => context.go('/user/${user.handle}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 2: ROOMS MODERATION
  Widget _buildRoomsTab() {
    final allRooms = ref.watch(roomsProvider);

    if (allRooms.isEmpty) {
      return const Center(
        child: Text('На платформе пока нет созданных комнат',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Активные комнаты на сервере (${allRooms.length})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              const Text(
                'Администратор может подключиться к любой комнате или удалить её',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: allRooms.length,
              itemBuilder: (context, i) {
                final room = allRooms[i];
                return _buildRoomModerationCard(room);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomModerationCard(WatchRoom room) {
    return Card(
      color: const Color(0xFF16162A),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tv_rounded, color: Color(0xFFC084FC)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        room.title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (room.password != null && room.password!.isNotEmpty)
                              ? Colors.orange.withValues(alpha: 0.2)
                              : Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (room.password != null && room.password!.isNotEmpty)
                              ? 'С паролем 🔒'
                              : 'Открытая 🌐',
                          style: TextStyle(
                            color: (room.password != null && room.password!.isNotEmpty)
                                ? Colors.orangeAccent
                                : Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Создатель: ${room.ownerName} • Участников: ${room.participantCount} / ${room.maxParticipants == null || room.maxParticipants == 0 ? "∞" : room.maxParticipants.toString()}',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Join room button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.login_rounded, size: 16),
              label: const Text('Войти'),
              onPressed: () => context.go('/rooms/${room.id}'),
            ),
            const SizedBox(width: 8),

            // Delete room
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 20),
              tooltip: 'Удалить комнату как Администратор',
              onPressed: () {
                ref.read(roomsProvider.notifier).deleteRoom(room.id);
                TopNotification.showWarning(
                  context,
                  'Комната «${room.title}» удалена администратором',
                  title: 'Комната закрыта',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
