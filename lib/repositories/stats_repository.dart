import '../core/supabase_client.dart';
import '../models/media_item.dart';

class StatsData {
  final Map<String, int> byStatus;
  final Map<String, int> byGenre;
  final Map<String, int> byMonth;
  final double averageRating;
  final int totalCount;
  final String? favoriteGenre;

  const StatsData({
    required this.byStatus,
    required this.byGenre,
    required this.byMonth,
    required this.averageRating,
    required this.totalCount,
    this.favoriteGenre,
  });
}

class StatsRepository {
  Future<StatsData> getStats() async {
    final response = await supabase
        .from('media')
        .select()
        .order('created_at', ascending: false);

    final items = (response as List)
        .map((j) => MediaItem.fromJson(j as Map<String, dynamic>))
        .toList();

    return _compute(items);
  }

  StatsData _compute(List<MediaItem> items) {
    // By status
    final byStatus = <String, int>{};
    for (final item in items) {
      byStatus[item.status] = (byStatus[item.status] ?? 0) + 1;
    }

    // By genre
    final byGenre = <String, int>{};
    for (final item in items) {
      for (final genre in item.genres) {
        byGenre[genre] = (byGenre[genre] ?? 0) + 1;
      }
    }

    // By month (watchedAt or createdAt for watched items)
    final byMonth = <String, int>{};
    final now = DateTime.now();
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      byMonth[key] = 0;
    }
    for (final item in items) {
      if (item.status == 'watched') {
        final date = item.watchedAt ?? item.updatedAt;
        final key =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';
        if (byMonth.containsKey(key)) {
          byMonth[key] = (byMonth[key] ?? 0) + 1;
        }
      }
    }

    // Average rating
    final rated = items.where((i) => i.rating != null).toList();
    final avgRating = rated.isEmpty
        ? 0.0
        : rated.fold<int>(0, (sum, i) => sum + i.rating!) / rated.length;

    // Favorite genre
    String? favoriteGenre;
    if (byGenre.isNotEmpty) {
      favoriteGenre =
          byGenre.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    return StatsData(
      byStatus: byStatus,
      byGenre: byGenre,
      byMonth: byMonth,
      averageRating: avgRating,
      totalCount: items.length,
      favoriteGenre: favoriteGenre,
    );
  }

  Future<Map<String, int>> getStatsByStatus() async {
    final stats = await getStats();
    return stats.byStatus;
  }

  Future<Map<String, int>> getStatsByGenre() async {
    final stats = await getStats();
    return stats.byGenre;
  }

  Future<Map<String, int>> getStatsByMonth() async {
    final stats = await getStats();
    return stats.byMonth;
  }

  Future<double> getAverageRating() async {
    final stats = await getStats();
    return stats.averageRating;
  }
}
