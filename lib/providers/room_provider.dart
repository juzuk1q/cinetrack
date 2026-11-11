import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';
import '../models/room_message.dart';
import '../models/watch_room.dart';

/// SHA-256 hash of a password string (matches PostgreSQL encode(sha256(...), 'hex'))
String _hashPassword(String password) {
  final bytes = utf8.encode(password);
  return sha256.convert(bytes).toString();
}

/// Returns the current authenticated user's ID, or empty string.
String _currentUserId() => supabase.auth.currentUser?.id ?? '';

class RoomRepository {
  /// Fetch all rooms from Supabase, ordered by creation date descending.
  Future<List<WatchRoom>> fetchRooms() async {
    try {
      final data = await supabase
          .from('rooms')
          .select()
          .order('created_at', ascending: false);

      return (data as List<dynamic>)
          .map((json) => _roomFromRow(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('RoomRepository.fetchRooms error: $e');
      return [];
    }
  }

  /// Fetch a single room by ID.
  Future<WatchRoom?> fetchRoomById(String id) async {
    try {
      final data =
          await supabase.from('rooms').select().eq('id', id).maybeSingle();
      if (data == null) return null;
      return _roomFromRow(data);
    } catch (e) {
      debugPrint('RoomRepository.fetchRoomById error: $e');
      return null;
    }
  }

  /// Create a room via server-side RPC (with fallback to direct insert).
  Future<WatchRoom?> createRoom({
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
  }) async {
    final effectiveOwnerId = (ownerId != null && ownerId.isNotEmpty)
        ? ownerId
        : _currentUserId();
    final roomId = 'room-${DateTime.now().millisecondsSinceEpoch}';
    final hasPwd = password != null && password.isNotEmpty;
    final pwdHash = hasPwd ? _hashPassword(password) : null;
    final sched = (scheduledAt ?? DateTime.now()).toIso8601String();

    try {
      final result = await supabase.rpc('create_room_with_password', params: {
        'p_id': roomId,
        'p_title': title,
        'p_owner_name': ownerName,
        'p_owner_id': effectiveOwnerId,
        'p_password': password,
        'p_max_participants': maxParticipants,
        'p_movie_title': movieTitle,
        'p_movie_type': movieType,
        'p_movie_poster': moviePoster,
        'p_movie_year': movieYear,
        'p_kinopoisk_id': kinopoiskId,
        'p_video_source_type': videoSourceType,
        'p_video_url': videoUrl,
        'p_scheduled_at': sched,
        'p_allow_guest_control': allowGuestControl,
      });

      if (result is Map<String, dynamic>) {
        final room = _roomFromRow(result);
        await _insertMessage(
          roomId: roomId,
          userName: ownerName,
          text: 'Комната создана! Ждём зрителей к просмотру 🍿',
          userId: effectiveOwnerId,
        );
        return room;
      }
    } catch (e) {
      debugPrint('create_room_with_password RPC failed, trying fallback: $e');
      try {
        final row = {
          'id': roomId,
          'title': title,
          'movie_title': movieTitle,
          'movie_type': movieType,
          'movie_poster': moviePoster,
          'movie_year': movieYear,
          'kinopoisk_id': kinopoiskId,
          'status': 'watching',
          'scheduled_at': sched,
          'owner_name': ownerName,
          'owner_id': effectiveOwnerId,
          'allow_guest_control': allowGuestControl,
          'participant_count': 1,
          'video_source_type': videoSourceType,
          'video_url': videoUrl,
          'password_hash': pwdHash,
          'max_participants': maxParticipants,
          'participants': [
            {'id': effectiveOwnerId, 'name': ownerName}
          ],
        };
        final inserted =
            await supabase.from('rooms').insert(row).select().single();
        final room = _roomFromRow(inserted);
        await _insertMessage(
          roomId: roomId,
          userName: ownerName,
          text: 'Комната создана! Ждём зрителей к просмотру 🍿',
          userId: effectiveOwnerId,
        );
        return room;
      } catch (err2) {
        debugPrint('Direct insert fallback failed: $err2');
      }
    }
    return null;
  }

  Future<void> updateRoomSettings(
    String roomId, {
    String? title,
    String? status,
    DateTime? scheduledAt,
    bool? allowGuestControl,
    String? password,
    int? maxParticipants,
    List<String>? allowedControllers,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (status != null) updates['status'] = status;
      if (scheduledAt != null) {
        updates['scheduled_at'] = scheduledAt.toIso8601String();
      }
      if (allowGuestControl != null) {
        updates['allow_guest_control'] = allowGuestControl;
      }
      if (password != null) {
        updates['password_hash'] =
            password.isNotEmpty ? _hashPassword(password) : null;
      }
      if (maxParticipants != null) {
        updates['max_participants'] = maxParticipants;
      }
      if (allowedControllers != null) {
        updates['allowed_controllers'] = allowedControllers;
      }

      if (updates.isNotEmpty) {
        await supabase.from('rooms').update(updates).eq('id', roomId);
      }
    } catch (e) {
      debugPrint('RoomRepository.updateRoomSettings error: $e');
    }
  }

  Future<void> setRoomMovieSource(
    String roomId, {
    required String movieTitle,
    String movieType = 'movie',
    String? moviePoster,
    int? movieYear,
    int? kinopoiskId,
    required String videoSourceType,
    String? videoUrl,
    String? videoFileName,
  }) async {
    try {
      await supabase.from('rooms').update({
        'movie_title': movieTitle,
        'movie_type': movieType,
        'movie_poster': moviePoster,
        'movie_year': movieYear,
        'kinopoisk_id': kinopoiskId,
        'video_source_type': videoSourceType,
        'video_url': videoUrl,
        'video_file_name': videoFileName,
      }).eq('id', roomId);
    } catch (e) {
      debugPrint('RoomRepository.setRoomMovieSource error: $e');
    }
  }

  Future<void> updateStatus(String roomId, String newStatus) async {
    try {
      await supabase
          .from('rooms')
          .update({'status': newStatus}).eq('id', roomId);
    } catch (e) {
      debugPrint('RoomRepository.updateStatus error: $e');
    }
  }

  Future<void> updateVideoSource(
    String roomId, {
    required String sourceType,
    String? videoUrl,
    String? videoFileName,
  }) async {
    try {
      await supabase.from('rooms').update({
        'video_source_type': sourceType,
        'video_url': videoUrl,
        'video_file_name': videoFileName,
      }).eq('id', roomId);
    } catch (e) {
      debugPrint('RoomRepository.updateVideoSource error: $e');
    }
  }

  Future<void> updatePlayback(
    String roomId, {
    required double position,
    required bool isPlaying,
  }) async {
    try {
      await supabase.from('rooms').update({
        'current_position': position,
        'is_playing': isPlaying,
      }).eq('id', roomId);
    } catch (e) {
      debugPrint('RoomRepository.updatePlayback error: $e');
    }
  }

  Future<void> deleteRoom(String roomId) async {
    try {
      await supabase.from('room_messages').delete().eq('room_id', roomId);
      await supabase.from('rooms').delete().eq('id', roomId);
    } catch (e) {
      debugPrint('RoomRepository.deleteRoom error: $e');
    }
  }

  Future<void> addParticipant(
      String roomId, String participantId, String userName) async {
    try {
      final data =
          await supabase.from('rooms').select().eq('id', roomId).single();
      final room = _roomFromRow(data);

      final parts = List<Map<String, String>>.from(room.participants);
      if (!parts.any((p) => p['id'] == participantId)) {
        parts.add({'id': participantId, 'name': userName});
        await supabase.from('rooms').update({
          'participants': parts,
          'participant_count': parts.length > room.participantCount
              ? parts.length
              : room.participantCount + 1,
        }).eq('id', roomId);
      }
    } catch (e) {
      debugPrint('RoomRepository.addParticipant error: $e');
    }
  }

  Future<void> transferRoomHost(String roomId,
      {required String? newHostId, required String newHostName}) async {
    try {
      await supabase.from('rooms').update({
        'owner_id': newHostId,
        'owner_name': newHostName,
      }).eq('id', roomId);
    } catch (e) {
      debugPrint('RoomRepository.transferRoomHost error: $e');
    }
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    try {
      final data =
          await supabase.from('rooms').select().eq('id', roomId).single();
      final room = _roomFromRow(data);

      final parts = List<Map<String, String>>.from(room.participants)
        ..removeWhere((p) => p['id'] == userId);
      final newCount = (room.participantCount - 1).clamp(0, 9999);

      if (newCount <= 0 || parts.isEmpty) {
        await deleteRoom(roomId);
      } else {
        String newOwnerId = room.ownerId ?? '';
        String newOwnerName = room.ownerName;
        if (room.ownerId == userId || room.ownerName == userId) {
          final nextHost = parts.first;
          newOwnerId = nextHost['id'] ?? '';
          newOwnerName = nextHost['name'] ?? 'Организатор';
        }
        await supabase.from('rooms').update({
          'participant_count': newCount,
          'participants': parts,
          'owner_id': newOwnerId,
          'owner_name': newOwnerName,
        }).eq('id', roomId);
      }
    } catch (e) {
      debugPrint('RoomRepository.leaveRoom error: $e');
    }
  }

  Future<void> _insertMessage({
    required String roomId,
    required String userName,
    required String text,
    String? userId,
  }) async {
    try {
      await supabase.from('room_messages').insert({
        'room_id': roomId,
        'user_name': userName,
        'text': text,
        'user_id': userId ?? _currentUserId(),
      });
    } catch (e) {
      debugPrint('RoomRepository._insertMessage error: $e');
    }
  }

  Future<void> addMessage(
      String roomId, String userName, String text, [String? senderId]) async {
    await _insertMessage(
      roomId: roomId,
      userName: userName,
      text: text,
      userId: senderId ?? _currentUserId(),
    );
  }

  Future<List<RoomMessage>> fetchMessages(String roomId) async {
    try {
      final data = await supabase
          .from('room_messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: true);

      return (data as List<dynamic>)
          .map((json) => RoomMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('RoomRepository.fetchMessages error: $e');
      return [];
    }
  }

  Future<bool> verifyRoomPassword(String roomId, String password) async {
    try {
      final result = await supabase.rpc('verify_room_password', params: {
        'target_room_id': roomId,
        'attempt_password': password,
      });
      return result == true;
    } catch (e) {
      debugPrint('verify_room_password RPC failed, trying fallback: $e');
      try {
        final data = await supabase
            .from('rooms')
            .select('password_hash')
            .eq('id', roomId)
            .maybeSingle();
        if (data == null) return false;
        final stored = data['password_hash'] as String?;
        if (stored == null || stored.isEmpty) return true;
        return stored == _hashPassword(password);
      } catch (_) {
        return false;
      }
    }
  }

  static WatchRoom _roomFromRow(Map<String, dynamic> json,
      {List<RoomMessage> messages = const []}) {
    final hasPasswordHash = json['password_hash'] != null &&
        (json['password_hash'] as String).isNotEmpty;
    final hasPassword = json['has_password'] == true || hasPasswordHash;

    final adjusted = Map<String, dynamic>.from(json);
    adjusted.remove('password_hash');
    adjusted['password'] = hasPassword ? '***' : null;

    if (adjusted['participants'] is String) {
      try {
        adjusted['participants'] =
            jsonDecode(adjusted['participants'] as String);
      } catch (_) {
        adjusted['participants'] = [];
      }
    }
    if (adjusted['allowed_controllers'] is String) {
      try {
        adjusted['allowed_controllers'] =
            jsonDecode(adjusted['allowed_controllers'] as String);
      } catch (_) {
        adjusted['allowed_controllers'] = [];
      }
    }

    adjusted.remove('messages');

    final room = WatchRoom.fromJson(adjusted);
    if (messages.isNotEmpty) {
      return room.copyWith(messages: messages);
    }
    return room;
  }
}

// ──────────────────────── PROVIDERS ────────────────────────

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository();
});

class RoomsNotifier extends StateNotifier<List<WatchRoom>> {
  RoomsNotifier(this._repo) : super([]) {
    _loadRooms();
  }

  final RoomRepository _repo;
  final Map<String, List<RoomMessage>> _messagesCache = {};

  Future<void> _loadRooms() async {
    final rooms = await _repo.fetchRooms();
    // Reattach cached messages
    final updated = rooms.map((r) {
      final cached = _messagesCache[r.id];
      if (cached != null && cached.isNotEmpty) {
        return r.copyWith(messages: cached);
      }
      return r;
    }).toList();
    state = updated;
  }

  Future<void> reload() async {
    await _loadRooms();
  }

  Future<void> loadMessages(String roomId) async {
    final msgs = await _repo.fetchMessages(roomId);
    _messagesCache[roomId] = msgs;
    final index = state.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final updated = List<WatchRoom>.from(state);
      updated[index] = updated[index].copyWith(messages: msgs);
      state = updated;
    }
  }

  Future<WatchRoom?> createRoom({
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
  }) async {
    final room = await _repo.createRoom(
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
    if (room != null) {
      state = [room, ...state];
    }
    return room;
  }

  Future<void> updateRoomSettings(
    String roomId, {
    String? title,
    String? status,
    DateTime? scheduledAt,
    bool? allowGuestControl,
    String? password,
    int? maxParticipants,
    List<String>? allowedControllers,
  }) async {
    final index = state.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final updated = List<WatchRoom>.from(state);
      updated[index] = updated[index].copyWith(
        title: title,
        status: status,
        scheduledAt: scheduledAt,
        allowGuestControl: allowGuestControl,
        password: (password != null && password.isNotEmpty) ? '***' : null,
        maxParticipants: maxParticipants,
        allowedControllers: allowedControllers,
      );
      state = updated;
    }
    await _repo.updateRoomSettings(
      roomId,
      title: title,
      status: status,
      scheduledAt: scheduledAt,
      allowGuestControl: allowGuestControl,
      password: password,
      maxParticipants: maxParticipants,
      allowedControllers: allowedControllers,
    );
  }

  Future<void> setRoomMovieSource(
    String roomId, {
    required String movieTitle,
    String movieType = 'movie',
    String? moviePoster,
    int? movieYear,
    int? kinopoiskId,
    required String videoSourceType,
    String? videoUrl,
    String? videoFileName,
  }) async {
    final index = state.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final updated = List<WatchRoom>.from(state);
      updated[index] = updated[index].copyWith(
        movieTitle: movieTitle,
        movieType: movieType,
        moviePoster: moviePoster,
        movieYear: movieYear,
        kinopoiskId: kinopoiskId,
        videoSourceType: videoSourceType,
        videoUrl: videoUrl,
        videoFileName: videoFileName,
      );
      state = updated;
    }
    await _repo.setRoomMovieSource(
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
  }

  Future<void> deleteRoom(String roomId) async {
    state = state.where((r) => r.id != roomId).toList();
    _messagesCache.remove(roomId);
    await _repo.deleteRoom(roomId);
  }

  Future<void> addParticipant(
      String roomId, String userId, String userName) async {
    final index = state.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final room = state[index];
      final parts = List<Map<String, String>>.from(room.participants);
      if (!parts.any((p) => p['id'] == userId)) {
        parts.add({'id': userId, 'name': userName});
        final updated = List<WatchRoom>.from(state);
        updated[index] = room.copyWith(
          participants: parts,
          participantCount: parts.length > room.participantCount
              ? parts.length
              : room.participantCount + 1,
        );
        state = updated;
      }
    }
    await _repo.addParticipant(roomId, userId, userName);
  }

  Future<void> transferRoomHost(String roomId,
      {required String? newHostId, required String newHostName}) async {
    final index = state.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final updated = List<WatchRoom>.from(state);
      updated[index] = updated[index].copyWith(
        ownerId: newHostId,
        ownerName: newHostName,
      );
      state = updated;
    }
    await _repo.transferRoomHost(roomId,
        newHostId: newHostId, newHostName: newHostName);
  }

  Future<void> leaveRoom(String roomId, String userId) async {
    final index = state.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final room = state[index];
      final parts = List<Map<String, String>>.from(room.participants)
        ..removeWhere((p) => p['id'] == userId);
      final newCount = (room.participantCount - 1).clamp(0, 9999);

      if (newCount <= 0 || parts.isEmpty) {
        state = state.where((r) => r.id != roomId).toList();
      } else {
        String newOwnerId = room.ownerId ?? '';
        String newOwnerName = room.ownerName;
        if (room.ownerId == userId || room.ownerName == userId) {
          final nextHost = parts.first;
          newOwnerId = nextHost['id'] ?? '';
          newOwnerName = nextHost['name'] ?? 'Организатор';
        }
        final updated = List<WatchRoom>.from(state);
        updated[index] = room.copyWith(
          participantCount: newCount,
          participants: parts,
          ownerId: newOwnerId,
          ownerName: newOwnerName,
        );
        state = updated;
      }
    }
    await _repo.leaveRoom(roomId, userId);
  }

  Future<void> addMessage(String roomId, String userName, String text,
      [String? senderId]) async {
    final newMsg = RoomMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      userName: userName,
      text: text,
      createdAt: DateTime.now(),
      senderId: senderId,
    );

    // Update local cache
    final current = _messagesCache[roomId] ?? [];
    _messagesCache[roomId] = [...current, newMsg];

    // Update room in state
    final index = state.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final updated = List<WatchRoom>.from(state);
      updated[index] = updated[index].copyWith(
        messages: _messagesCache[roomId]!,
      );
      state = updated;
    }

    await _repo.addMessage(roomId, userName, text, senderId);
  }

  Future<void> updateStatus(String roomId, String status) async {
    final index = state.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final updated = List<WatchRoom>.from(state);
      updated[index] = updated[index].copyWith(status: status);
      state = updated;
    }
    await _repo.updateStatus(roomId, status);
  }

  Future<void> updateVideoSource(
    String roomId, {
    required String sourceType,
    String? videoUrl,
    String? videoFileName,
  }) async {
    final index = state.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final updated = List<WatchRoom>.from(state);
      updated[index] = updated[index].copyWith(
        videoSourceType: sourceType,
        videoUrl: videoUrl,
        videoFileName: videoFileName,
      );
      state = updated;
    }
    await _repo.updateVideoSource(
      roomId,
      sourceType: sourceType,
      videoUrl: videoUrl,
      videoFileName: videoFileName,
    );
  }

  Future<void> updatePlayback(
    String roomId, {
    required double position,
    required bool isPlaying,
  }) async {
    final index = state.indexWhere((r) => r.id == roomId);
    if (index != -1) {
      final updated = List<WatchRoom>.from(state);
      updated[index] = updated[index].copyWith(
        currentPosition: position,
        isPlaying: isPlaying,
      );
      state = updated;
    }
    await _repo.updatePlayback(roomId, position: position, isPlaying: isPlaying);
  }
}

final roomsProvider =
    StateNotifierProvider<RoomsNotifier, List<WatchRoom>>((ref) {
  return RoomsNotifier(ref.watch(roomRepositoryProvider));
});

final singleRoomProvider = Provider.family<WatchRoom?, String>((ref, id) {
  final rooms = ref.watch(roomsProvider);
  try {
    return rooms.firstWhere((r) => r.id == id);
  } catch (_) {
    return null;
  }
});

final roomMessagesProvider =
    FutureProvider.family<List<RoomMessage>, String>((ref, roomId) async {
  final repo = ref.read(roomRepositoryProvider);
  return repo.fetchMessages(roomId);
});
