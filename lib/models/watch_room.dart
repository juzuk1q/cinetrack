import 'room_message.dart';

class WatchRoom {
  final String id;
  final String title;
  final String movieTitle;
  final String movieType; // 'movie' | 'series' | 'cartoon'
  final String? moviePoster;
  final int? movieYear;
  final String status; // 'preparing' | 'watching' | 'finished'
  final DateTime scheduledAt;
  final String ownerName;
  final int participantCount;
  final List<RoomMessage> messages;

  const WatchRoom({
    required this.id,
    required this.title,
    required this.movieTitle,
    required this.movieType,
    this.moviePoster,
    this.movieYear,
    required this.status,
    required this.scheduledAt,
    required this.ownerName,
    required this.participantCount,
    required this.messages,
  });

  WatchRoom copyWith({
    String? id,
    String? title,
    String? movieTitle,
    String? movieType,
    String? moviePoster,
    int? movieYear,
    String? status,
    DateTime? scheduledAt,
    String? ownerName,
    int? participantCount,
    List<RoomMessage>? messages,
  }) {
    return WatchRoom(
      id: id ?? this.id,
      title: title ?? this.title,
      movieTitle: movieTitle ?? this.movieTitle,
      movieType: movieType ?? this.movieType,
      moviePoster: moviePoster ?? this.moviePoster,
      movieYear: movieYear ?? this.movieYear,
      status: status ?? this.status,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      ownerName: ownerName ?? this.ownerName,
      participantCount: participantCount ?? this.participantCount,
      messages: messages ?? this.messages,
    );
  }
}
