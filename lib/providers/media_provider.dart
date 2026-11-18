import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_item.dart';
import '../repositories/media_repository.dart';

// Repository
final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository();
});

// Filters state
class FiltersNotifier extends StateNotifier<MediaFilters> {
  FiltersNotifier() : super(const MediaFilters());

  void setStatus(String? status) {
    state = state.copyWith(
      status: status,
      clearStatus: status == null,
    );
  }

  void setType(String? type) {
    state = state.copyWith(type: type, clearType: type == null);
  }

  void setGenre(String? genre) {
    state = state.copyWith(genre: genre, clearGenre: genre == null);
  }

  void setYear(int? year) {
    state = state.copyWith(year: year, clearYear: year == null);
  }

  void setSearch(String query) {
    state = state.copyWith(
      searchQuery: query.isEmpty ? null : query,
      clearSearch: query.isEmpty,
    );
  }

  void reset() {
    state = const MediaFilters();
  }
}

final filtersProvider =
    StateNotifierProvider<FiltersNotifier, MediaFilters>((ref) {
  return FiltersNotifier();
});

// Media list (filtered with strict deduplication)
final mediaListProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repo = ref.watch(mediaRepositoryProvider);
  final filters = ref.watch(filtersProvider);
  final rawList = await repo.getAll(filters: filters);
  // Guarantee deduplication by Kinopoisk ID or trimmed title
  final uniqueMap = <String, MediaItem>{};
  for (final item in rawList) {
    final key = (item.kinopoiskId != null && item.kinopoiskId! > 0)
        ? 'kp_${item.kinopoiskId}'
        : 'title_${item.title.trim().toLowerCase()}';
    uniqueMap.putIfAbsent(key, () => item);
  }
  return uniqueMap.values.toList();
});

// Target user media list (for viewing other users' collections)
final userMediaListProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, userId) async {
  final repo = ref.watch(mediaRepositoryProvider);
  final rawList = await repo.getByUserId(userId);
  final uniqueMap = <String, MediaItem>{};
  for (final item in rawList) {
    final key = (item.kinopoiskId != null && item.kinopoiskId! > 0)
        ? 'kp_${item.kinopoiskId}'
        : 'title_${item.title.trim().toLowerCase()}';
    uniqueMap.putIfAbsent(key, () => item);
  }
  return uniqueMap.values.toList();
});

// Single media item
final mediaItemProvider =
    FutureProvider.family<MediaItem?, String>((ref, id) async {
  final repo = ref.watch(mediaRepositoryProvider);
  return repo.getById(id);
});

// Media with planned dates (for planner)
final plannedMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  final repo = ref.watch(mediaRepositoryProvider);
  return repo.getAllWithPlannedDates();
});

// Media CRUD notifier
class MediaNotifier extends StateNotifier<AsyncValue<void>> {
  MediaNotifier(this._repo) : super(const AsyncValue.data(null));

  final MediaRepository _repo;

  Future<MediaItem?> create(MediaItem item) async {
    state = const AsyncValue.loading();
    try {
      final created = await _repo.create(item);
      state = const AsyncValue.data(null);
      return created;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<MediaItem?> update(String id, MediaItem item) async {
    state = const AsyncValue.loading();
    try {
      final updated = await _repo.update(id, item);
      state = const AsyncValue.data(null);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<bool> delete(String id) async {
    state = const AsyncValue.loading();
    try {
      await _repo.delete(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final mediaNotifierProvider =
    StateNotifierProvider<MediaNotifier, AsyncValue<void>>((ref) {
  return MediaNotifier(ref.watch(mediaRepositoryProvider));
});
