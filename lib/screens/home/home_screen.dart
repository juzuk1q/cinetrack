import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/media_item.dart';
import '../../models/watch_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/media_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final rooms = ref.watch(roomsProvider);
    final mediaAsync = ref.watch(mediaListProvider);

    final displayName = user?.email?.split('@').first ?? 'Киноман';
    final liveRooms = rooms.where((r) => r.status == 'watching').toList();
    final upcomingRooms = rooms.where((r) => r.status == 'preparing').toList();

    return Scaffold(
      body: Row(
        children: [
          const AppSidebar(selectedIndex: 0),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Top AppBar
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  pinned: true,
                  floating: true,
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Привет, $displayName! 🍿',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        DateFormat('EEEE, d MMMM', 'ru').format(DateTime.now()),
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Создать комнату'),
                        onPressed: () => context.go('/rooms'),
                      ),
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. Featured Movie Banner
                      _buildFeaturedMovieBanner(context),
                      const SizedBox(height: 32),

                      // 2. Active Watch Rooms ("Смотрят прямо сейчас")
                      _buildSectionHeader(
                        context,
                        title: 'Смотрят прямо сейчас с друзьями',
                        subtitle: 'Подключайтесь к синхронному показу с живым чатом',
                        icon: Icons.live_tv_rounded,
                        color: const Color(0xFF10B981),
                        actionLabel: 'Все комнаты (${rooms.length})',
                        onAction: () => context.go('/rooms'),
                      ),
                      const SizedBox(height: 14),
                      if (liveRooms.isEmpty)
                        _buildEmptyRoomCard(context)
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossCount =
                                constraints.maxWidth > 800 ? 2 : 1;
                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 2.1,
                              ),
                              itemCount: liveRooms.length,
                              itemBuilder: (context, i) =>
                                  _buildLiveRoomCard(context, liveRooms[i]),
                            );
                          },
                        ),
                      const SizedBox(height: 32),

                      // 3. Upcoming Group Screenings ("С кем и когда посмотреть")
                      _buildSectionHeader(
                        context,
                        title: 'Запланированные совместные показы',
                        subtitle: 'С кем и когда можно посмотреть кино',
                        icon: Icons.calendar_today_rounded,
                        color: const Color(0xFF9F67FF),
                        actionLabel: '+ Запланировать',
                        onAction: () => context.go('/rooms'),
                      ),
                      const SizedBox(height: 14),
                      _buildUpcomingRoomsList(context, upcomingRooms),
                      const SizedBox(height: 32),

                      // 4. Continue Watching / User's Queue
                      _buildSectionHeader(
                        context,
                        title: 'Моя коллекция & Очередь просмотра',
                        subtitle: 'Фильмы, которые вы планировали посмотреть',
                        icon: Icons.bookmark_added_rounded,
                        color: const Color(0xFFF59E0B),
                        actionLabel: 'Вся библиотека',
                        onAction: () => context.go('/library'),
                      ),
                      const SizedBox(height: 14),
                      mediaAsync.when(
                        data: (items) =>
                            _buildUserQueue(context, items.take(4).toList()),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Text('Ошибка загрузки: $e'),
                      ),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedMovieBanner(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF3B1D7A), Color(0xFF160E29)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=600&auto=format&fit=crop&q=80',
                    width: 100,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.movie_rounded,
                        size: 50,
                        color: Colors.white24),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE040FB).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFFE040FB), width: 0.8),
                        ),
                        child: const Text(
                          'РЕКОМЕНДАЦИЯ ДНЯ',
                          style: TextStyle(
                            color: Color(0xFFE040FB),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Интерстеллар (2014)',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Фантастика • Драма • Кристофер Нолан • 8.7 ★',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                            ),
                            icon: const Icon(Icons.groups_rounded, size: 16),
                            label: const Text('Смотреть с друзьями 🍿'),
                            onPressed: () => context.go('/rooms'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFF59E0B)),
                            ),
                            icon: const Icon(Icons.movie_filter_rounded,
                                size: 16, color: Color(0xFFF59E0B)),
                            label: const Text('Смотреть на Lordfilm',
                                style: TextStyle(color: Color(0xFFF59E0B))),
                            onPressed: () {
                              launchUrl(
                                Uri.parse('https://yandex.ru/search/?text=${Uri.encodeComponent('lordfilm Интерстеллар 2014')}'),
                                mode: LaunchMode.platformDefault,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(actionLabel,
              style: const TextStyle(color: Color(0xFF9F67FF), fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildLiveRoomCard(BuildContext context, WatchRoom room) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.2),
      ),
      child: Row(
        children: [
          if (room.moviePoster != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                room.moviePoster!,
                width: 55,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 55,
                  height: 80,
                  color: Colors.white10,
                  child: const Icon(Icons.movie_rounded),
                ),
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fiber_manual_record_rounded,
                              size: 8, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text('Смотрят сейчас 🍿',
                              style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text('Зрителей: ${room.participantCount}',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  room.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  'Фильм: ${room.movieTitle} • С кем: ${room.ownerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 14),
                  label: const Text('Войти в комнату',
                      style: TextStyle(fontSize: 11)),
                  onPressed: () => context.go('/rooms/${room.id}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRoomCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.groups_rounded, size: 36, color: Colors.white24),
            const SizedBox(height: 8),
            const Text('Сейчас нет активных показов',
                style: TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Создать первую комнату для друзей'),
              onPressed: () => context.go('/rooms'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingRoomsList(
      BuildContext context, List<WatchRoom> rooms) {
    if (rooms.isEmpty) {
      return const Text('Запланированных показов пока нет',
          style: TextStyle(color: Colors.white38));
    }
    return Column(
      children: rooms.map((room) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E34),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  color: Color(0xFF9F67FF), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    Text(
                      'Фильм: ${room.movieTitle} • С кем: ${room.ownerName} • ${DateFormat('d MMMM, HH:mm', 'ru').format(room.scheduledAt)}',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF252540),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Text('Подключиться',
                    style: TextStyle(fontSize: 11)),
                onPressed: () => context.go('/rooms/${room.id}'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUserQueue(BuildContext context, List<MediaItem> items) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E34),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Center(
          child: Column(
            children: [
              const Text('В вашей личной очереди пока пусто',
                  style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.search_rounded),
                label: const Text('Выбрать фильм в библиотеке'),
                onPressed: () => context.go('/library'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            childAspectRatio: 0.65,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => MediaCard(item: items[i]),
        );
      },
    );
  }
}
