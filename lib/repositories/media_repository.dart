import '../core/supabase_client.dart';
import '../models/media_item.dart';

class MediaFilters {
  final String? status;
  final String? type;
  final String? genre;
  final int? year;
  final String? searchQuery;

  const MediaFilters({
    this.status,
    this.type,
    this.genre,
    this.year,
    this.searchQuery,
  });

  MediaFilters copyWith({
    String? status,
    String? type,
    String? genre,
    int? year,
    String? searchQuery,
    bool clearStatus = false,
    bool clearType = false,
    bool clearGenre = false,
    bool clearYear = false,
    bool clearSearch = false,
  }) {
    return MediaFilters(
      status: clearStatus ? null : (status ?? this.status),
      type: clearType ? null : (type ?? this.type),
      genre: clearGenre ? null : (genre ?? this.genre),
      year: clearYear ? null : (year ?? this.year),
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
    );
  }

  bool get hasActiveFilters =>
      status != null ||
      type != null ||
      genre != null ||
      year != null ||
      (searchQuery != null && searchQuery!.isNotEmpty);
}

class MediaRepository {
  final String _table = 'media';

  Future<List<MediaItem>> getAll({MediaFilters? filters}) async {
    var query = supabase
        .from(_table)
        .select()
        .order('created_at', ascending: false);

    // We'll fetch all and filter client-side for search + genre array
    final response = await query;
    var items = (response as List)
        .map((json) => MediaItem.fromJson(json))
        .toList();

    if (filters == null) return items;

    if (filters.status != null) {
      items = items.where((i) => i.status == filters.status).toList();
    }
    if (filters.type != null) {
      items = items.where((i) => i.type == filters.type).toList();
    }
    if (filters.genre != null) {
      items = items
          .where((i) => i.genres.contains(filters.genre))
          .toList();
    }
    if (filters.year != null) {
      items = items.where((i) => i.year == filters.year).toList();
    }
    if (filters.searchQuery != null && filters.searchQuery!.isNotEmpty) {
      final q = filters.searchQuery!.toLowerCase();
      items = items.where((i) {
        return i.title.toLowerCase().contains(q) ||
            (i.actors?.toLowerCase().contains(q) ?? false) ||
            (i.director?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    return items;
  }

  Future<MediaItem?> getById(String id) async {
    final response = await supabase
        .from(_table)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return MediaItem.fromJson(response);
  }

  Future<MediaItem> create(MediaItem item) async {
    final data = item.toInsertJson();
    final currentUserId = supabase.auth.currentUser?.id;
    if (currentUserId != null && (!data.containsKey('user_id') || data['user_id'] == null)) {
      data['user_id'] = currentUserId;
    }

    final targetUserId = data['user_id'];
    if (targetUserId != null) {
      // Check for existing duplicate to prevent adding multiple copies of the same film
      try {
        final existing = await supabase
            .from(_table)
            .select()
            .eq('user_id', targetUserId)
            .ilike('title', item.title.trim())
            .maybeSingle();
        if (existing != null) {
          return MediaItem.fromJson(existing);
        }
      } catch (_) {}
    }

    final response = await supabase
        .from(_table)
        .insert(data)
        .select()
        .single();
    return MediaItem.fromJson(response);
  }

  Future<MediaItem> update(String id, MediaItem item) async {
    final data = item.toInsertJson();
    data.remove('user_id');
    final response = await supabase
        .from(_table)
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return MediaItem.fromJson(response);
  }

  Future<void> delete(String id) async {
    await supabase.from(_table).delete().eq('id', id);
  }

  Future<List<MediaItem>> getByPlannedDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    final response = await supabase
        .from(_table)
        .select()
        .eq('planned_date', dateStr)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => MediaItem.fromJson(json))
        .toList();
  }

  Future<List<MediaItem>> getAllWithPlannedDates() async {
    final response = await supabase
        .from(_table)
        .select()
        .not('planned_date', 'is', null)
        .order('planned_date', ascending: true);
    return (response as List)
        .map((json) => MediaItem.fromJson(json))
        .toList();
  }
}
