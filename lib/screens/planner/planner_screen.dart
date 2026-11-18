import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/media_item.dart';
import '../../providers/media_provider.dart';
import '../../widgets/app_header.dart';

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  Map<DateTime, List<MediaItem>> _eventMap = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  Map<DateTime, List<MediaItem>> _buildEventMap(List<MediaItem> items) {
    final map = <DateTime, List<MediaItem>>{};
    for (final item in items) {
      if (item.plannedDate == null) continue;
      final key = DateTime(
        item.plannedDate!.year,
        item.plannedDate!.month,
        item.plannedDate!.day,
      );
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }

  List<MediaItem> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _eventMap[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final plannedAsync = ref.watch(plannedMediaProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(activeRoute: '/planner'),
          Expanded(
            child: plannedAsync.when(
              data: (items) {
                _eventMap = _buildEventMap(items);
                final selectedEvents = _selectedDay != null
                    ? _getEventsForDay(_selectedDay!)
                    : [];

                return Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded,
                              color: Color(0xFF7C3AED), size: 26),
                          const SizedBox(width: 10),
                          Text(
                            'Планировщик',
                            style:
                                Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Calendar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Card(
                        child: TableCalendar<MediaItem>(
                          locale: 'ru_RU',
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2030),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (d) =>
                              isSameDay(d, _selectedDay),
                          calendarFormat: _calendarFormat,
                          eventLoader: _getEventsForDay,
                          startingDayOfWeek: StartingDayOfWeek.monday,
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            todayDecoration: BoxDecoration(
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: const BoxDecoration(
                              color: Color(0xFF7C3AED),
                              shape: BoxShape.circle,
                            ),
                            markerDecoration: const BoxDecoration(
                              color: Color(0xFFE040FB),
                              shape: BoxShape.circle,
                            ),
                            defaultTextStyle:
                                const TextStyle(color: Colors.white70),
                            weekendTextStyle:
                                const TextStyle(color: Color(0xFF9F67FF)),
                            todayTextStyle:
                                const TextStyle(color: Colors.white),
                            selectedTextStyle:
                                const TextStyle(color: Colors.white),
                            outsideTextStyle:
                                const TextStyle(color: Colors.white24),
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonDecoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            formatButtonTextStyle:
                                const TextStyle(color: Colors.white70),
                            titleTextStyle: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            leftChevronIcon: const Icon(
                                Icons.chevron_left, color: Colors.white70),
                            rightChevronIcon: const Icon(
                                Icons.chevron_right, color: Colors.white70),
                          ),
                          daysOfWeekStyle: const DaysOfWeekStyle(
                            weekdayStyle: TextStyle(color: Colors.white54),
                            weekendStyle:
                                TextStyle(color: Color(0xFF9F67FF)),
                          ),
                          onDaySelected: (selected, focused) {
                            setState(() {
                              _selectedDay = selected;
                              _focusedDay = focused;
                            });
                          },
                          onFormatChanged: (format) {
                            setState(() => _calendarFormat = format);
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Selected day info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Text(
                            _selectedDay != null
                                ? DateFormat('d MMMM y', 'ru')
                                    .format(_selectedDay!)
                                : 'Выберите дату',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(width: 8),
                          if (selectedEvents.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${selectedEvents.length}',
                                style: const TextStyle(
                                    color: Color(0xFF9F67FF),
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Events list
                    Expanded(
                      child: selectedEvents.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_busy_rounded,
                                      size: 48, color: Colors.white24),
                                  SizedBox(height: 12),
                                  Text(
                                    'На этот день ничего не запланировано',
                                    style: TextStyle(color: Colors.white38),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              itemCount: selectedEvents.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final item =
                                    selectedEvents[i] as MediaItem;
                                return _PlannerItemTile(item: item);
                              },
                            ),
                    ),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlannerItemTile extends StatelessWidget {
  final MediaItem item;
  const _PlannerItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: item.posterUrl != null && item.posterUrl!.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  item.posterUrl!,
                  width: 44,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _placeholder(),
                ),
              )
            : _placeholder(),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${_typeLabel(item.type)} • ${item.status == "watched" ? "Просмотрено" : "Запланировано"}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.go('/media/${item.id}'),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.movie_rounded, color: Colors.white24),
    );
  }

  String _typeLabel(String type) {
    const map = {'movie': 'Фильм', 'series': 'Сериал', 'cartoon': 'Мульт'};
    return map[type] ?? type;
  }
}
