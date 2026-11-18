import 'package:flutter_test/flutter_test.dart';
import 'package:cinetrack/models/media_item.dart';
import 'package:cinetrack/repositories/stats_repository.dart';

void main() {
  group('StatsRepository computeStats Tests', () {
    test('computeStats correctly aggregates counts, statuses, genres, and ratings', () {
      final now = DateTime.now();
      final mockItems = [
        MediaItem(
          id: '1',
          userId: 'user-1',
          title: 'Movie A',
          type: 'movie',
          genres: ['Sci-Fi', 'Action'],
          year: 2022,
          director: 'Director A',
          actors: 'Actor A',
          description: 'Desc A',
          status: 'watched',
          rating: 10,
          createdAt: now,
          updatedAt: now,
          watchedAt: now,
        ),
        MediaItem(
          id: '2',
          userId: 'user-1',
          title: 'Movie B',
          type: 'movie',
          genres: ['Sci-Fi', 'Drama'],
          year: 2023,
          director: 'Director B',
          actors: 'Actor B',
          description: 'Desc B',
          status: 'watched',
          rating: 8,
          createdAt: now,
          updatedAt: now,
          watchedAt: now,
        ),
        MediaItem(
          id: '3',
          userId: 'user-1',
          title: 'Series C',
          type: 'series',
          genres: ['Comedy'],
          year: 2024,
          director: 'Director C',
          actors: 'Actor C',
          description: 'Desc C',
          status: 'want_to_watch',
          rating: null,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final stats = StatsRepository.computeStats(mockItems);

      expect(stats.totalCount, 3);
      expect(stats.byStatus['watched'], 2);
      expect(stats.byStatus['want_to_watch'], 1);

      expect(stats.byGenre['Sci-Fi'], 2);
      expect(stats.byGenre['Action'], 1);
      expect(stats.byGenre['Drama'], 1);
      expect(stats.byGenre['Comedy'], 1);

      expect(stats.favoriteGenre, 'Sci-Fi');
      expect(stats.averageRating, 9.0);
    });

    test('computeStats handles empty list gracefully', () {
      final stats = StatsRepository.computeStats([]);
      expect(stats.totalCount, 0);
      expect(stats.averageRating, 0.0);
      expect(stats.favoriteGenre, isNull);
      expect(stats.byStatus, isEmpty);
      expect(stats.byGenre, isEmpty);
    });
  });
}
