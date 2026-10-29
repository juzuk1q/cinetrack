import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../data/curated_catalog.dart';
import '../../models/catalog_item.dart';
import '../../models/watch_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/app_sidebar.dart';

class RoomsScreen extends ConsumerStatefulWidget {
  const RoomsScreen({super.key});

  @override
  ConsumerState<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends ConsumerState<RoomsScreen> {
  String _filter = 'all'; // 'all', 'watching', 'preparing'

  void _showCreateRoomDialog() {
    final titleCtrl = TextEditingController();
    final movieCtrl = TextEditingController();
    CatalogItem? selectedMovie;
    DateTime scheduledDate = DateTime.now().add(const Duration(hours: 1));
    String movieType = 'movie';

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
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Пригласите друзей или присоединяйтесь к совместному просмотру фильмов с живым чатом!',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 16),

                      // Room Title
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Название комнаты *',
                          hintText: 'Например, «Киновечер пятницы»',
                          prefixIcon: Icon(Icons.meeting_room_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Choose Movie from catalog
                      const Text('Выберите фильм из библиотеки:',
                          style: TextStyle(
                              color: Color(0xFF9F67FF),
                              fontWeight: FontWeight.w600,
                              fontSize: 12)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<CatalogItem>(
                        isExpanded: true,
                        hint: const Text('Выберите фильм/сериал...'),
                        initialValue: selectedMovie,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.movie_outlined),
                        ),
                        items: CuratedCatalog.items.map((m) {
                          return DropdownMenuItem<CatalogItem>(
                            value: m,
                            child: Text(
                              '${m.title} (${m.year}) — ${AppConstants.mediaTypes[m.type]}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDlgState(() {
                            selectedMovie = val;
                            if (val != null) {
                              movieCtrl.text = val.title;
                              movieType = val.type;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Or enter manual movie title
                      TextField(
                        controller: movieCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Или введите своё название фильма',
                          prefixIcon: Icon(Icons.edit_note_rounded),
                        ),
                        onChanged: (v) {
                          if (selectedMovie != null &&
                              selectedMovie!.title != v) {
                            setDlgState(() => selectedMovie = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Scheduled Date/Time
                      ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Colors.white12)),
                        leading: const Icon(Icons.access_time_rounded,
                            color: Color(0xFF9F67FF)),
                        title: const Text('Время сеанса',
                            style: TextStyle(fontSize: 14)),
                        subtitle: Text(
                          DateFormat('d MMMM, HH:mm', 'ru').format(scheduledDate),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.edit_calendar_rounded, size: 20),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: scheduledDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                            locale: const Locale('ru'),
                          );
                          if (date != null && context.mounted) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(scheduledDate),
                            );
                            if (time != null) {
                              setDlgState(() {
                                scheduledDate = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
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
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Создать комнату'),
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final movie = movieCtrl.text.trim();
                    if (title.isEmpty || movie.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Заполните название комнаты и фильма')),
                      );
                      return;
                    }

                    final user = ref.read(currentUserProvider);
                    final ownerName = user?.email?.split('@').first ?? 'Организатор';

                    final room = ref.read(roomsProvider.notifier).createRoom(
                          title: title,
                          movieTitle: movie,
                          movieType: selectedMovie?.type ?? movieType,
                          moviePoster: selectedMovie?.posterUrl,
                          movieYear: selectedMovie?.year,
                          scheduledAt: scheduledDate,
                          ownerName: ownerName,
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
      body: Row(
        children: [
          const AppSidebar(selectedIndex: 2),
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
                      color: isWatching
                          ? const Color(0xFF10B981).withValues(alpha: 0.2)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isWatching
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(isWatching ? '🍿 Смотрят сейчас' : '⏳ Запланирован'),
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

              // Enter button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWatching
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF252540),
                  ),
                  icon: const Icon(Icons.login_rounded, size: 16),
                  label: const Text('Войти в комнату'),
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
