import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../models/room_message.dart';
import '../../models/watch_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/app_sidebar.dart';

class RoomDetailScreen extends ConsumerStatefulWidget {
  final String roomId;
  const RoomDetailScreen({super.key, required this.roomId});

  @override
  ConsumerState<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends ConsumerState<RoomDetailScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage(WatchRoom room) {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final userName = user?.email?.split('@').first ?? 'Я';

    ref.read(roomsProvider.notifier).addMessage(room.id, userName, text);
    _msgCtrl.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(singleRoomProvider(widget.roomId));

    if (room == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Комната не найдена'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/rooms'),
                child: const Text('Назад ко всем комнатам'),
              ),
            ],
          ),
        ),
      );
    }

    final isWatching = room.status == 'watching';

    return Scaffold(
      body: Row(
        children: [
          const AppSidebar(selectedIndex: 2),
          Expanded(
            child: Column(
              children: [
                // Top AppBar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A2E),
                    border: Border(bottom: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => context.go('/rooms'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              room.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            Text(
                              'Фильм: ${room.movieTitle} • Организатор: ${room.ownerName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Status switcher
                      FilterChip(
                        avatar: Text(isWatching ? '🍿' : '⏳'),
                        label: Text(
                          isWatching ? 'Идёт показ' : 'Запланирован',
                          style: TextStyle(
                            color: isWatching
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        selected: isWatching,
                        onSelected: (val) {
                          ref.read(roomsProvider.notifier).updateStatus(
                                room.id,
                                val ? 'watching' : 'preparing',
                              );
                        },
                      ),
                    ],
                  ),
                ),

                // Main Content: Movie Player Launchers + Chat
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 750;
                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Left: Movie Banner & Stream links
                            Expanded(
                              flex: 5,
                              child: _buildMovieInfoPane(context, room),
                            ),
                            const VerticalDivider(width: 1, color: Colors.white12),
                            // Right: Chat
                            Expanded(
                              flex: 4,
                              child: _buildChatPane(context, room),
                            ),
                          ],
                        );
                      } else {
                        // Narrow screen: Tabs
                        return DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              const TabBar(
                                tabs: [
                                  Tab(icon: Icon(Icons.movie_rounded), text: 'Плееры & Фильм'),
                                  Tab(icon: Icon(Icons.chat_bubble_rounded), text: 'Чат комнаты'),
                                ],
                              ),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _buildMovieInfoPane(context, room),
                                    _buildChatPane(context, room),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovieInfoPane(BuildContext context, WatchRoom room) {
    final query = Uri.encodeComponent(
        '${room.movieTitle} ${room.movieYear?.toString() ?? ''}');
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Movie Banner Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E34),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (room.moviePoster != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      room.moviePoster!,
                      width: 90,
                      height: 130,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 90,
                        height: 130,
                        color: Colors.white10,
                        child: const Icon(Icons.movie_rounded, size: 40),
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.movieTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Категория: ${AppConstants.mediaTypes[room.movieType] ?? room.movieType}',
                        style: const TextStyle(color: Color(0xFF9F67FF), fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Время сеанса: ${DateFormat('EEEE, d MMMM, HH:mm', 'ru').format(room.scheduledAt)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.group_rounded,
                              size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Text(
                            'В комнате: ${room.participantCount} зрителей',
                            style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Launch stream player buttons
          const Text(
            'ЗАПУСТИТЬ СОВМЕСТНЫЙ ПРОСМОТР',
            style: TextStyle(
              color: Color(0xFF9F67FF),
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Выберите удобный сервис. Все участники могут открыть плеер одновременно и синхронно смотреть сеанс, общаясь в чате комнаты справа:',
            style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.3),
          ),
          const SizedBox(height: 16),

          // Quick player launchers
          _buildLauncherTile(
            title: 'Смотреть на Lordfilm',
            subtitle: 'Популярный бесплатный плеер со всеми озвучками',
            icon: Icons.movie_filter_rounded,
            color: const Color(0xFFF59E0B),
            url: 'https://yandex.ru/search/?text=${Uri.encodeComponent('lordfilm ${room.movieTitle} ${room.movieYear ?? ''}')}',
          ),
          const SizedBox(height: 10),
          _buildLauncherTile(
            title: 'Смотреть на Кинопоиске',
            subtitle: 'Официальный онлайн-кинотеатр в высоком качестве',
            icon: Icons.play_circle_fill_rounded,
            color: const Color(0xFFFF5500),
            url: 'https://www.kinopoisk.ru/index.php?kp_query=$query',
          ),
          const SizedBox(height: 10),
          _buildLauncherTile(
            title: 'Открыть трейлер на YouTube',
            subtitle: 'Трейлер перед началом просмотра',
            icon: Icons.video_library_rounded,
            color: const Color(0xFFFF0000),
            url: 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('${room.movieTitle} трейлер')}',
          ),
          const SizedBox(height: 10),
          _buildLauncherTile(
            title: 'Искать плеер онлайн (Яндекс / Google)',
            subtitle: 'Альтернативные источники и сайты просмотра',
            icon: Icons.search_rounded,
            color: const Color(0xFF3B82F6),
            url: 'https://yandex.ru/search/?text=${Uri.encodeComponent('${room.movieTitle} смотреть онлайн бесплатно')}',
          ),
        ],
      ),
    );
  }

  Widget _buildLauncherTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String url,
  }) {
    return InkWell(
      onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildChatPane(BuildContext context, WatchRoom room) {
    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E34),
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: const Row(
            children: [
              Icon(Icons.chat_rounded, color: Color(0xFF9F67FF), size: 18),
              SizedBox(width: 8),
              Text(
                'Чат совместного просмотра',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: room.messages.length,
            itemBuilder: (context, i) {
              final msg = room.messages[i];
              return _buildMessageBubble(msg);
            },
          ),
        ),

        // Message input
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            border: Border(top: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Обсудить фильм с друзьями...',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(room),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send_rounded, size: 18),
                onPressed: () => _sendMessage(room),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(RoomMessage msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF7C3AED),
            child: Text(
              msg.userName.isNotEmpty ? msg.userName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      msg.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF9F67FF),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(msg.createdAt),
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252540),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    msg.text,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
