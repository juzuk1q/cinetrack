// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/room_message.dart';
import '../models/watch_room.dart';

class RoomRepository {
  static const String _storageKey = 'cinetrack_rooms_v1';
  final List<WatchRoom> _rooms = [];

  static String getClientToken() {
    try {
      final token = html.window.localStorage['cinetrack_client_uid'];
      if (token != null && token.isNotEmpty) return token;
      final newToken =
          'user_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
      html.window.localStorage['cinetrack_client_uid'] = newToken;
      return newToken;
    } catch (_) {
      return 'user_default';
    }
  }

  RoomRepository() {
    _loadRooms();
  }

  void _loadRooms() {
    try {
      final saved = html.window.localStorage[_storageKey];
      if (saved != null && saved.isNotEmpty) {
        final List<dynamic> list = jsonDecode(saved);
        _rooms.clear();
        for (final item in list) {
          _rooms.add(WatchRoom.fromJson(item as Map<String, dynamic>));
        }
      }
    } catch (_) {}
  }


  void _saveRooms() {
    try {
      final jsonStr = jsonEncode(_rooms.map((r) => r.toJson()).toList());
      html.window.localStorage[_storageKey] = jsonStr;
    } catch (_) {}
  }

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
    String movieTitle = 'Источник не выбран',
    String movieType = 'movie',
    String? moviePoster,
    int? movieYear,
    int? kinopoiskId,
    DateTime? scheduledAt,
    required String ownerName,
    String? ownerId,
    bool allowGuestControl = false,
    String? password,
    int? maxParticipants,
    String videoSourceType = 'none',
    String? videoUrl,
  }) {
    final effectiveOwnerId = ownerId ?? getClientToken();
    final room = WatchRoom(
      id: 'room-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      movieTitle: movieTitle,
      movieType: movieType,
      moviePoster: moviePoster,
      movieYear: movieYear,
      kinopoiskId: kinopoiskId,
      status: 'watching',
      scheduledAt: scheduledAt ?? DateTime.now(),
      ownerName: ownerName,
      ownerId: effectiveOwnerId,
      allowGuestControl: allowGuestControl,
      participantCount: 1,
      password: password,
      maxParticipants: maxParticipants,
      videoSourceType: videoSourceType,
      videoUrl: videoUrl,
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
    _saveRooms();
    return room;
  }

  void updateRoomSettings(
    String roomId, {
    String? title,
    String? status,
    DateTime? scheduledAt,
    bool? allowGuestControl,
    String? password,
    int? maxParticipants,
    List<String>? allowedControllers,
  }) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      _rooms[index] = _rooms[index].copyWith(
        title: title,
        status: status,
        scheduledAt: scheduledAt,
        allowGuestControl: allowGuestControl,
        password: password,
        maxParticipants: maxParticipants,
        allowedControllers: allowedControllers,
      );
      _saveRooms();
    }
  }

  void setRoomMovieSource(
    String roomId, {
    required String movieTitle,
    String movieType = 'movie',
    String? moviePoster,
    int? movieYear,
    int? kinopoiskId,
    required String videoSourceType,
    String? videoUrl,
    String? videoFileName,
  }) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      _rooms[index] = _rooms[index].copyWith(
        movieTitle: movieTitle,
        movieType: movieType,
        moviePoster: moviePoster,
        movieYear: movieYear,
        kinopoiskId: kinopoiskId,
        videoSourceType: videoSourceType,
        videoUrl: videoUrl,
        videoFileName: videoFileName,
      );
      _saveRooms();
    }
  }

  void deleteRoom(String roomId) {
    _rooms.removeWhere((r) => r.id == roomId);
    _saveRooms();
  }

  void addParticipant(String roomId, String userId, String userName) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final room = _rooms[index];
      final parts = List<Map<String, String>>.from(room.participants);
      if (!parts.any((p) => p['id'] == userId)) {
        parts.add({'id': userId, 'name': userName});
        _rooms[index] = room.copyWith(
          participants: parts,
          participantCount: parts.length > room.participantCount ? parts.length : room.participantCount + 1,
        );
        _saveRooms();
      }
    }
  }

  void transferRoomHost(String roomId, {required String? newHostId, required String newHostName}) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final room = _rooms[index];
      _rooms[index] = room.copyWith(
        ownerId: newHostId,
        ownerName: newHostName,
      );
      _saveRooms();
    }
  }

  void leaveRoom(String roomId, String userId) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final room = _rooms[index];
      final parts = List<Map<String, String>>.from(room.participants)
        ..removeWhere((p) => p['id'] == userId);
      final newCount = (room.participantCount - 1).clamp(0, 9999);
      if (newCount <= 0 || parts.isEmpty) {
        deleteRoom(roomId);
      } else {
        String newOwnerId = room.ownerId ?? '';
        String newOwnerName = room.ownerName;
        if (room.ownerId == userId || room.ownerName == userId) {
          final nextHost = parts.first;
          newOwnerId = nextHost['id'] ?? '';
          newOwnerName = nextHost['name'] ?? 'Организатор';
        }
        _rooms[index] = room.copyWith(
          participantCount: newCount,
          participants: parts,
          ownerId: newOwnerId,
          ownerName: newOwnerName,
        );
        _saveRooms();
      }
    }
  }

  void addMessage(String roomId, String userName, String text, [String? senderId]) {
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
      _saveRooms();
    }
  }

  void updateStatus(String roomId, String newStatus) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      _rooms[index] = _rooms[index].copyWith(status: newStatus);
      _saveRooms();
    }
  }

  void updateVideoSource(
    String roomId, {
    required String sourceType,
    String? videoUrl,
    String? videoFileName,
  }) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      _rooms[index] = _rooms[index].copyWith(
        videoSourceType: sourceType,
        videoUrl: videoUrl,
        videoFileName: videoFileName,
      );
      _saveRooms();
    }
  }

  void updatePlayback(
    String roomId, {
    required double position,
    required bool isPlaying,
  }) {
    final index = _rooms.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      _rooms[index] = _rooms[index].copyWith(
        currentPosition: position,
        isPlaying: isPlaying,
      );
      _saveRooms();
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
    String movieTitle = 'Источник не выбран',
    String movieType = 'movie',
    String? moviePoster,
    int? movieYear,
    int? kinopoiskId,
    DateTime? scheduledAt,
    required String ownerName,
    String? ownerId,
    bool allowGuestControl = false,
    String? password,
    int? maxParticipants,
    String videoSourceType = 'none',
    String? videoUrl,
  }) {
    final room = _repo.createRoom(
      title: title,
      movieTitle: movieTitle,
      movieType: movieType,
      moviePoster: moviePoster,
      movieYear: movieYear,
      kinopoiskId: kinopoiskId,
      scheduledAt: scheduledAt,
      ownerName: ownerName,
      ownerId: ownerId,
      allowGuestControl: allowGuestControl,
      password: password,
      maxParticipants: maxParticipants,
      videoSourceType: videoSourceType,
      videoUrl: videoUrl,
    );
    state = _repo.getRooms();
    return room;
  }

  void updateRoomSettings(
    String roomId, {
    String? title,
    String? status,
    DateTime? scheduledAt,
    bool? allowGuestControl,
    String? password,
    int? maxParticipants,
    List<String>? allowedControllers,
  }) {
    _repo.updateRoomSettings(
      roomId,
      title: title,
      status: status,
      scheduledAt: scheduledAt,
      allowGuestControl: allowGuestControl,
      password: password,
      maxParticipants: maxParticipants,
      allowedControllers: allowedControllers,
    );
    state = _repo.getRooms();
  }

  void setRoomMovieSource(
    String roomId, {
    required String movieTitle,
    String movieType = 'movie',
    String? moviePoster,
    int? movieYear,
    int? kinopoiskId,
    required String videoSourceType,
    String? videoUrl,
    String? videoFileName,
  }) {
    _repo.setRoomMovieSource(
      roomId,
      movieTitle: movieTitle,
      movieType: movieType,
      moviePoster: moviePoster,
      movieYear: movieYear,
      kinopoiskId: kinopoiskId,
      videoSourceType: videoSourceType,
      videoUrl: videoUrl,
      videoFileName: videoFileName,
    );
    state = _repo.getRooms();
  }

  void deleteRoom(String roomId) {
    _repo.deleteRoom(roomId);
    state = _repo.getRooms();
  }

  void addParticipant(String roomId, String userId, String userName) {
    _repo.addParticipant(roomId, userId, userName);
    state = _repo.getRooms();
  }

  void transferRoomHost(String roomId, {required String? newHostId, required String newHostName}) {
    _repo.transferRoomHost(roomId, newHostId: newHostId, newHostName: newHostName);
    state = _repo.getRooms();
  }

  void leaveRoom(String roomId, String userId) {
    _repo.leaveRoom(roomId, userId);
    state = _repo.getRooms();
  }

  void addMessage(String roomId, String userName, String text, [String? senderId]) {
    _repo.addMessage(roomId, userName, text, senderId);
    state = _repo.getRooms();
  }

  void updateStatus(String roomId, String status) {
    _repo.updateStatus(roomId, status);
    state = _repo.getRooms();
  }

  void updateVideoSource(
    String roomId, {
    required String sourceType,
    String? videoUrl,
    String? videoFileName,
  }) {
    _repo.updateVideoSource(
      roomId,
      sourceType: sourceType,
      videoUrl: videoUrl,
      videoFileName: videoFileName,
    );
    state = _repo.getRooms();
  }

  void updatePlayback(
    String roomId, {
    required double position,
    required bool isPlaying,
  }) {
    _repo.updatePlayback(roomId, position: position, isPlaying: isPlaying);
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
