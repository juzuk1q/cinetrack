import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/catalog_item.dart';
import '../services/kinopoisk_service.dart';

class CatalogFilterState {
  final String category; // 'all', 'movie', 'series', 'cartoon', 'anime'
  final String genre;
  final String country;
  final int? year;
  final String searchQuery;

  const CatalogFilterState({
    this.category = 'all',
    this.genre = 'Все жанры',
    this.country = 'Все страны',
    this.year,
    this.searchQuery = '',
  });

  CatalogFilterState copyWith({
    String? category,
    String? genre,
    String? country,
    int? year,
    bool clearYear = false,
    String? searchQuery,
  }) {
    return CatalogFilterState(
      category: category ?? this.category,
      genre: genre ?? this.genre,
      country: country ?? this.country,
      year: clearYear ? null : (year ?? this.year),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool get hasActiveFilters =>
      genre != 'Все жанры' || country != 'Все страны' || year != null;
}

class CatalogState {
  final bool isLoading;
  final List<CatalogItem> items;
  final String? error;
  final CatalogFilterState filter;

  const CatalogState({
    this.isLoading = false,
    this.items = const [],
    this.error,
    this.filter = const CatalogFilterState(),
  });

  CatalogState copyWith({
    bool? isLoading,
    List<CatalogItem>? items,
    String? error,
    CatalogFilterState? filter,
  }) {
    return CatalogState(
      isLoading: isLoading ?? this.isLoading,
      items: items ?? this.items,
      error: error,
      filter: filter ?? this.filter,
    );
  }
}

class CatalogNotifier extends StateNotifier<CatalogState> {
  final KinopoiskService _service;

  CatalogNotifier(this._service) : super(const CatalogState(isLoading: true)) {
    loadCatalog();
  }

  Future<void> loadCatalog() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final filter = state.filter;
      List<CatalogItem> results;

      if (filter.searchQuery.trim().isNotEmpty) {
        var rawResults = await _service.search(filter.searchQuery.trim());

        // Respect active category filter (e.g. Anime only shows anime, Series only shows series)
        if (filter.category != 'all') {
          rawResults = rawResults.where((item) {
            if (filter.category == 'anime') {
              return item.type == 'anime' ||
                  item.genres.any((g) => g.toLowerCase().contains('аниме'));
            } else if (filter.category == 'series') {
              return item.type == 'series' ||
                  item.genres.any((g) => g.toLowerCase().contains('сериал'));
            } else if (filter.category == 'cartoon') {
              return item.type == 'cartoon' ||
                  item.genres.any((g) => g.toLowerCase().contains('мульт'));
            } else if (filter.category == 'movie') {
              return item.type == 'movie' &&
                  !item.genres.any((g) =>
                      g.toLowerCase().contains('аниме') ||
                      g.toLowerCase().contains('мульт'));
            }
            return true;
          }).toList();
        }

        // Re-rank by relevance so exact keyword match appears first
        final q = filter.searchQuery.trim().toLowerCase();
        rawResults.sort((a, b) {
          final aTitle = a.title.toLowerCase();
          final bTitle = b.title.toLowerCase();
          final aStarts = aTitle.startsWith(q) ? 1 : 0;
          final bStarts = bTitle.startsWith(q) ? 1 : 0;
          if (aStarts != bStarts) return bStarts.compareTo(aStarts);

          final aContains = aTitle.contains(q) ? 1 : 0;
          final bContains = bTitle.contains(q) ? 1 : 0;
          if (aContains != bContains) return bContains.compareTo(aContains);

          return b.rating.compareTo(a.rating);
        });

        results = rawResults;
      } else {
        final genreId = KinopoiskService.genreMap[filter.genre] ?? 0;
        final countryId = KinopoiskService.countryMap[filter.country] ?? 0;

        results = await _service.getByCategory(
          category: filter.category,
          genreId: genreId > 0 ? genreId : null,
          countryId: countryId > 0 ? countryId : null,
          year: filter.year,
        );
      }

      state = state.copyWith(isLoading: false, items: results);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setCategory(String category) {
    if (state.filter.category == category) return;
    state = state.copyWith(
      filter: state.filter.copyWith(category: category, searchQuery: ''),
    );
    loadCatalog();
  }

  void setGenre(String genre) {
    state = state.copyWith(filter: state.filter.copyWith(genre: genre));
    loadCatalog();
  }

  void setCountry(String country) {
    state = state.copyWith(filter: state.filter.copyWith(country: country));
    loadCatalog();
  }

  void setYear(int? year) {
    state = state.copyWith(
      filter: state.filter.copyWith(year: year, clearYear: year == null),
    );
    loadCatalog();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(filter: state.filter.copyWith(searchQuery: query));
    loadCatalog();
  }

  void resetFilters() {
    state = state.copyWith(
      filter: state.filter.copyWith(
        genre: 'Все жанры',
        country: 'Все страны',
        clearYear: true,
        searchQuery: '',
      ),
    );
    loadCatalog();
  }
}

final kinopoiskServiceProvider = Provider<KinopoiskService>((ref) {
  return KinopoiskService();
});

final catalogProvider =
    StateNotifierProvider<CatalogNotifier, CatalogState>((ref) {
  final service = ref.watch(kinopoiskServiceProvider);
  return CatalogNotifier(service);
});
