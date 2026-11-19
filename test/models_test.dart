import 'package:flutter_test/flutter_test.dart';
import 'package:cinetrack/models/user_profile.dart';
import 'package:cinetrack/models/media_item.dart';
import 'package:cinetrack/models/watch_room.dart';
import 'package:cinetrack/models/room_message.dart';
import 'package:cinetrack/models/movie_review.dart';
import 'package:cinetrack/models/friend_request.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('fromJson and toJson should preserve all fields', () {
      final json = {
        'id': 'user-123',
        'email': 'alex@example.com',
        'display_name': 'Alex',
        'username': 'alex_cool',
        'custom_title': 'Cinema Critic',
        'role': 'moderator',
        'is_blocked': false,
        'is_frozen': false,
        'unlocked_titles': ['welcome', 'collector_3'],
        'created_at': '2026-01-01T12:00:00.000Z',
        'updated_at': '2026-01-02T12:00:00.000Z',
      };

      final profile = UserProfile.fromJson(json);

      expect(profile.id, 'user-123');
      expect(profile.email, 'alex@example.com');
      expect(profile.displayName, 'Alex');
      expect(profile.username, 'alex_cool');
      expect(profile.customTitle, 'Cinema Critic');
      expect(profile.role, 'moderator');
      expect(profile.isBlocked, false);
      expect(profile.isFrozen, false);
      expect(profile.isRestricted, false);
      expect(profile.unlockedTitles, contains('welcome'));
      expect(profile.roleLabel, 'Модератор');

      final serialized = profile.toJson();
      expect(serialized['id'], 'user-123');
      expect(serialized['email'], 'alex@example.com');
      expect(serialized['role'], 'moderator');
      expect(serialized['custom_title'], 'Cinema Critic');
    });

    test('Hierarchy and permissions: canManage', () {
      final admin = UserProfile.fromJson({
        'id': 'admin-1',
        'email': 'admin@cinetrack.app',
        'display_name': 'Admin',
        'username': 'admin',
        'role': 'admin',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      final moderator = UserProfile.fromJson({
        'id': 'mod-1',
        'email': 'mod@cinetrack.app',
        'display_name': 'Mod',
        'username': 'mod',
        'role': 'moderator',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      final user = UserProfile.fromJson({
        'id': 'user-1',
        'email': 'user@cinetrack.app',
        'display_name': 'Regular',
        'username': 'user',
        'role': 'user',
        'created_at': '2026-01-01T00:00:00.000Z',
      });

      expect(admin.canManage(moderator), true);
      expect(admin.canManage(user), true);
      expect(moderator.canManage(user), false);
      expect(moderator.canManage(admin), false);
      expect(user.canManage(moderator), false);
    });
  });

  group('MediaItem Model Tests', () {
    test('fromJson and toJson serialization', () {
      final now = DateTime.now();
      final item = MediaItem(
        id: 'media-456',
        userId: 'user-123',
        title: 'Интерстеллар',
        type: 'movie',
        genres: ['Фантастика', 'Драма'],
        year: 2014,
        director: 'Кристофер Нолан',
        actors: 'Мэттью Макконахи',
        description: 'Космическое путешествие',
        status: 'watched',
        rating: 10,
        createdAt: now,
        updatedAt: now,
      );

      final json = item.toJson();
      expect(json['id'], 'media-456');
      expect(json['user_id'], 'user-123');
      expect(json['title'], 'Интерстеллар');
      expect(json['type'], 'movie');
      expect(json['rating'], 10);
      expect(json['status'], 'watched');

      final reconstructed = MediaItem.fromJson(json);
      expect(reconstructed.id, item.id);
      expect(reconstructed.userId, 'user-123');
      expect(reconstructed.title, item.title);
      expect(reconstructed.rating, 10);
    });
  });

  group('WatchRoom Model Tests', () {
    test('fromJson and toJson verification', () {
      final room = WatchRoom(
        id: 'room-789',
        title: 'Вечерний просмотр',
        ownerId: 'owner-1',
        ownerName: 'Киноман',
        movieTitle: 'Дюна',
        movieType: 'movie',
        videoSourceType: 'none',
        videoUrl: 'https://player.example.com/embed/123',
        password: 'secretPassword',
        scheduledAt: DateTime.parse('2026-02-01T20:00:00.000Z'),
        participantCount: 5,
        maxParticipants: 10,
      );

      final json = room.toJson();
      expect(json['id'], 'room-789');
      expect(json['title'], 'Вечерний просмотр');
      expect(json['password'], 'secretPassword');

      final restored = WatchRoom.fromJson(json);
      expect(restored.id, 'room-789');
      expect(restored.hasPassword, true);
      expect(restored.participantCount, 5);
    });
  });

  group('RoomMessage and MovieReview Tests', () {
    test('RoomMessage serialization', () {
      final msg = RoomMessage(
        id: 'msg-1',
        senderId: 'user-1',
        userName: 'Киноман',
        text: 'Какой крутой момент!',
        createdAt: DateTime.parse('2026-02-01T20:15:00.000Z'),
      );

      final json = msg.toJson();
      expect(json['user_name'], 'Киноман');
      expect(json['text'], 'Какой крутой момент!');

      final restored = RoomMessage.fromJson(json);
      expect(restored.id, 'msg-1');
      expect(restored.text, msg.text);
      expect(restored.userName, msg.userName);
    });

    test('MovieReview serialization', () {
      final review = MovieReview(
        id: 'rev-1',
        userId: 'user-1',
        authorName: 'Критик',
        kinopoiskId: 301,
        movieTitle: 'Матрица',
        rating: 9.5,
        title: 'Шедевр',
        text: 'Превосходное кино.',
        createdAt: DateTime.parse('2026-02-01T21:00:00.000Z'),
      );

      final json = review.toJson();
      expect(json['kinopoisk_id'], 301);
      expect(json['rating'], 9.5);
      expect(json['text'], 'Превосходное кино.');

      final restored = MovieReview.fromJson(json);
      expect(restored.text, 'Превосходное кино.');
      expect(restored.rating, 9.5);
      expect(restored.authorName, 'Критик');
    });

    test('FriendRequest serialization and status parsing', () {
      final req = FriendRequest(
        id: 'fr-123',
        senderId: 'user-a',
        receiverId: 'user-b',
        status: FriendRequestStatus.pending,
        createdAt: DateTime.parse('2026-03-01T10:00:00.000Z'),
        updatedAt: DateTime.parse('2026-03-01T10:05:00.000Z'),
      );

      final json = req.toJson();
      expect(json['id'], 'fr-123');
      expect(json['sender_id'], 'user-a');
      expect(json['receiver_id'], 'user-b');
      expect(json['status'], 'pending');

      final restored = FriendRequest.fromJson(json);
      expect(restored.id, 'fr-123');
      expect(restored.senderId, 'user-a');
      expect(restored.receiverId, 'user-b');
      expect(restored.status, FriendRequestStatus.pending);

      final acceptedJson = {...json, 'status': 'accepted'};
      expect(FriendRequest.fromJson(acceptedJson).status, FriendRequestStatus.accepted);

      final rejectedJson = {...json, 'status': 'rejected'};
      expect(FriendRequest.fromJson(rejectedJson).status, FriendRequestStatus.rejected);
    });
  });
}
