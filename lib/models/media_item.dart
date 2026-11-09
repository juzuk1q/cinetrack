class MediaItem {
  final String id;
  final String userId;
  final String title;
  final String type; // movie | series | cartoon
  final List<String> genres;
  final int? year;
  final String? director;
  final String? actors;
  final String? description;
  final String? posterUrl;
  final int? kinopoiskId;
  final String status; // want_to_watch | watching | watched
  final int? rating;
  final String? review;
  final DateTime? plannedDate;
  final DateTime? watchedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MediaItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.type,
    required this.genres,
    this.year,
    this.director,
    this.actors,
    this.description,
    this.posterUrl,
    this.kinopoiskId,
    required this.status,
    this.rating,
    this.review,
    this.plannedDate,
    this.watchedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      genres: (json['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      year: json['year'] as int?,
      director: json['director'] as String?,
      actors: json['actors'] as String?,
      description: json['description'] as String?,
      posterUrl: json['poster_url'] as String?,
      kinopoiskId: json['kinopoisk_id'] as int?,
      status: json['status'] as String? ?? 'want_to_watch',
      rating: json['rating'] as int?,
      review: json['review'] as String?,
      plannedDate: json['planned_date'] != null
          ? DateTime.tryParse(json['planned_date'] as String)
          : null,
      watchedAt: json['watched_at'] != null
          ? DateTime.tryParse(json['watched_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'type': type,
      'genres': genres,
      'year': year,
      'director': director,
      'actors': actors,
      'description': description,
      'poster_url': posterUrl,
      'kinopoisk_id': kinopoiskId,
      'status': status,
      'rating': rating,
      'review': review,
      'planned_date': plannedDate?.toIso8601String().split('T').first,
      'watched_at': watchedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    final map = <String, dynamic>{
      'title': title,
      'type': type,
      'genres': genres,
      'year': year,
      'director': director,
      'actors': actors,
      'description': description,
      'poster_url': posterUrl,
      'kinopoisk_id': kinopoiskId,
      'status': status,
      'rating': rating,
      'review': review,
      'planned_date': plannedDate?.toIso8601String().split('T').first,
      'watched_at': watchedAt?.toIso8601String(),
    };
    if (userId.isNotEmpty) {
      map['user_id'] = userId;
    }
    return map;
  }

  MediaItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? type,
    List<String>? genres,
    int? year,
    String? director,
    String? actors,
    String? description,
    String? posterUrl,
    int? kinopoiskId,
    String? status,
    int? rating,
    String? review,
    DateTime? plannedDate,
    DateTime? watchedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearRating = false,
    bool clearPlannedDate = false,
    bool clearWatchedAt = false,
  }) {
    return MediaItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      type: type ?? this.type,
      genres: genres ?? this.genres,
      year: year ?? this.year,
      director: director ?? this.director,
      actors: actors ?? this.actors,
      description: description ?? this.description,
      posterUrl: posterUrl ?? this.posterUrl,
      kinopoiskId: kinopoiskId ?? this.kinopoiskId,
      status: status ?? this.status,
      rating: clearRating ? null : (rating ?? this.rating),
      review: review ?? this.review,
      plannedDate:
          clearPlannedDate ? null : (plannedDate ?? this.plannedDate),
      watchedAt: clearWatchedAt ? null : (watchedAt ?? this.watchedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MediaItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
