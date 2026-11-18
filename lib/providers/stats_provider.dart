import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/stats_repository.dart';

final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  return StatsRepository();
});

final statsDataProvider = FutureProvider<StatsData>((ref) async {
  final repo = ref.watch(statsRepositoryProvider);
  return repo.getStats();
});

final statsByStatusProvider = FutureProvider<Map<String, int>>((ref) async {
  final data = await ref.watch(statsDataProvider.future);
  return data.byStatus;
});

final statsByGenreProvider = FutureProvider<Map<String, int>>((ref) async {
  final data = await ref.watch(statsDataProvider.future);
  return data.byGenre;
});

final statsByMonthProvider = FutureProvider<Map<String, int>>((ref) async {
  final data = await ref.watch(statsDataProvider.future);
  return data.byMonth;
});

final averageRatingProvider = FutureProvider<double>((ref) async {
  final data = await ref.watch(statsDataProvider.future);
  return data.averageRating;
});
