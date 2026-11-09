import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/movie_randomizer.dart';
import '../../core/theme.dart';
import '../../data/curated_catalog.dart';
import '../../models/catalog_item.dart';
import '../../models/media_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/top_notification.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String _selectedType = 'all'; // all, movie, series, cartoon, anime
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  int _displayLimit = 16;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 350) {
      final total = _getFilteredItems().length;
      if (_displayLimit < total && !_isLoadingMore) {
        setState(() {
          _isLoadingMore = true;
        });
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            setState(() {
              _displayLimit = (_displayLimit + 12).clamp(0, total);
              _isLoadingMore = false;
            });
          }
        });
      }
    }
  }

  List<CatalogItem> _getFilteredItems() {
    return CuratedCatalog.items.where((item) {
      if (_selectedType != 'all') {
        if (_selectedType == 'movie' && item.type != 'movie') return false;
        if (_selectedType == 'series' && item.type != 'series') return false;
        if (_selectedType == 'cartoon' && item.type != 'cartoon') return false;
        if (_selectedType == 'anime' && item.type != 'anime') return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = item.title.toLowerCase().contains(q);
        final matchOriginal =
            item.nameOriginal?.toLowerCase().contains(q) ?? false;
        final matchDirector = item.director.toLowerCase().contains(q);
        final matchActors = item.actors.toLowerCase().contains(q);
        final matchGenre =
            item.genres.any((g) => g.toLowerCase().contains(q));
        if (!matchTitle &&
            !matchOriginal &&
            !matchDirector &&
            !matchActors &&
            !matchGenre) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _toggleCollection(
      CatalogItem catalogItem, MediaItem? existing) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
      return;
    }

    if (existing != null) {
      // Remove from collection
      try {
        await ref.read(mediaNotifierProvider.notifier).delete(existing.id);
        ref.invalidate(mediaListProvider);
        ref.invalidate(statsDataProvider);

        if (!mounted) return;
        TopNotification.showSuccess(
          context,
          '«${catalogItem.title}» удалён из вашей коллекции 🗑️',
          title: 'Коллекция',
        );
      } catch (e) {
        if (!mounted) return;
        TopNotification.showError(
          context,
          'Ошибка удаления: $e',
          title: 'Ошибка',
        );
      }
      return;
    }

    // Add to collection
    final now = DateTime.now();
    final item = MediaItem(
      id: '',
      userId: user.id,
      title: catalogItem.title,
      type: catalogItem.type,
      genres: catalogItem.genres,
      year: catalogItem.year,
      director: catalogItem.director,
      actors: catalogItem.actors,
      description: catalogItem.description,
      posterUrl: catalogItem.posterUrl,
      kinopoiskId: catalogItem.kinopoiskId,
      status: 'want_to_watch',
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref.read(mediaNotifierProvider.notifier).create(item);
      ref.invalidate(mediaListProvider);
      ref.invalidate(statsDataProvider);

      if (!mounted) return;
      TopNotification.showSuccess(
        context,
        '«${catalogItem.title}» добавлен в коллекцию! ⭐',
        title: 'Коллекция',
      );
    } catch (e) {
      if (!mounted) return;
      TopNotification.showError(
        context,
        'Ошибка добавления: $e',
        title: 'Ошибка',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userMediaAsync = ref.watch(mediaListProvider);
    final userMediaMap = <String, MediaItem>{};
    userMediaAsync.maybeWhen(
      data: (items) {
        for (final m in items) {
          if (m.kinopoiskId != null && m.kinopoiskId! > 0) {
            userMediaMap['kp_${m.kinopoiskId}'] = m;
          }
          userMediaMap['title_${m.title.toLowerCase().trim()}'] = m;
        }
      },
      orElse: () {},
    );

    final filtered = _getFilteredItems();
    final displayedItems = filtered.take(_displayLimit).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C16),
      body: Column(
        children: [
          const AppHeader(activeRoute: '/library'),
          Expanded(
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // Top banner & filters
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.movie_filter_rounded,
                                color: Color(0xFF9F67FF), size: 24),
                            const SizedBox(width: 10),
                            const Text(
                              'Библиотека и каталог фильмов',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Всего шедевров: ${filtered.length}',
                              style: const TextStyle(
                                color: Color(0xFFC084FC),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Готовая коллекция фильмов, сериалов, аниме и мультфильмов. Выберите произведение и запустите совместный просмотр или добавьте в коллекцию!',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Search Bar
                        TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF16162A),
                            hintText:
                                'Поиск по названию, режиссёру, актёрам или жанру...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: Colors.white54),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Color(0xFF7C3AED), width: 1.5),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded,
                                        color: Colors.white54),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {
                                        _searchQuery = '';
                                        _displayLimit = 16;
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (v) => setState(() {
                            _searchQuery = v.trim();
                            _displayLimit = 16;
                          }),
                        ),
                        const SizedBox(height: 14),

                        // Category filter chips
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildFilterChip('all', 'Все категории',
                                Icons.all_inclusive_rounded),
                            _buildFilterChip(
                                'movie', 'Фильмы', Icons.movie_outlined),
                            _buildFilterChip(
                                'series', 'Сериалы', Icons.tv_outlined),
                            _buildFilterChip(
                                'anime', 'Аниме', Icons.bolt_rounded),
                            _buildFilterChip('cartoon', 'Мультфильмы',
                                Icons.animation_outlined),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                              ),
                              icon: const Text('🎲',
                                  style: TextStyle(fontSize: 14)),
                              label: const Text('Случайный выбор',
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700)),
                              onPressed: () => _pickRandomMovie(
                                  filtered.isNotEmpty
                                      ? filtered
                                      : CuratedCatalog.items),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Grid of items
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      childAspectRatio: 0.62,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = displayedItems[index];
                        final existing = (item.kinopoiskId != null
                                ? userMediaMap['kp_${item.kinopoiskId}']
                                : null) ??
                            userMediaMap[
                                'title_${item.title.toLowerCase().trim()}'];
                        return _buildCatalogCard(item, existing);
                      },
                      childCount: displayedItems.length,
                    ),
                  ),
                ),

                // Infinite Scroll Load-More Indicator
                if (_displayLimit < filtered.length)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF7C3AED),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Показано ${displayedItems.length} из ${filtered.length} произведений. Листайте вниз для загрузки...',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          'Вы просмотрели всю подборку шедевров! 🍿',
                          style: TextStyle(
                            color: Colors.white38,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _pickRandomMovie(List<CatalogItem> items) {
    MovieRandomizer.pickAndOpen(context, candidates: items, usePush: false);
  }

  Widget _buildFilterChip(String type, String label, IconData icon) {
    final selected = _selectedType == type;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : Colors.white54,
      ),
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFF7C3AED),
      backgroundColor: const Color(0xFF16162A),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF9F67FF) : Colors.white12,
      ),
      onSelected: (_) => setState(() {
        _selectedType = type;
        _displayLimit = 16;
      }),
    );
  }

  Widget _buildCatalogCard(CatalogItem item, MediaItem? existing) {
    final alreadyInCollection = existing != null;
    final poster =
        CatalogItem.fixPosterUrl(item.posterUrl, kpId: item.kinopoiskId);

    return InkWell(
      onTap: () => context.push(
        '/movie/${item.kinopoiskId ?? item.title}',
        extra: item,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16162A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Poster with badges
            Expanded(
              flex: 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    poster,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF1A1A2E),
                      child: const Center(
                        child: Icon(Icons.movie_rounded,
                            size: 48, color: Colors.white24),
                      ),
                    ),
                  ),
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black87,
                          ],
                          stops: [0.55, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Type badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.typeColor(item.type)
                            .withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.displayTypeLabel.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  // Rating badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: const Color(0xFFFFCA28), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 13, color: Color(0xFFFFCA28)),
                          const SizedBox(width: 3),
                          Text(
                            item.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.year} • ${item.genres.take(2).join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Actions: Solo Watch / Collection Toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Row(
                children: [
                  // Play button
                  IconButton.filledTonal(
                    icon: const Icon(Icons.play_arrow_rounded,
                        size: 18, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF282845),
                    ),
                    tooltip: 'Смотреть онлайн',
                    onPressed: () => context.push(
                      '/movie/${item.kinopoiskId ?? item.title}',
                      extra: item,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Toggle collection button
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        backgroundColor: alreadyInCollection
                            ? const Color(0xFF10B981)
                            : const Color(0xFF7C3AED),
                      ),
                      icon: Icon(
                        alreadyInCollection
                            ? Icons.check_circle_rounded
                            : Icons.bookmark_add_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      label: Text(
                        alreadyInCollection ? 'В коллекции' : 'В коллекцию',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () =>
                          _toggleCollection(item, existing),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
