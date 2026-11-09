import 'room_message.dart';

class WatchRoom {
  final String id;
  final String title;
  final String movieTitle;
  final String movieType; // 'movie' | 'series' | 'cartoon' | 'anime'
  final String? moviePoster;
  final int? movieYear;
  final String status; // 'preparing' | 'watching' | 'finished'
  final DateTime scheduledAt;
  final String ownerName;
  final String? ownerId;
  final int? kinopoiskId;
  final bool allowGuestControl;
  final int participantCount;
  final List<RoomMessage> messages;
  final String videoSourceType; // 'none' | 'catalog' | 'kodik' | 'vk' | 'youtube' | 'url' | 'file'
  final String? videoUrl;
  final String? videoFileName;
  final double currentPosition;
  final bool isPlaying;
  final String? password;
  final int? maxParticipants;
  final List<Map<String, String>> participants;

  const WatchRoom({
    required this.id,
    required this.title,
    this.movieTitle = 'Источник не выбран',
    this.movieType = 'movie',
    this.moviePoster,
    this.movieYear,
    this.status = 'watching',
    required this.scheduledAt,
    required this.ownerName,
    this.ownerId,
    this.kinopoiskId,
    this.allowGuestControl = false,
    this.participantCount = 1,
    this.messages = const [],
    this.videoSourceType = 'none',
    this.videoUrl,
    this.videoFileName,
    this.currentPosition = 0.0,
    this.isPlaying = false,
    this.password,
    this.maxParticipants,
    this.participants = const [],
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
    String? ownerId,
    int? kinopoiskId,
    bool? allowGuestControl,
    int? participantCount,
    List<RoomMessage>? messages,
    String? videoSourceType,
    String? videoUrl,
    String? videoFileName,
    double? currentPosition,
    bool? isPlaying,
    String? password,
    int? maxParticipants,
    List<Map<String, String>>? participants,
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
      ownerId: ownerId ?? this.ownerId,
      kinopoiskId: kinopoiskId ?? this.kinopoiskId,
      allowGuestControl: allowGuestControl ?? this.allowGuestControl,
      participantCount: participantCount ?? this.participantCount,
      messages: messages ?? this.messages,
      videoSourceType: videoSourceType ?? this.videoSourceType,
      videoUrl: videoUrl ?? this.videoUrl,
      videoFileName: videoFileName ?? this.videoFileName,
      currentPosition: currentPosition ?? this.currentPosition,
      isPlaying: isPlaying ?? this.isPlaying,
      password: password ?? this.password,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      participants: participants ?? this.participants,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'movie_title': movieTitle,
      'movie_type': movieType,
      'movie_poster': moviePoster,
      'movie_year': movieYear,
      'status': status,
      'scheduled_at': scheduledAt.toIso8601String(),
      'owner_name': ownerName,
      'owner_id': ownerId,
      'kinopoisk_id': kinopoiskId,
      'allow_guest_control': allowGuestControl,
      'participant_count': participantCount,
      'messages': messages.map((m) => m.toJson()).toList(),
      'video_source_type': videoSourceType,
      'video_url': videoUrl,
      'video_file_name': videoFileName,
      'current_position': currentPosition,
      'is_playing': isPlaying,
      'password': password,
      'max_participants': maxParticipants,
      'participants': participants,
    };
  }

  factory WatchRoom.fromJson(Map<String, dynamic> json) {
    final rawParts = json['participants'] as List<dynamic>?;
    final List<Map<String, String>> parts = [];
    if (rawParts != null) {
      for (final p in rawParts) {
        if (p is Map) {
          parts.add(p.map((k, v) => MapEntry(k.toString(), v.toString())));
        }
      }
    }

    return WatchRoom(
      id: json['id'] as String,
      title: json['title'] as String,
      movieTitle: json['movie_title'] as String? ?? 'Источник не выбран',
      movieType: json['movie_type'] as String? ?? 'movie',
      moviePoster: json['movie_poster'] as String?,
      movieYear: json['movie_year'] as int?,
      status: json['status'] as String? ?? 'watching',
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : DateTime.now(),
      ownerName: json['owner_name'] as String? ?? 'Организатор',
      ownerId: json['owner_id'] as String?,
      kinopoiskId: json['kinopoisk_id'] as int?,
      allowGuestControl: json['allow_guest_control'] as bool? ?? false,
      participantCount: json['participant_count'] as int? ?? 1,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => RoomMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      videoSourceType: json['video_source_type'] as String? ?? 'none',
      videoUrl: json['video_url'] as String?,
      videoFileName: json['video_file_name'] as String?,
      currentPosition: (json['current_position'] as num?)?.toDouble() ?? 0.0,
      isPlaying: json['is_playing'] as bool? ?? false,
      password: json['password'] as String?,
      maxParticipants: json['max_participants'] as int?,
      participants: parts,
    );
  }
}
