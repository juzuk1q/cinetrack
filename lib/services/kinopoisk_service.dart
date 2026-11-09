import 'dart:convert';
import 'package:http/http.dart' as http;

import '../data/curated_catalog.dart';
import '../models/catalog_item.dart';

class KinopoiskService {
  static const String _baseUrl = 'https://kinopoiskapiunofficial.tech';
  static const String _apiKey = '94660b64-04f7-4aad-92f2-bf025a953f99';

  static final Map<String, List<CatalogItem>> _cache = {};

  static Map<String, String> get _headers => {
        'X-API-KEY': _apiKey,
        'Content-Type': 'application/json',
      };

  // Standard Lordfilm genre mappings to Kinopoisk API genre IDs
  static const Map<String, int> genreMap = {
    'Все жанры': 0,
    'Биографические': 8,
    'Боевики': 11,
    'Вестерны': 10,
    'Военные': 14,
    'Детективы': 5,
    'Детские': 33,
    'Документальные': 22,
    'Драмы': 2,
    'Исторические': 15,
    'Комедии': 13,
    'Короткометражки': 23,
    'Криминал': 3,
    'Мелодрамы': 4,
    'Музыкальные': 16,
    'Мюзиклы': 20,
    'Нуар': 9,
    'Приключения': 7,
    'Семейные': 19,
    'Спорт': 21,
    'Триллеры': 1,
    'Ужасы': 17,
    'Фантастика': 6,
    'Фэнтези': 12,
    'Мультфильмы': 18,
    'Аниме': 24,
  };

  // Standard Lordfilm country mappings to Kinopoisk API country IDs
  static const Map<String, int> countryMap = {
    'Все страны': 0,
    'США': 1,
    'Россия': 34,
    'Франция': 3,
    'Великобритания': 5,
    'Япония': 16,
    'Южная Корея (Дорамы)': 49,
    'Турция': 44,
    'Индия': 7,
    'Германия': 9,
    'Италия': 10,
    'Испания': 8,
  };

  /// Fetch top popular titles
  Future<List<CatalogItem>> getPopular({int page = 1}) async {
    final cacheKey = 'popular_$page';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/v2.2/films/collections?type=TOP_POPULAR_ALL&page=$page');
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> items = data['items'] ?? [];
        final results = <CatalogItem>[];
        for (final it in items) {
          try {
            if (it is Map<String, dynamic>) {
              results.add(CatalogItem.fromKinopoisk(it));
            }
          } catch (_) {}
        }

        if (results.isNotEmpty) {
          _cache[cacheKey] = results;
          return results;
        }
      }
    } catch (_) {}

    return CuratedCatalog.items;
  }

  /// Search films by keyword
  Future<List<CatalogItem>> search(String keyword, {int page = 1}) async {
    if (keyword.trim().isEmpty) return getPopular(page: page);

    final cacheKey = 'search_${keyword.trim().toLowerCase()}_$page';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final uri = Uri.parse(
          '$_baseUrl/api/v2.1/films/search-by-keyword?keyword=${Uri.encodeQueryComponent(keyword.trim())}&page=$page');
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> items = data['films'] ?? data['items'] ?? [];
        final results = <CatalogItem>[];
        for (final it in items) {
          try {
            if (it is Map<String, dynamic>) {
              results.add(CatalogItem.fromKinopoisk(it));
            }
          } catch (_) {}
        }

        if (results.isNotEmpty) {
          _cache[cacheKey] = results;
          return results;
        }
      }
    } catch (_) {}

    // Fallback: search in curated catalog
    final q = keyword.toLowerCase();
    return CuratedCatalog.items.where((i) {
      return i.title.toLowerCase().contains(q) ||
          i.director.toLowerCase().contains(q) ||
          i.genres.any((g) => g.toLowerCase().contains(q));
    }).toList();
  }

  /// Fetch full film details by Kinopoisk ID (e.g. 301 for Matrix)
  Future<CatalogItem?> getFilmById(int id) async {
    final cacheKey = 'film_$id';
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!.first;
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/v2.2/films/$id');
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final item = CatalogItem.fromKinopoisk(data);
        _cache[cacheKey] = [item];
        return item;
      }
    } catch (_) {}

    return null;
  }

  /// Filter films by category, genre, country, and year
  Future<List<CatalogItem>> getByCategory({
    required String category, // 'all', 'movie', 'series', 'cartoon', 'anime'
    int? genreId,
    int? countryId,
    int? year,
    int page = 1,
  }) async {
    final cacheKey = 'cat_${category}_g${genreId ?? 0}_c${countryId ?? 0}_y${year ?? 0}_p$page';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final queryParams = <String, String>{
        'order': 'NUM_VOTE',
        'page': page.toString(),
      };

      // Type mapping
      if (category == 'movie') {
        queryParams['type'] = 'FILM';
      } else if (category == 'series') {
        queryParams['type'] = 'TV_SERIES';
      } else if (category == 'cartoon') {
        // Cartoon is genre 18
        if (genreId == null || genreId == 0) {
          queryParams['genres'] = '18';
        }
      } else if (category == 'anime') {
        // Anime is genre 24
        if (genreId == null || genreId == 0) {
          queryParams['genres'] = '24';
        }
      } else {
        queryParams['type'] = 'ALL';
      }

      // Explicit genre
      if (genreId != null && genreId > 0) {
        queryParams['genres'] = genreId.toString();
      }

      // Explicit country
      if (countryId != null && countryId > 0) {
        queryParams['countries'] = countryId.toString();
      }

      // Explicit year
      if (year != null && year > 0) {
        queryParams['yearFrom'] = year.toString();
        queryParams['yearTo'] = year.toString();
      }

      final uri = Uri.parse('$_baseUrl/api/v2.2/films').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> items = data['items'] ?? [];
        final results = <CatalogItem>[];
        for (final it in items) {
          try {
            if (it is Map<String, dynamic>) {
              results.add(CatalogItem.fromKinopoisk(
                it,
                fallbackCategory: category,
              ));
            }
          } catch (_) {}
        }

        if (results.isNotEmpty) {
          _cache[cacheKey] = results;
          return results;
        }
      }
    } catch (_) {}

    // Fallback: local filtering
    return CuratedCatalog.items.where((item) {
      if (category != 'all' && item.type != category) return false;
      if (year != null && year > 0 && item.year != year) return false;
      if (genreId != null && genreId > 0) {
        final genreEntry = genreMap.entries.where((e) => e.value == genreId);
        if (genreEntry.isNotEmpty) {
          final gKey = genreEntry.first.key.toLowerCase();
          final stem = gKey.length > 4 ? gKey.substring(0, 4) : gKey;
          if (!item.genres.any((g) => g.toLowerCase().contains(stem))) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  /// Fetch stills / backstage frames for a film
  Future<List<String>> getFilmImages(int id) async {
    final cacheKey = 'images_$id';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!.map((e) => e.posterUrl).toList();
    }

    try {
      final uri = Uri.parse('$_baseUrl/api/v2.2/films/$id/images?type=STILL&page=1');
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> items = data['items'] ?? [];
        final urls = items
            .map((item) => (item['imageUrl'] ?? item['previewUrl']) as String? ?? '')
            .where((u) => u.isNotEmpty)
            .toList();

        if (urls.isNotEmpty) {
          return urls;
        }
      }
    } catch (_) {}

    return [];
  }

  /// Fetch trailers and videos for a film
  Future<List<Map<String, dynamic>>> getFilmVideos(int id) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/v2.2/films/$id/videos');
      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> items = data['items'] ?? [];
        return items.cast<Map<String, dynamic>>();
      }
    } catch (_) {}

    return [];
  }
}
