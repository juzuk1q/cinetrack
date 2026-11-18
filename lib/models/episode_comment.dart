class EpisodeComment {
  final String id;
  final int kinopoiskId;
  final int episode;
  final int season;
  final String? timecode;
  final String? userId;
  final String authorName;
  final String text;
  int likes;
  bool isLiked;
  final DateTime createdAt;

  EpisodeComment({
    required this.id,
    required this.kinopoiskId,
    this.episode = 1,
    this.season = 1,
    this.timecode,
    this.userId,
    required this.authorName,
    required this.text,
    this.likes = 0,
    this.isLiked = false,
    required this.createdAt,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}';
  }

  factory EpisodeComment.fromJson(Map<String, dynamic> json) {
    return EpisodeComment(
      id: json['id'] as String,
      kinopoiskId: (json['kinopoisk_id'] as num).toInt(),
      episode: (json['episode'] as num?)?.toInt() ?? 1,
      season: (json['season'] as num?)?.toInt() ?? 1,
      timecode: json['timecode'] as String?,
      userId: json['user_id'] as String?,
      authorName: json['author_name'] as String? ?? 'Зритель',
      text: json['text'] as String? ?? '',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kinopoisk_id': kinopoiskId,
      'episode': episode,
      'season': season,
      'timecode': timecode,
      'user_id': userId,
      'author_name': authorName,
      'text': text,
      'likes': likes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
