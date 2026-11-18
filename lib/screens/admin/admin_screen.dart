import 'widgets/admin_user_card.dart';

import 'widgets/admin_room_card.dart';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';




import '../../models/user_profile.dart';


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

    super.dispose();

  }



  // Manage Titles & Badges Dialog

  @override

  Widget build(BuildContext context) {

    final isAdmin = ref.watch(isAdminProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;



    return Scaffold(

      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF1F5F9),

      body: Column(

        children: [

          const AppHeader(activeRoute: '/admin'),

          Expanded(

            child: NestedScrollView(

              headerSliverBuilder: (context, innerBoxIsScrolled) => [

                SliverAppBar(

                  pinned: true,

                  backgroundColor: isDark ? const Color(0xFF0F0F1A) : Colors.white,

                  elevation: isDark ? 0 : 1,

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

                      Text(

                        'Панель управления (Админ-центр)',

                        style: TextStyle(

                          fontWeight: FontWeight.w800,

                          fontSize: 18,

                          color: isDark ? Colors.white : const Color(0xFF0F172A),

                        ),

                      ),

                    ],

                  ),

                  actions: [

                    IconButton(

                      icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),

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

                    labelColor: isDark ? Colors.white : const Color(0xFF7C3AED),

                    unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),

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

                  ? _buildAccessDeniedPlaceholder(isDark)

                  : TabBarView(

                      controller: _tabController,

                      children: [

                        _buildUsersTab(isDark),

                        _buildRoomsTab(isDark),

                      ],

                    ),

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildAccessDeniedPlaceholder(bool isDark) {

    return Center(

      child: Container(

        constraints: const BoxConstraints(maxWidth: 480),

        padding: const EdgeInsets.all(32),

        decoration: BoxDecoration(

          color: isDark ? const Color(0xFF16162A) : Colors.white,

          borderRadius: BorderRadius.circular(20),

          border: Border.all(

            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),

          ),

          boxShadow: [

            if (!isDark)

              BoxShadow(

                color: Colors.black.withValues(alpha: 0.05),

                blurRadius: 16,

                offset: const Offset(0, 4),

              ),

          ],

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

            Text(

              'Требуются права Администратора',

              style: TextStyle(

                fontSize: 18,

                fontWeight: FontWeight.w800,

                color: isDark ? Colors.white : const Color(0xFF0F172A),

              ),

            ),

            const SizedBox(height: 10),

            Text(

              'Для входа в панель управления ваш аккаунт должен иметь роль «admin» в базе данных.',

              textAlign: TextAlign.center,

              style: TextStyle(

                color: isDark ? Colors.white70 : const Color(0xFF64748B),

                fontSize: 13,

                height: 1.4,

              ),

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

  Widget _buildUsersTab(bool isDark) {

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

            role: 'admin',

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

                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),

                  decoration: InputDecoration(

                    isDense: true,

                    hintText: 'Поиск пользователя по email, юзернейму, имени или титулу...',

                    hintStyle: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),

                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? Colors.white60 : const Color(0xFF64748B)),

                    filled: true,

                    fillColor: isDark ? const Color(0xFF16162A) : Colors.white,

                    border: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(10),

                      borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),

                    ),

                    enabledBorder: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(10),

                      borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),

                    ),

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

                  color: isDark ? const Color(0xFF1E1E34) : Colors.white,

                  borderRadius: BorderRadius.circular(10),

                  border: Border.all(

                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),

                  ),

                  boxShadow: [

                    if (!isDark)

                      BoxShadow(

                        color: Colors.black.withValues(alpha: 0.04),

                        blurRadius: 8,

                        offset: const Offset(0, 2),

                      ),

                  ],

                ),

                child: Row(

                  children: [

                    const Icon(Icons.people_alt_rounded, size: 16, color: Color(0xFF9F67FF)),

                    const SizedBox(width: 8),

                    Text(

                      'Всего участников: ${profiles.length}',

                      style: TextStyle(

                        fontWeight: FontWeight.w700,

                        fontSize: 13,

                        color: isDark ? Colors.white : const Color(0xFF0F172A),

                      ),

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

                ? Center(

                    child: Text('Пользователи не найдены',

                        style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B))),

                  )

                : ListView.builder(

                    itemCount: filtered.length,

                    itemBuilder: (context, i) {

                      final user = filtered[i];

                      return AdminUserCard(user: user, currentActor: currentActor, currentUser: currentUser, isDark: isDark);

                    },

                  ),

          ),

        ],

      ),

    );

  }



  // TAB 2: ROOMS MODERATION

  Widget _buildRoomsTab(bool isDark) {

    final allRooms = ref.watch(roomsProvider);



    if (allRooms.isEmpty) {

      return Center(

        child: Text('На платформе пока нет созданных комнат',

            style: TextStyle(color: isDark ? Colors.white54 : const Color(0xFF64748B))),

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

                style: TextStyle(

                    fontSize: 16,

                    fontWeight: FontWeight.w700,

                    color: isDark ? Colors.white : const Color(0xFF0F172A)),

              ),

              const Spacer(),

              Text(

                'Администратор может подключиться к любой комнате или удалить её',

                style: TextStyle(

                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),

                    fontSize: 12),

              ),

            ],

          ),

          const SizedBox(height: 16),

          Expanded(

            child: ListView.builder(

              itemCount: allRooms.length,

              itemBuilder: (context, i) {

                final room = allRooms[i];

                return AdminRoomCard(room: room, isDark: isDark);

              },

            ),

          ),

        ],

      ),

    );

  }



}

