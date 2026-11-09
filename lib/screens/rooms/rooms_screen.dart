import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/watch_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/app_header.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  String _filter = 'all'; // 'all', 'watching', 'preparing'

  void _confirmDeleteRoom(BuildContext context, WatchRoom room) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E34),
        title: const Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Удалить комнату?'),
          ],
        ),
        content: Text(
          'Вы уверены, что хотите удалить «${room.title}»?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(roomsProvider.notifier).deleteRoom(room.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Комната «${room.title}» удалена')),
              );
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateRoomDialog() {
    final titleCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool isPasswordObscured = true;
    int? maxUsers;
    double sliderVal = 50.0;
    final limitTextCtrl = TextEditingController(text: '∞');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.groups_rounded, color: Color(0xFF7C3AED)),
                  SizedBox(width: 10),
                  Text('Создать комнату просмотра'),
                ],
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Приглашайте друзей к совместному просмотру. Видеоисточник (фильм из каталога, VK Видео, прямая ссылка или файл) вы выберете внутри комнаты!',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 18),

                      // Room Title
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Название комнаты *',
                          hintText: 'Например, «Киновечер с друзьями»',
                          prefixIcon: Icon(Icons.meeting_room_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Room Password (optional)
                      TextField(
                        controller: passwordCtrl,
                        obscureText: isPasswordObscured,
                        decoration: InputDecoration(
                          labelText: 'Пароль для входа (необязательно)',
                          hintText: 'Оставьте пустым для открытого входа',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordObscured
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () {
                              setDlgState(() {
                                isPasswordObscured = !isPasswordObscured;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Max Participants (Slider + Precise TextField)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Лимит участников:',
                            style: TextStyle(
                              color: Color(0xFF9F67FF),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: sliderVal >= 50
                                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                  : const Color(0xFF7C3AED).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: sliderVal >= 50
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF7C3AED),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              sliderVal >= 50
                                  ? '♾ Без лимита'
                                  : '${sliderVal.round()} чел.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sliderVal >= 50
                                    ? const Color(0xFF34D399)
                                    : const Color(0xFFC084FC),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF7C3AED),
                                inactiveTrackColor: Colors.white12,
                                thumbColor: const Color(0xFF9F67FF),
                                overlayColor: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                                trackHeight: 4,
                              ),
                              child: Slider(
                                value: sliderVal,
                                min: 2,
                                max: 50,
                                divisions: 48,
                                onChanged: (val) {
                                  setDlgState(() {
                                    sliderVal = val;
                                    if (val >= 50) {
                                      maxUsers = null;
                                      limitTextCtrl.text = '∞';
                                    } else {
                                      maxUsers = val.round();
                                      limitTextCtrl.text = val.round().toString();
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 74,
                            child: TextField(
                              controller: limitTextCtrl,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                hintText: '2-50',
                                hintStyle: const TextStyle(fontSize: 11, color: Colors.white30),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onChanged: (text) {
                                final parsed = int.tryParse(text.trim());
                                setDlgState(() {
                                  if (parsed == null || parsed >= 50 || parsed <= 0) {
                                    sliderVal = 50.0;
                                    maxUsers = null;
                                  } else {
                                    final clamped = parsed.clamp(2, 49);
                                    sliderVal = clamped.toDouble();
                                    maxUsers = clamped;
                                  }
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      Text(
                        sliderVal >= 50
                            ? '♾ Ползунок справа: количество участников неограниченно'
                            : 'Точная настройка: максимум ${sliderVal.round()} зрителей одновременно',
                        style: const TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Создать комнату'),
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Введите название комнаты')),
                      );
                      return;
                    }

                    final user = ref.read(currentUserProvider);
                    final ownerName =
                        user?.email?.split('@').first ?? 'Организатор';
                    final clientToken = RoomRepository.getClientToken();
                    final ownerId = user?.id ?? clientToken;
                    final pwd = passwordCtrl.text.trim();

                    final room = ref.read(roomsProvider.notifier).createRoom(
                          title: title,
                          ownerName: ownerName,
                          ownerId: ownerId,
                          password: pwd.isNotEmpty ? pwd : null,
                          maxParticipants: maxUsers,
                          videoSourceType: 'none',
                        );

                    Navigator.pop(ctx);
                    context.go('/rooms/${room.id}');
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allRooms = ref.watch(roomsProvider);
    final rooms = allRooms.where((r) {
      if (_filter == 'watching') return r.status == 'watching';
      if (_filter == 'preparing') return r.status == 'preparing';
      return true;
    }).toList();

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(activeRoute: '/rooms'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  pinned: true,
                  title: const Text('Комнаты совместного просмотра'),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Создать комнату'),
                        onPressed: _showCreateRoomDialog,
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Смотрите кино и сериалы синхронно с друзьями на Lordfilm и Кинопоиске, обсуждайте моменты в живом чате!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Все комнаты'),
                              selected: _filter == 'all',
                              onSelected: (_) =>
                                  setState(() => _filter = 'all'),
                            ),
                            ChoiceChip(
                              avatar: const Text('🍿'),
                              label: const Text('Смотрят прямо сейчас'),
                              selected: _filter == 'watching',
                              onSelected: (_) =>
                                  setState(() => _filter = 'watching'),
                            ),
                            ChoiceChip(
                              avatar: const Text('⏳'),
                              label: const Text('Запланированные'),
                              selected: _filter == 'preparing',
                              onSelected: (_) =>
                                  setState(() => _filter = 'preparing'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (rooms.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('Комнат пока нет. Создайте первую!'),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 380,
                        childAspectRatio: 1.15,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => _buildRoomCard(rooms[i]),
                        childCount: rooms.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(WatchRoom room) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final isOwner = user != null &&
        (room.ownerId == user.id ||
            room.ownerName.toLowerCase() ==
                (user.email?.split('@').first ?? '').toLowerCase());
    final canDelete = isOwner || isAdmin;
    final isWatching = room.status == 'watching';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/rooms/${room.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top status row
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_rounded,
                            size: 11, color: Color(0xFF9F67FF)),
                        const SizedBox(width: 4),
                        Text(
                          room.ownerName,
                          style: const TextStyle(
                            color: Color(0xFF9F67FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded,
                          size: 16, color: Colors.white54),
                      const SizedBox(width: 4),
                      Text(
                        '${room.participantCount}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      if (canDelete) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: Colors.redAccent),
                          tooltip: isOwner
                              ? 'Удалить свою комнату'
                              : 'Удалить комнату (Администратор)',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _confirmDeleteRoom(context, room),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                room.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),

              // Movie details with poster
              Row(
                children: [
                  if (room.moviePoster != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        room.moviePoster!,
                        width: 36,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.movie_rounded,
                            size: 28,
                            color: Colors.white24),
                      ),
                    )
                  else
                    Container(
                      width: 36,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.movie_rounded,
                          size: 20, color: Color(0xFF9F67FF)),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.movieTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF9F67FF),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Организатор: ${room.ownerName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11),
                        ),
                        Text(
                          'Сеанс: ${DateFormat('d MMM, HH:mm', 'ru').format(room.scheduledAt)}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),

              // Enter button (Comfortable height 48px)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWatching
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF252540),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text(
                    'Войти в комнату',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  onPressed: () => context.go('/rooms/${room.id}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
