import 'package:cinetrack/models/catalog_item.dart';
import 'package:cinetrack/services/kinopoisk_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ContentSafetyFilter SafeSearch Tests', () {
    test('allows safe and family-friendly movies', () {
      const safeMovie = CatalogItem(
        title: 'Интерстеллар',
        type: 'movie',
        genres: ['фантастика', 'драма', 'приключения'],
        year: 2014,
        rating: 8.6,
        kinopoiskId: 258687,
      );

      const safeAnime = CatalogItem(
        title: 'Унесённые призраками',
        type: 'anime',
        genres: ['аниме', 'мультфильм', 'приключения'],
        year: 2001,
        rating: 8.5,
        kinopoiskId: 370,
      );

      expect(ContentSafetyFilter.isSafe(safeMovie), isTrue);
      expect(ContentSafetyFilter.isSafe(safeAnime), isTrue);
    });

    test('blocks content with adult/erotica/hentai/porn genres', () {
      const adultMovie = CatalogItem(
        title: 'Некоторый фильм 18+',
        type: 'movie',
        genres: ['драма', 'для взрослых'],
        year: 2020,
        rating: 6.0,
      );

      const eroticaMovie = CatalogItem(
        title: 'Эротический триллер',
        type: 'movie',
        genres: ['эротика', 'триллер'],
        year: 2019,
        rating: 5.5,
      );

      const hentaiAnime = CatalogItem(
        title: 'Хентай тайтл',
        type: 'anime',
        genres: ['аниме', 'хентай'],
        year: 2021,
        rating: 7.0,
      );

      expect(ContentSafetyFilter.isSafe(adultMovie), isFalse);
      expect(ContentSafetyFilter.isSafe(eroticaMovie), isFalse);
      expect(ContentSafetyFilter.isSafe(hentaiAnime), isFalse);
    });

    test('blocks content with NSFW keywords in title or description', () {
      const pornTitleMovie = CatalogItem(
        title: 'Сексвайф порно история',
        type: 'movie',
        genres: ['комедия'],
        year: 2022,
        rating: 4.0,
      );

      const pornDescMovie = CatalogItem(
        title: 'Обычное название',
        type: 'movie',
        genres: ['драма'],
        description: 'Откровенные порно сцены и интимные приключения',
        year: 2021,
        rating: 5.0,
      );

      expect(ContentSafetyFilter.isSafe(pornTitleMovie), isFalse);
      expect(ContentSafetyFilter.isSafe(pornDescMovie), isFalse);
    });

    test('filterSafe filters list correctly', () {
      final list = [
        const CatalogItem(title: 'Матрица', type: 'movie', genres: ['фантастика']),
        const CatalogItem(title: 'Порно фильм', type: 'movie', genres: ['для взрослых']),
        const CatalogItem(title: 'Гарри Поттер', type: 'movie', genres: ['фэнтези']),
      ];

      final filtered = ContentSafetyFilter.filterSafe(list);
      expect(filtered.length, 2);
      expect(filtered.map((e) => e.title), containsAll(['Матрица', 'Гарри Поттер']));
    });
  });
}
