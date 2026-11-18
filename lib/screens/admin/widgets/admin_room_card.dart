import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/watch_room.dart';
import '../../../providers/room_provider.dart';
import '../../../widgets/top_notification.dart';

class AdminRoomCard extends ConsumerWidget {
  final WatchRoom room;
  final bool isDark;

  const AdminRoomCard({
    super.key,
    required this.room,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
  
    return Card(
      color: isDark ? const Color(0xFF16162A) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
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
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF0F172A)),
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
                    style: TextStyle(
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        fontSize: 12),
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

