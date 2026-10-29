import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_message.dart';
import '../models/watch_room.dart';

class RoomRepository {
  // In-memory state with demo rooms + dynamic rooms created by user
  final List<WatchRoom> _rooms = [
    WatchRoom(
      id: 'room-1',
      title: 'Космический вечер: смотрим шедевр Нолана',
      movieTitle: 'Интерстеллар',
      movieType: 'movie',
      moviePoster:
          'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=600&auto=format&fit=crop&q=80',
      movieYear: 2014,
      status: 'watching',
      scheduledAt: DateTime.now().subtract(const Duration(minutes: 45)),
      ownerName: 'Алексей (Кинокритик)',
      participantCount: 5,
      messages: [
        RoomMessage(
          id: 'm1',
          userName: 'Алексей',
          text: 'Всем привет! Подключайтесь к плееру Lordfilm, сцена на водяной планете просто пушка!',
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        RoomMessage(
          id: 'm2',
          userName: 'Мария',
          text: 'Саундтрек Ханса Циммера до мурашек каждый раз 🎹',
          createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
        ),
        RoomMessage(
          id: 'm3',
          userName: 'Дмитрий',
          text: '1 час на этой планете — 7 лет на Земле ⏳',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ],
    ),
    WatchRoom(
      id: 'room-2',
      title: 'Марафон сериала «Чернобыль» (1-3 серии)',
      movieTitle: 'Чернобыль',
      movieType: 'series',
      moviePoster:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      movieYear: 2019,
      status: 'preparing',
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      ownerName: 'Елена',
      participantCount: 3,
      messages: [
        RoomMessage(
          id: 'm4',
          userName: 'Елена',
          text: 'Начинаем сегодня в 20:00! Готовьте чай и пледы ☕',
          createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
        ),
      ],
    ),
    WatchRoom(
      id: 'room-3',
      title: 'Аниме-пятница с Хаяо Миядзаки ✨',
      movieTitle: 'Унесённые призраками',
      movieType: 'cartoon',
      moviePoster:
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&auto=format&fit=crop&q=80',
      movieYear: 2001,
      status: 'preparing',
      scheduledAt: DateTime.now().add(const Duration(hours: 4)),
      ownerName: 'Артём',
      participantCount: 7,
      messages: [
        RoomMessage(
          id: 'm5',
          userName: 'Артём',
          text: 'Кто ещё не смотрел в оригинале с субтитрами — подключайтесь!',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ],
    ),
  ];

  List<WatchRoom> getRooms() => List.unmodifiable(_rooms);

  WatchRoom? getRoomById(String id) {
    try {
      return _rooms.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  WatchRoom createRoom({
    required String title,
    required String movieTitle,
    required String movieType,
    String? moviePoster,
    int? movieYear,
    required DateTime scheduledAt,
    required String ownerName,
  }) {
    final room = WatchRoom(
      id: 'room-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      movieTitle: movieTitle,
      movieType: movieType,
      moviePoster: moviePoster,
      movieYear: movieYear,
      status: 'preparing',
      scheduledAt: scheduledAt,
      ownerName: ownerName,
      participantCount: 1,
      messages: [
        RoomMessage(
          id: 'm-${DateTime.now().millisecondsSinceEpoch}',
          userName: ownerName,
          text: 'Комната создана! Ждём зрителей к просмотру 🍿',
          createdAt: DateTime.now(),
        ),
      ],
    );
    _rooms.insert(0, room);
    return room;
  }

  void addMessage(String roomId, String userName, String text) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final room = _rooms[index];
      final newMsg = RoomMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        userName: userName,
        text: text,
        createdAt: DateTime.now(),
      );
      final updatedMessages = List<RoomMessage>.from(room.messages)..add(newMsg);
      _rooms[index] = room.copyWith(messages: updatedMessages);
    }
  }

  void updateStatus(String roomId, String newStatus) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      _rooms[index] = _rooms[index].copyWith(status: newStatus);
    }
  }
}

// Providers
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository();
});

class RoomsNotifier extends StateNotifier<List<WatchRoom>> {
  RoomsNotifier(this._repo) : super(_repo.getRooms());

  final RoomRepository _repo;

  void reload() {
    state = _repo.getRooms();
  }

  WatchRoom createRoom({
    required String title,
    required String movieTitle,
    required String movieType,
    String? moviePoster,
    int? movieYear,
    required DateTime scheduledAt,
    required String ownerName,
  }) {
    final room = _repo.createRoom(
      title: title,
      movieTitle: movieTitle,
      movieType: movieType,
      moviePoster: moviePoster,
      movieYear: movieYear,
      scheduledAt: scheduledAt,
      ownerName: ownerName,
    );
    state = _repo.getRooms();
    return room;
  }

  void addMessage(String roomId, String userName, String text) {
    _repo.addMessage(roomId, userName, text);
    state = _repo.getRooms();
  }

  void updateStatus(String roomId, String status) {
    _repo.updateStatus(roomId, status);
    state = _repo.getRooms();
  }
}

final roomsProvider =
    StateNotifierProvider<RoomsNotifier, List<WatchRoom>>((ref) {
  return RoomsNotifier(ref.watch(roomRepositoryProvider));
});

final singleRoomProvider =
    Provider.family<WatchRoom?, String>((ref, id) {
  final rooms = ref.watch(roomsProvider);
  try {
    return rooms.firstWhere((r) => r.id == id);
  } catch (_) {
    return null;
  }
});
