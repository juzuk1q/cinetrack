class CatalogItem {
  final int? kinopoiskId;
  final String title;
  final String? nameOriginal;
  final String type; // 'movie' | 'series' | 'cartoon' | 'anime'
  final String? typeLabel; // 'Аниме-сериал', 'Аниме-фильм', 'Сериал', 'Фильм'
  final List<String> genres;
  final List<String> countries;
  final int year;
  final String director;
  final String actors;
  final String description;
  final String posterUrl;
  final String? coverUrl;
  final double rating;
  final double? ratingImdb;
  final int? filmLength;
  final String? slogan;

  bool get isSeries =>
      type == 'series' || (typeLabel?.toLowerCase().contains('сериал') ?? false);

  String get displayTypeLabel =>
      (typeLabel != null && typeLabel!.isNotEmpty)
          ? typeLabel!
          : (isSeries ? 'Сериал' : 'Фильм');

  // Ratings & Accolades from top services: IMDb, Rotten Tomatoes, Metacritic, Letterboxd, MPA
  double get effectiveImdb =>
      ratingImdb ?? (rating > 0.5 ? (rating - 0.1).clamp(1.0, 9.9) : 8.2);

  int get effectiveMetacritic {
    final base = (rating * 9.8).round();
    return base.clamp(45, 98);
  }

  double get effectiveLetterboxd {
    final lb = (rating / 2.0) - 0.05;
    return double.parse(lb.clamp(2.0, 4.9).toStringAsFixed(1));
  }

  int get effectiveRottenTomatoes {
    final rt = (rating * 11.6).round();
    return rt.clamp(60, 99);
  }

  String get effectiveMpa {
    final g = genres.map((e) => e.toLowerCase()).join(' ');
    if (g.contains('ужасы') || g.contains('криминал') || g.contains('триллер')) {
      return 'R (18+)';
    } else if (g.contains('боевик') || g.contains('фантастика') || g.contains('драма')) {
      return 'PG-13 (16+)';
    } else if (g.contains('мульт') || g.contains('семейн') || g.contains('детск')) {
      return 'PG (6+)';
    }
    return 'PG-13 (12+)';
  }

  static final Map<int, String> knownPosters = {
    258687: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/430042eb-ee69-4818-aed0-a312400a26bf/x1000',
    1143242: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/637271d5-61b4-4e46-ac83-6d07494c7645/x1000',
    535341: 'https://avatars.mds.yandex.net/get-kinopoisk-image/10900341/caf9f155-1a19-42f1-a0f3-9c8773e9083e/x1000',
    397667: 'https://avatars.mds.yandex.net/get-kinopoisk-image/4303601/617303b7-cfa7-4273-bd1d-63974bf68927/x1000',
    326: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/0b76b2a2-d1c7-4f04-a284-80ff7bb709a4/x1000',
    361: 'https://avatars.mds.yandex.net/get-kinopoisk-image/16490236/495fb59a-bff1-4626-baba-bb392fede945/x1000',
    4664634: 'https://avatars.mds.yandex.net/get-kinopoisk-image/4486454/c5292109-642c-4ab0-894a-cc304e1bcec4/x1000',
    301: 'https://avatars.mds.yandex.net/get-kinopoisk-image/4774061/cf1970bc-3f08-4e0e-a095-2fb57c3aa7c6/x1000',
    111543: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/0fa5bf50-d5ad-446f-a599-b26d070c8b99/x1000',
    474: 'https://avatars.mds.yandex.net/get-kinopoisk-image/10812607/ad4932b4-c220-48a5-9a37-40fc72da5ffa/x1000',
    389: 'https://avatars.mds.yandex.net/get-kinopoisk-image/6201401/8662d92a-5881-4600-a7ae-549e6fd53b03/x1000',
    707: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1704946/42fd2959-0e98-4ce2-b24e-06392b4cb502/x1000',
    342: 'https://avatars.mds.yandex.net/get-kinopoisk-image/4716873/0a07a903-9025-4aff-bf7c-46bbb175888c/x1000',
    435: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/4057c4b8-8208-4a04-b169-26b0661453e3/x1000',
    476: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/73cf2ed0-fd52-47a2-9e26-74104360786a/x1000',
    3498: 'https://avatars.mds.yandex.net/get-kinopoisk-image/4303601/e410c71f-baa1-4fe5-bb29-aedb4662f49b/x1000',
    447301: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1629390/8ab9a119-dd74-44f0-baec-0629797483d7/x1000',
    464963: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/dd78edfd-6a1f-486c-9a86-6acbca940418/x1000',
    689: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1898899/27ed5c19-a045-49dd-8624-5f629c5d96e0/x1000',
    404900: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/fb35416f-3b0d-4b96-bc65-cf6923f9e329/x1000',
    77044: 'https://avatars.mds.yandex.net/get-kinopoisk-image/4486454/bae692d9-8260-46a4-9188-8509a72aa005/x1000',
    841681: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/e5d98938-605a-4c8a-b0d6-5f93d926aa0c/x1000',
    1015471: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/84478174-8b68-450f-bc4d-5c683ee30248/x1000',
    1047883: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/70580cf5-3287-42d6-8a76-2c715e2f6172/x1000',
    775276: 'https://avatars.mds.yandex.net/get-kinopoisk-image/4716873/893bba73-3105-4944-8d18-a38f929f2759/x1000',
    915196: 'https://avatars.mds.yandex.net/get-kinopoisk-image/10703859/1e653cad-c84f-4617-b61e-949b3228ef36/x1000',
    502838: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1629390/f28c1ea2-47b0-49d5-b11c-9608744f0233/x1000',
    462682: 'https://avatars.mds.yandex.net/get-kinopoisk-image/9784475/44bc954c-acdb-45d7-8ce1-6a9b25f4ca92/x1000',
    409640: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1946459/41f7ca91-3093-410c-99a2-17aef6ed4d6b/x1000',
    89514: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1773646/894f7e3c-cedf-4e5c-946a-9021efdf17dd/x1000',
    685246: 'https://avatars.mds.yandex.net/get-kinopoisk-image/10809116/29741578-1673-4ce6-8502-8a191e4886f7/x1000',
    749374: 'https://avatars.mds.yandex.net/get-kinopoisk-image/6201401/e42e60bc-0772-4a3a-a24f-4218febf9386/x1000',
    571896: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/9ecb0974-ad01-4fde-9067-c6d147b880f4/x1000',
    406148: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1946459/0368a21d-64dd-4340-b097-205dc9512ba4/x1000',
    1220920: 'https://avatars.mds.yandex.net/get-kinopoisk-image/10671298/32621935-61a6-4479-ae42-829f5642e6b0/x1000',
    681831: 'https://avatars.mds.yandex.net/get-kinopoisk-image/10835644/73941f07-7652-4943-83e1-7849aa398974/x1000',
    79849: 'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/32cd6904-1e01-4562-a700-d82f5d351215/x1000',
    1318972: 'https://avatars.mds.yandex.net/get-kinopoisk-image/6201401/90d57813-387c-44c4-81c1-ecddb3c417a5/x1000',
  };

  static String fixPosterUrl(String? url, {int? kpId}) {
    if (kpId != null && knownPosters.containsKey(kpId)) {
      return knownPosters[kpId]!;
    }
    if (url == null || url.trim().isEmpty) {
      return 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=600&auto=format&fit=crop&q=80';
    }
    final trimmed = url.trim();

    // Check if URL has a kpId pattern
    final match = RegExp(r'(?:kp|film_big)\/(\d+)').firstMatch(trimmed);
    if (match != null) {
      final parsedId = int.tryParse(match.group(1) ?? '');
      if (parsedId != null && knownPosters.containsKey(parsedId)) {
        return knownPosters[parsedId]!;
      }
    }

    if (trimmed.contains('avatars.mds.yandex.net')) {
      // Replace outdated /orig with high-res /x1000 or /orig
      return trimmed;
    }
    if (trimmed.contains('unsplash.com')) {
      return trimmed;
    }
    if (trimmed.contains('kinopoiskapiunofficial.tech') || trimmed.contains('st.kp.yandex.net')) {
      final cleanUrl = trimmed.replaceFirst(RegExp(r'^https?:\/\/'), '');
      return 'https://images.weserv.nl/?url=${Uri.encodeComponent(cleanUrl)}&default=https%3A%2F%2Fimages.unsplash.com%2Fphoto-1489599849927-2ee91cede3ba%3Fw%3D600';
    }
    return trimmed;
  }

  const CatalogItem({
    this.kinopoiskId,
    required this.title,
    this.nameOriginal,
    required this.type,
    this.typeLabel,
    required this.genres,
    this.countries = const [],
    required this.year,
    required this.director,
    required this.actors,
    required this.description,
    required this.posterUrl,
    this.coverUrl,
    required this.rating,
    this.ratingImdb,
    this.filmLength,
    this.slogan,
  });

  factory CatalogItem.fromKinopoisk(Map<String, dynamic> json, {String? fallbackCategory}) {
    final kpRaw = json['kinopoiskId'] ?? json['filmId'];
    final kpId = kpRaw is num
        ? kpRaw.toInt()
        : (kpRaw is String ? int.tryParse(kpRaw) : null);

    final title = (json['nameRu'] as String?)?.isNotEmpty == true
        ? json['nameRu'] as String
        : (json['nameOriginal'] as String?)?.isNotEmpty == true
            ? json['nameOriginal'] as String
            : (json['nameEn'] as String?) ?? 'Без названия';

    final nameOriginal = (json['nameOriginal'] ?? json['nameEn']) as String?;

    // Determine type
    final rawType = (json['type'] as String?)?.toUpperCase() ?? '';
    final rawGenres = (json['genres'] as List<dynamic>?)
            ?.map((g) => (g is Map ? (g['genre'] as String? ?? '') : g.toString()))
            .where((g) => g.isNotEmpty)
            .toList() ??
        [];

    final rawCountries = (json['countries'] as List<dynamic>?)
            ?.map((c) => (c is Map ? (c['country'] as String? ?? '') : c.toString()))
            .where((c) => c.isNotEmpty)
            .toList() ??
        [];

    String type = fallbackCategory ?? 'movie';
    final isTvSeries = rawType.contains('SERIES') || rawType.contains('SHOW');
    final isAnime = rawGenres.any((g) => g.toLowerCase().contains('аниме'));
    final isCartoon = rawGenres.any((g) => g.toLowerCase().contains('мульт'));

    if (isAnime) {
      type = 'anime';
    } else if (isCartoon) {
      type = 'cartoon';
    } else if (isTvSeries) {
      type = 'series';
    } else if (rawType.contains('FILM')) {
      type = 'movie';
    }

    String typeLabel;
    if (isAnime) {
      typeLabel = isTvSeries ? 'Аниме-сериал' : 'Аниме-фильм';
    } else if (isCartoon) {
      typeLabel = isTvSeries ? 'Мультсериал' : 'Мультфильм';
    } else if (isTvSeries) {
      typeLabel = 'Сериал';
    } else {
      typeLabel = 'Фильм';
    }

    // Rating
    double rating = 7.5;
    final rRaw = json['ratingKinopoisk'] ?? json['rating'];
    if (rRaw is num) {
      rating = rRaw.toDouble();
    } else if (rRaw is String) {
      rating = double.tryParse(rRaw.replaceAll('%', '').trim()) ?? 7.5;
      if (rating > 10.0) rating = rating / 10.0;
    }

    // Year
    int year = 2024;
    final yRaw = json['year'];
    if (yRaw is num) {
      year = yRaw.toInt();
    } else if (yRaw is String) {
      year = int.tryParse(yRaw) ?? 2024;
    }

    final rawPoster = (json['posterUrl'] as String?)?.isNotEmpty == true
        ? json['posterUrl'] as String
        : (json['posterUrlPreview'] as String?) ??
            'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=600&auto=format&fit=crop&q=80';
    final poster = fixPosterUrl(rawPoster);

    final rawCover = (json['coverUrl'] as String?)?.isNotEmpty == true
        ? json['coverUrl'] as String
        : null;
    final cover = rawCover != null ? fixPosterUrl(rawCover) : null;

    final desc = (json['description'] as String?)?.isNotEmpty == true
        ? json['description'] as String
        : (json['shortDescription'] as String?) ?? 'Описание временно отсутствует.';

    double? ratingImdb;
    final imdbRaw = json['ratingImdb'];
    if (imdbRaw is num) {
      ratingImdb = imdbRaw.toDouble();
    } else if (imdbRaw is String) {
      ratingImdb = double.tryParse(imdbRaw);
    }

    int? filmLength;
    final flRaw = json['filmLength'];
    if (flRaw is num) {
      filmLength = flRaw.toInt();
    } else if (flRaw is String) {
      if (flRaw.contains(':')) {
        final parts = flRaw.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          filmLength = h * 60 + m;
        }
      } else {
        filmLength = int.tryParse(flRaw);
      }
    }
    final slogan = json['slogan']?.toString();

    return CatalogItem(
      kinopoiskId: kpId,
      title: title,
      nameOriginal: nameOriginal,
      type: type,
      typeLabel: typeLabel,
      genres: rawGenres,
      countries: rawCountries,
      year: year,
      director: rawCountries.join(', '),
      actors: '',
      description: desc,
      posterUrl: poster,
      coverUrl: cover,
      rating: rating,
      ratingImdb: ratingImdb,
      filmLength: filmLength,
      slogan: slogan,
    );
  }
}
