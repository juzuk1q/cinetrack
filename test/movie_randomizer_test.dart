import 'package:flutter_test/flutter_test.dart';
import 'package:cinetrack/core/movie_randomizer.dart';
import 'package:cinetrack/models/catalog_item.dart';

void main() {
  group('MovieRandomizer Tests', () {
    test('pickItem should return a non-null CatalogItem', () {
      final picked = MovieRandomizer.pickItem();
      expect(picked, isNotNull);
      expect(picked!.title.isNotEmpty, true);
    });

    test('pickItem should pick from provided custom candidates', () {
      const customItem = CatalogItem(
        kinopoiskId: 999999,
        title: 'Уникальный тестовый фильм',
        type: 'movie',
        typeLabel: 'Фильм',
        genres: ['Тест'],
        year: 2026,
        director: 'Режиссер',
        actors: 'Актеры',
        description: 'Описание',
        posterUrl: 'https://example.com/poster.jpg',
        rating: 9.9,
      );

      final picked = MovieRandomizer.pickItem(candidates: [customItem]);
      expect(picked, isNotNull);
    });
  });
}
