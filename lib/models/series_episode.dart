class SeriesEpisode {
  final int seasonNumber;
  final int episodeNumber;
  final String? nameRu;
  final String? nameEn;
  final String? synopsis;
  final String? releaseDate;

  const SeriesEpisode({
    required this.seasonNumber,
    required this.episodeNumber,
    this.nameRu,
    this.nameEn,
    this.synopsis,
    this.releaseDate,
  });

  /// Checks if episode has already aired based on releaseDate
  bool get isAired {
    if (releaseDate == null || releaseDate!.trim().isEmpty) return true;
    try {
      final date = DateTime.tryParse(releaseDate!.trim());
      if (date != null) {
        final now = DateTime.now();
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
        return date.isBefore(endOfToday);
      }
    } catch (_) {}
    return true;
  }

  String? get formattedReleaseDate {
    if (releaseDate == null || releaseDate!.trim().isEmpty) return null;
    try {
      final date = DateTime.tryParse(releaseDate!.trim());
      if (date != null) {
        const months = [
          'янв',
          'фев',
          'мар',
          'апр',
          'мая',
          'июн',
          'июл',
          'авг',
          'сен',
          'окт',
          'ноя',
          'дек'
        ];
        return '${date.day} ${months[date.month - 1]} ${date.year}';
      }
    } catch (_) {}
    return releaseDate;
  }

  String get displayTitle {
    if (nameRu != null && nameRu!.trim().isNotEmpty) {
      return '$episodeNumber. $nameRu';
    }
    if (nameEn != null && nameEn!.trim().isNotEmpty) {
      return '$episodeNumber. $nameEn';
    }
    return '$episodeNumber серия';
  }

  factory SeriesEpisode.fromJson(Map<String, dynamic> json) {
    return SeriesEpisode(
      seasonNumber: json['seasonNumber'] as int? ?? 1,
      episodeNumber: json['episodeNumber'] as int? ?? 1,
      nameRu: (json['nameRu'] as String?)?.trim(),
      nameEn: (json['nameEn'] as String?)?.trim(),
      synopsis: (json['synopsis'] as String?)?.trim(),
      releaseDate: (json['releaseDate'] as String?)?.trim(),
    );
  }
}

class SeriesSeason {
  final int number;
  final List<SeriesEpisode> episodes;

  const SeriesSeason({
    required this.number,
    required this.episodes,
  });

  String get displayTitle => 'Сезон $number';

  int get totalCount => episodes.length;
  int get airedCount => episodes.where((e) => e.isAired).length;
  List<SeriesEpisode> get airedEpisodes =>
      episodes.where((e) => e.isAired).toList();
  bool get hasUpcoming => airedCount < totalCount;

  factory SeriesSeason.fromJson(Map<String, dynamic> json) {
    final epList = (json['episodes'] as List<dynamic>?) ?? [];
    return SeriesSeason(
      number: json['number'] as int? ?? 1,
      episodes: epList
          .whereType<Map<String, dynamic>>()
          .map((e) => SeriesEpisode.fromJson(e))
          .toList(),
    );
  }
}
