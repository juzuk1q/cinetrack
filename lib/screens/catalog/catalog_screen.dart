import 'dart:async';
import '../../services/kinopoisk_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/curated_catalog.dart';
import '../../models/catalog_item.dart';
import '../../models/media_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/top_notification.dart';
import '../../widgets/animations/app_animations.dart';

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
  List<CatalogItem> _remoteSearchResults = [];
  bool _isSearchingRemote = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() {
      final val = _searchCtrl.text.trim();
      if (val != _searchQuery) {
        _onSearchChanged(val);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
      _displayLimit = 16;
    });

    if (val.isEmpty) {
      _searchDebounce?.cancel();
      setState(() {
        _remoteSearchResults = [];
        _isSearchingRemote = false;
      });
      return;
    }

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _isSearchingRemote = true);
      try {
        final results = await KinopoiskService().search(val);
        if (mounted && _searchQuery == val) {
          setState(() {
            _remoteSearchResults = ContentSafetyFilter.filterSafe(results);
            _isSearchingRemote = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isSearchingRemote = false);
      }
    });
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
    List<CatalogItem> pool;
    if (_searchQuery.isEmpty) {
      // Main catalog: show hand-picked masterpieces of cinema
      pool = CuratedCatalog.items;
    } else {
      // Live search: merge matching curated items with live Kinopoisk database
      final q = _searchQuery.toLowerCase();
      final localMatches = CuratedCatalog.items.where((item) {
        return item.title.toLowerCase().contains(q) ||
            (item.nameOriginal?.toLowerCase().contains(q) ?? false) ||
            item.director.toLowerCase().contains(q) ||
            item.actors.toLowerCase().contains(q) ||
            item.genres.any((g) => g.toLowerCase().contains(q));
      }).toList();

      final seenIds = <int>{};
      final seenTitles = <String>{};
      final combined = <CatalogItem>[];

      for (final item in localMatches) {
        if (item.kinopoiskId != null) seenIds.add(item.kinopoiskId!);
        seenTitles.add(item.title.toLowerCase());
        combined.add(item);
      }

      for (final item in _remoteSearchResults) {
        if (item.kinopoiskId != null && seenIds.contains(item.kinopoiskId)) continue;
        if (seenTitles.contains(item.title.toLowerCase())) continue;
        if (item.kinopoiskId != null) seenIds.add(item.kinopoiskId!);
        seenTitles.add(item.title.toLowerCase());
        combined.add(item);
      }

      pool = combined;
    }

    // Strict SafeSearch filter: eliminate adult, erotica, pornography, hentai
    pool = ContentSafetyFilter.filterSafe(pool);

    if (_selectedType != 'all') {
      pool = pool.where((item) {
        if (_selectedType == 'movie') {
          return item.type == 'movie' &&
              !item.genres.any((g) => g.toLowerCase().contains('аниме') || g.toLowerCase().contains('мульт'));
        }
        if (_selectedType == 'series') {
          return item.type == 'series' || item.genres.any((g) => g.toLowerCase().contains('сериал'));
        }
        if (_selectedType == 'cartoon') {
          return item.type == 'cartoon' || item.genres.any((g) => g.toLowerCase().contains('мульт'));
        }
        if (_selectedType == 'anime') {
          return item.type == 'anime' || item.genres.any((g) => g.toLowerCase().contains('аниме'));
        }
        return true;
      }).toList();
    }

    return pool;
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
          '«${catalogItem.title}» удалён из вашей коллекции',
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
    var normType = catalogItem.type.toLowerCase();
    if (normType.contains('series') || normType.contains('show')) {
      normType = 'series';
    } else if (normType.contains('anime')) {
      normType = 'anime';
    } else if (normType.contains('cartoon') || normType.contains('мульт')) {
      normType = 'cartoon';
    } else {
      normType = 'movie';
    }

    final item = MediaItem(
      id: '',
      userId: user.id,
      title: catalogItem.title,
      type: normType,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C16) : const Color(0xFFF8FAFC),
      body: Column(
        children: [
          const AppHeader(activeRoute: '/catalog'),
          Expanded(
            child: CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                // Top banner & filters (Clean background, search & full-width stretched genre tabs)
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    color: isDark ? const Color(0xFF0C0C16) : const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Каталог',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Full width rounded search pill
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF16162A) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            style: TextStyle(
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Название фильма или сериала',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                size: 20,
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isSearchingRemote) ...[
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  if (_searchQuery.isNotEmpty)
                                    IconButton(
                                      icon: Icon(
                                        Icons.clear_rounded,
                                        color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                                        size: 18,
                                      ),
                                      onPressed: () => _searchCtrl.clear(),
                                    ),
                                ],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Tabs: Все | Фильмы | Сериалы | Мультфильмы | Аниме (Растянуты на всю ширину)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF16162A) : const Color(0xFFEDF2F7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 540;
                              final tabs = [
                                ('all', 'Все'),
                                ('movie', 'Фильмы'),
                                ('series', 'Сериалы'),
                                ('cartoon', 'Мультфильмы'),
                                ('anime', 'Аниме'),
                              ];

                              return Row(
                                children: tabs.map((tab) {
                                  final isSelected = _selectedType == tab.$1;
                                  return Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          _selectedType = tab.$1;
                                          _displayLimit = 16;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        padding: EdgeInsets.symmetric(
                                          vertical: isMobile ? 9 : 11,
                                          horizontal: 4,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF7C3AED)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: isSelected
                                              ? [
                                                  BoxShadow(
                                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Text(
                                          tab.$2,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                            fontSize: isMobile ? 12 : 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.movie_filter_rounded,
                              size: 26,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _selectedType == 'anime'
                                  ? 'Ищете другое аниме?'
                                  : _selectedType == 'movie'
                                      ? 'Ищете другой фильм?'
                                      : _selectedType == 'series'
                                          ? 'Ищете другой сериал?'
                                          : _selectedType == 'cartoon'
                                              ? 'Ищете другой мультфильм?'
                                              : 'Не нашли нужное произведение?',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF334155),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'В базе CineTrack тысячи тайтлов — введите название в поиске выше',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? Colors.white38 : const Color(0xFF64748B),
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: () {
                                _scrollCtrl.animateTo(
                                  0,
                                  duration: const Duration(milliseconds: 350),
                                  curve: Curves.easeOutCubic,
                                );
                              },
                              icon: const Icon(Icons.search_rounded, size: 16),
                              label: const Text('Перейти к поиску'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF7C3AED),
                                side: const BorderSide(color: Color(0xFF7C3AED), width: 1.2),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ],
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




  Widget _buildCatalogCard(CatalogItem item, MediaItem? existing) {
    final alreadyInCollection = existing != null;
    final poster =
        CatalogItem.fixPosterUrl(item.posterUrl, kpId: item.kinopoiskId);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedHoverCard(
      onTap: () => context.push(
        '/movie/${item.kinopoiskId ?? item.title}',
        extra: item,
      ),
      borderRadius: BorderRadius.circular(16),
      glowColor: const Color(0xFF7C3AED),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16162A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.06),
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
                  Hero(
                    tag: 'movie-poster-${item.kinopoiskId ?? item.title}',
                    child: Image.network(
                      poster,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return const ShimmerBox(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 0,
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFE2E8F0),
                        child: Center(
                          child: Icon(Icons.movie_rounded,
                              size: 48, color: isDark ? Colors.white24 : const Color(0xFF94A3B8)),
                        ),
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
                  // Top Right: Rating badge + Bookmark button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
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
                        const SizedBox(width: 6),
                        BouncyButton(
                          onTap: () => _toggleCollection(item, existing),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: alreadyInCollection
                                  ? const Color(0xFF10B981)
                                  : Colors.black.withValues(alpha: 0.75),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: alreadyInCollection
                                    ? const Color(0xFF10B981)
                                    : Colors.white30,
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              alreadyInCollection
                                  ? Icons.bookmark_added_rounded
                                  : Icons.bookmark_add_outlined,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.year} • ${item.genres.take(2).join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
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
                  BouncyButton(
                    onTap: () => context.push(
                      '/movie/${item.kinopoiskId ?? item.title}',
                      extra: item,
                    ),
                    child: IconButton.filledTonal(
                      icon: Icon(Icons.play_arrow_rounded,
                          size: 18, color: isDark ? Colors.white : const Color(0xFF7C3AED)),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF282845) : const Color(0xFFEDE9FE),
                      ),
                      tooltip: 'Смотреть онлайн',
                      onPressed: () => context.push(
                        '/movie/${item.kinopoiskId ?? item.title}',
                        extra: item,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Toggle collection button
                  Expanded(
                    child: BouncyButton(
                      onTap: () => _toggleCollection(item, existing),
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
                        onPressed: () => _toggleCollection(item, existing),
                      ),
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
