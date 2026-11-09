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
