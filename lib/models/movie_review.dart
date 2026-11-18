class MovieReview {
  final String id;
  final int kinopoiskId;
  final String movieTitle;
  final String? userId;
  final String authorName;
  final String authorTitle;
  final double rating;
  final String type; // 'positive' | 'neutral' | 'negative'
  final String title;
  final String text;
  int likes;
  bool isLiked;
  final DateTime createdAt;

  MovieReview({
    required this.id,
    required this.kinopoiskId,
    required this.movieTitle,
    this.userId,
    required this.authorName,
    this.authorTitle = 'Зритель CineTrack 🍿',
    this.rating = 8.0,
    this.type = 'positive',
    required this.title,
    required this.text,
    this.likes = 0,
    this.isLiked = false,
    required this.createdAt,
  });

  String get date {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин назад';
    if (diff.inDays < 1) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}';
  }

  factory MovieReview.fromJson(Map<String, dynamic> json) {
    return MovieReview(
      id: json['id'] as String,
      kinopoiskId: (json['kinopoisk_id'] as num).toInt(),
      movieTitle: json['movie_title'] as String? ?? '',
      userId: json['user_id'] as String?,
      authorName: json['author_name'] as String? ?? 'Зритель',
      authorTitle: json['author_title'] as String? ?? 'Зритель CineTrack 🍿',
      rating: (json['rating'] as num?)?.toDouble() ?? 8.0,
      type: json['type'] as String? ?? 'positive',
      title: json['title'] as String? ?? '',
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
      'movie_title': movieTitle,
      'user_id': userId,
      'author_name': authorName,
      'author_title': authorTitle,
      'rating': rating,
      'type': type,
      'title': title,
      'text': text,
      'likes': likes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
