import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../core/supabase_client.dart';
import '../data/curated_catalog.dart';
import '../models/catalog_item.dart';
import '../models/series_episode.dart';

class KinopoiskService {
  static final Map<String, List<CatalogItem>> _cache = {};
  static final Map<String, List<SeriesSeason>> _seasonsCache = {};

  /// Invoke kinopoisk-proxy Supabase Edge Function
  static Future<dynamic> _fetchProxy(
    String path, [
    Map<String, String>? params,
  ]) async {
    try {
      final response = await supabase.functions.invoke(
        'kinopoisk-proxy',
        body: {
          'path': path,
          if (params != null && params.isNotEmpty) 'params': params,
        },
      );

      if (response.status == 200) {
        final data = response.data;
        if (data is Map<String, dynamic> || data is List<dynamic>) {
          return data;
        }
        if (data is String) {
          return jsonDecode(data);
        }
      } else {
        debugPrint('Kinopoisk proxy returned status ${response.status}: ${response.data}');
      }
    } catch (e) {
      debugPrint('Kinopoisk proxy request failed: $e');
    }
    return null;
  }

  // Standard Lordfilm genre mappings to Kinopoisk API genre IDs
  static const Map<String, int> genreMap = {
    'Все жанры': 0,
    'Боевик': 11,
    'Приключения': 7,
    'Комедия': 13,
    'Драма': 2,
    'Фантастика': 6,
    'Фэнтези': 5,
    'Триллер': 1,
    'Ужасы': 17,
    'Детектив': 19,
    'Криминал': 3,
    'Мелодрама': 4,
    'Военный': 14,
    'Исторический': 15,
    'Документальный': 22,
    'Семейный': 29,
    'Биография': 8,
    'Вестерн': 10,
    'Аниме': 24,
    'Мультфильм': 18,
    'Мюзикл': 9,
    'Спорт': 21,
  };

  // Standard country mappings
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
      final data = await _fetchProxy(
        '/api/v2.2/films/collections',
        {'type': 'TOP_POPULAR_ALL', 'page': page.toString()},
      );

      if (data is Map<String, dynamic>) {
        final List<dynamic> items = data['items'] ?? [];
        final results = <CatalogItem>[];
        for (final it in items) {
          try {
            if (it is Map<String, dynamic>) {
              results.add(CatalogItem.fromKinopoisk(it));
            }
          } catch (e) {
        debugPrint('KinopoiskService handled error: $e');
      }
        }

        if (results.isNotEmpty) {
          _cache[cacheKey] = results;
          return results;
        }
      }
    } catch (e) {
        debugPrint('KinopoiskService handled error: $e');
      }

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
      final data = await _fetchProxy(
        '/api/v2.1/films/search-by-keyword',
        {'keyword': keyword.trim(), 'page': page.toString()},
      );

      if (data is Map<String, dynamic>) {
        final List<dynamic> items = data['films'] ?? data['items'] ?? [];
        final results = <CatalogItem>[];
        for (final it in items) {
          try {
            if (it is Map<String, dynamic>) {
              results.add(CatalogItem.fromKinopoisk(it));
            }
          } catch (e) {
        debugPrint('KinopoiskService handled error: $e');
      }
        }

        if (results.isNotEmpty) {
          _cache[cacheKey] = results;
          return results;
        }
      }
    } catch (e) {
        debugPrint('KinopoiskService handled error: $e');
      }

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
      final data = await _fetchProxy('/api/v2.2/films/$id');

      if (data is Map<String, dynamic>) {
        final item = CatalogItem.fromKinopoisk(data);
        _cache[cacheKey] = [item];
        return item;
      }
    } catch (e) {
        debugPrint('KinopoiskService handled error: $e');
      }

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
        if (genreId == null || genreId == 0) {
          queryParams['genres'] = '18';
        }
      } else if (category == 'anime') {
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

      final data = await _fetchProxy('/api/v2.2/films', queryParams);

      if (data is Map<String, dynamic>) {
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
          } catch (e) {
        debugPrint('KinopoiskService handled error: $e');
      }
        }

        if (results.isNotEmpty) {
          _cache[cacheKey] = results;
          return results;
        }
      }
    } catch (e) {
        debugPrint('KinopoiskService handled error: $e');
      }

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
      final data = await _fetchProxy(
        '/api/v2.2/films/$id/images',
        {'type': 'STILL', 'page': '1'},
      );

      if (data is Map<String, dynamic>) {
        final List<dynamic> items = data['items'] ?? [];
        final urls = items
            .map((item) => (item['imageUrl'] ?? item['previewUrl']) as String? ?? '')
            .where((u) => u.isNotEmpty)
            .toList();

        if (urls.isNotEmpty) {
          return urls;
        }
      }
    } catch (e) {
        debugPrint('KinopoiskService handled error: $e');
      }

    return [];
  }

  /// Fetch trailers and videos for a film
  Future<List<Map<String, dynamic>>> getFilmVideos(int id) async {
    try {
      final data = await _fetchProxy('/api/v2.2/films/$id/videos');

      if (data is Map<String, dynamic>) {
        final List<dynamic> items = data['items'] ?? [];
        return items.cast<Map<String, dynamic>>();
      }
    } catch (e) {
        debugPrint('KinopoiskService handled error: $e');
      }

    return [];
  }

  /// Fetch series seasons and episodes by Kinopoisk ID
  Future<List<SeriesSeason>> getSeasons(int id) async {
    final cacheKey = 'seasons_$id';
    if (_seasonsCache.containsKey(cacheKey)) {
      return _seasonsCache[cacheKey]!;
    }

    try {
      final data = await _fetchProxy('/api/v2.2/films/$id/seasons');

      if (data is Map<String, dynamic>) {
        final List<dynamic> items = data['items'] ?? [];
        final seasons = items
            .whereType<Map<String, dynamic>>()
            .map((s) => SeriesSeason.fromJson(s))
            .where((s) => s.episodes.isNotEmpty)
            .toList();

        seasons.sort((a, b) => a.number.compareTo(b.number));

        if (seasons.isNotEmpty) {
          _seasonsCache[cacheKey] = seasons;
          return seasons;
        }
      }
    } catch (e) {
        debugPrint('KinopoiskService handled error: $e');
      }

    return [];
  }
}
