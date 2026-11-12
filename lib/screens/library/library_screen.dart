import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/catalog_item.dart';
import '../../models/media_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kinopoisk_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/app_header.dart';
import 'widgets/catalog_card_widget.dart';
import '../../widgets/top_notification.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String _animeSubFilter = 'all'; // 'all', 'series', 'movies'

  final List<int> _years = [2026, 2025, 2024, 2023, 2022, 2021, 2020];

  final List<String> _countries = [
    'Все страны',
    'США',
    'Россия',
    'Франция',
    'Великобритания',
    'Япония',
    'Южная Корея (Дорамы)',
    'Турция',
    'Индия',
    'Германия',
    'Италия',
    'Испания',
  ];

  final List<String> _genresColumn1 = [
    'Биографические',
    'Мюзиклы',
    'Боевики',
    'Вестерны',
    'Военные',
    'Документальные',
    'Детективы',
    'Детские',
    'Драмы',
    'Исторические',
    'Комедии',
    'Короткометражки',
  ];

  final List<String> _genresColumn2 = [
    'Криминал',
    'Мелодрамы',
    'Музыкальные',
    'Нуар',
    'Приключения',
    'Семейные',
    'Спорт',
    'Триллеры',
    'Ужасы',
    'Фантастика',
    'Фэнтези',
    'Аниме',
    'Мультфильмы',
  ];

  String? _lastQueryParam;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkQueryParam();
  }

  void _checkQueryParam() {
    try {
      final uri = GoRouterState.of(context).uri;
      final q = uri.queryParameters['q'];
      if (q != null && q.trim().isNotEmpty && q != _lastQueryParam) {
        _lastQueryParam = q;
        _searchCtrl.text = q.trim();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ref.read(catalogProvider.notifier).setSearchQuery(q.trim());
          }
        });
      }
    } catch (e) {
      debugPrint('Error syncing query params in library: $e');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _startSoloWatch(CatalogItem item) {
    final uri = Uri(
      path: '/watch',
      queryParameters: {
        'title': item.title,
        'year': item.year.toString(),
        if (item.kinopoiskId != null) 'kpId': item.kinopoiskId.toString(),
        'poster': item.posterUrl,
        'type': item.type,
        'desc': item.description,
        'genres': item.genres.join(', '),
      },
    );
    context.go(uri.toString());
  }

  Future<void> _startPartyWatch(CatalogItem item) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      TopNotification.showWarning(
        context,
        'Для создания комнаты необходимо войти в аккаунт',
        title: 'Требуется авторизация',
      );
      context.push('/login');
      return;
    }
    final customProf = ref.read(profileCustomizationProvider);
    final dbProf = ref.read(userProfileProvider).value;
    final ownerName = (customProf?.username.isNotEmpty == true
            ? '@${customProf!.username.replaceAll('@', '')}'
            : null) ??
        (dbProf?.username.isNotEmpty == true
            ? '@${dbProf!.username.replaceAll('@', '')}'
            : null) ??
        (user.userMetadata?['username'] != null
            ? '@${user.userMetadata!['username']}'
            : null) ??
        (user.email?.split('@').first ?? 'Организатор');
    final ownerId = user.id;

    final room = await ref.read(roomsProvider.notifier).createRoom(
          title: 'Совместный просмотр: ${item.title} 🍿',
          movieTitle: item.title,
          movieType: item.type,
          moviePoster: item.posterUrl,
          movieYear: item.year,
          kinopoiskId: item.kinopoiskId,
          videoSourceType: 'catalog',
          videoUrl: 'https://kinobox.tv/embed/kinopoisk/${item.kinopoiskId ?? 258687}',
          scheduledAt: DateTime.now(),
          ownerName: ownerName,
          ownerId: ownerId,
        );

    if (room == null || !mounted) return;
    TopNotification.showSuccess(
      context,
      'Комната «${item.title}» создана! Подключаем к показу...',
      title: 'Комната совместного просмотра 🍿',
    );

    context.go('/rooms/${room.id}');
  }

  Future<void> _addToMyCollection(CatalogItem catalogItem) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      TopNotification.showWarning(
        context,
        'Войдите в аккаунт, чтобы сохранять в личную коллекцию',
        title: 'Авторизация',
      );
      return;
    }

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
        '«${catalogItem.title}» добавлен в вашу коллекцию! ⭐',
        title: 'Коллекция',
      );
    } catch (e) {
      if (!mounted) return;
      TopNotification.showError(
        context,
        'Ошибка сохранения: $e',
        title: 'Ошибка',
      );
    }
  }

  void _showMovieDetailDialog(CatalogItem initialItem) {
    final id = initialItem.kinopoiskId?.toString() ?? Uri.encodeComponent(initialItem.title);
    context.push('/movie/$id', extra: initialItem);
  }

  void _openFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (dialogCtx, ref, _) {
            final currentFilter = ref.watch(catalogProvider).filter;

            return AlertDialog(
              backgroundColor: const Color(0xFF16162A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.white12),
              ),
              title: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: Color(0xFF9F67FF)),
                  const SizedBox(width: 10),
                  const Text('Фильтр каталога',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (currentFilter.hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        ref.read(catalogProvider.notifier).resetFilters();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Сбросить всё',
                          style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                ],
              ),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Years Row
                      const Text('По году:',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9F67FF),
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Все года'),
                            selected: currentFilter.year == null,
                            onSelected: (_) {
                              ref.read(catalogProvider.notifier).setYear(null);
                            },
                          ),
                          ..._years.map((y) {
                            return ChoiceChip(
                              label: Text('$y'),
                              selected: currentFilter.year == y,
                              onSelected: (_) {
                                ref.read(catalogProvider.notifier).setYear(y);
                              },
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Countries Row
                      const Text('По странам:',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9F67FF),
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _countries.map((c) {
                          final selected = currentFilter.country == c;
                          return ChoiceChip(
                            label: Text(c),
                            selected: selected,
                            onSelected: (_) {
                              ref.read(catalogProvider.notifier).setCountry(c);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Genres
                      const Text('По жанрам:',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9F67FF),
                              fontSize: 13)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Все жанры'),
                            selected: currentFilter.genre == 'Все жанры',
                            onSelected: (_) {
                              ref.read(catalogProvider.notifier).setGenre('Все жанры');
                            },
                          ),
                          ..._genresColumn1.map((g) {
                            return ChoiceChip(
                              label: Text(g),
                              selected: currentFilter.genre == g,
                              onSelected: (_) {
                                ref.read(catalogProvider.notifier).setGenre(g);
                              },
                            );
                          }),
                          ..._genresColumn2.map((g) {
                            return ChoiceChip(
                              label: Text(g),
                              selected: currentFilter.genre == g,
                              onSelected: (_) {
                                ref.read(catalogProvider.notifier).setGenre(g);
                              },
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Применить фильтры'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogState = ref.watch(catalogProvider);
    final userMediaAsync = ref.watch(mediaListProvider);

    final userTitles = userMediaAsync.maybeWhen(
      data: (items) => items.map((e) => e.title.toLowerCase().trim()).toSet(),
      orElse: () => <String>{},
    );

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(activeRoute: '/library'),
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                // Lordfilm Categories & Search Bar
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1280),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          MediaQuery.of(context).size.width < 700 ? 12 : 28,
                          16,
                          MediaQuery.of(context).size.width < 700 ? 12 : 28,
                          12,
                        ),
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Categories Row: [ВСЁ] [ФИЛЬМЫ] [СЕРИАЛЫ] [МУЛЬТФИЛЬМЫ] [АНИМЕ]
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _buildCategoryBtn('all', 'ВСЁ'),
                            _buildCategoryBtn('movie', 'ФИЛЬМЫ'),
                            _buildCategoryBtn('series', 'СЕРИАЛЫ'),
                            _buildCategoryBtn('cartoon', 'МУЛЬТФИЛЬМЫ'),
                            _buildCategoryBtn('anime', 'АНИМЕ 🌸'),
                          ],
                        ),

                        // Anime sub-filters (TV Series / Episodes vs Full Movies)
                        if (catalogState.filter.category == 'anime') ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.video_collection_rounded,
                                        size: 14, color: Color(0xFF818CF8)),
                                    SizedBox(width: 5),
                                    Text(
                                      'Формат:',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFC7D2FE)),
                                    ),
                                  ],
                                ),
                              ),
                              _buildAnimeSubFilterChip('all', '🍿 Все аниме'),
                              _buildAnimeSubFilterChip(
                                  'series', '📺 Аниме-сериалы (по сериям)'),
                              _buildAnimeSubFilterChip(
                                  'movies', '🎬 Полнометражные фильмы'),
                            ],
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Search Input & Filter Button Row
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText:
                                      'Введите название фильма, сериала или аниме...',
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_searchCtrl.text.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(Icons.clear_rounded,
                                              size: 18),
                                          tooltip: 'Очистить',
                                          onPressed: () {
                                            _searchCtrl.clear();
                                            ref
                                                .read(catalogProvider.notifier)
                                                .setSearchQuery('');
                                          },
                                        ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Color(0xFF7C3AED)),
                                        tooltip: 'Искать',
                                        onPressed: () {
                                          ref
                                              .read(catalogProvider.notifier)
                                              .setSearchQuery(
                                                  _searchCtrl.text.trim());
                                        },
                                      ),
                                    ],
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onChanged: (val) {
                                  _searchDebounce?.cancel();
                                  _searchDebounce =
                                      Timer(const Duration(milliseconds: 350), () {
                                    if (mounted) {
                                      ref
                                          .read(catalogProvider.notifier)
                                          .setSearchQuery(val.trim());
                                    }
                                  });
                                },
                                onSubmitted: (val) {
                                  _searchDebounce?.cancel();
                                  ref
                                      .read(catalogProvider.notifier)
                                      .setSearchQuery(val.trim());
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: catalogState.filter.hasActiveFilters
                                      ? const Color(0xFF10B981)
                                      : Colors.white24,
                                  width: catalogState.filter.hasActiveFilters
                                      ? 1.5
                                      : 1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 15),
                                backgroundColor:
                                    catalogState.filter.hasActiveFilters
                                        ? const Color(0xFF10B981)
                                            .withValues(alpha: 0.1)
                                        : null,
                              ),
                              icon: Icon(
                                Icons.tune_rounded,
                                color: catalogState.filter.hasActiveFilters
                                    ? const Color(0xFF10B981)
                                    : Colors.white70,
                              ),
                              label: Text(
                                catalogState.filter.hasActiveFilters
                                    ? 'Фильтры (активны)'
                                    : 'Фильтры',
                                style: TextStyle(
                                  color: catalogState.filter.hasActiveFilters
                                      ? const Color(0xFF10B981)
                                      : Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onPressed: _openFilterDialog,
                            ),
                          ],
                        ),

                        // Active filter chips row (strictly year, genre, country)
                        if (catalogState.filter.hasActiveFilters) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('Активно:',
                                  style: TextStyle(
                                      color: Colors.white54, fontSize: 11)),
                              if (catalogState.filter.genre != 'Все жанры')
                                Chip(
                                  label: Text(catalogState.filter.genre,
                                      style: const TextStyle(fontSize: 11)),
                                  onDeleted: () => ref
                                      .read(catalogProvider.notifier)
                                      .setGenre('Все жанры'),
                                ),
                              if (catalogState.filter.country != 'Все страны')
                                Chip(
                                  label: Text(catalogState.filter.country,
                                      style: const TextStyle(fontSize: 11)),
                                  onDeleted: () => ref
                                      .read(catalogProvider.notifier)
                                      .setCountry('Все страны'),
                                ),
                              if (catalogState.filter.year != null)
                                Chip(
                                  label: Text('${catalogState.filter.year} г.',
                                      style: const TextStyle(fontSize: 11)),
                                  onDeleted: () => ref
                                      .read(catalogProvider.notifier)
                                      .setYear(null),
                                ),
                              TextButton(
                                onPressed: () {
                                  ref
                                      .read(catalogProvider.notifier)
                                      .resetFilters();
                                },
                                child: const Text('Сбросить фильтры',
                                    style: TextStyle(
                                        color: Colors.redAccent, fontSize: 11)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
              body: catalogState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : catalogState.items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off_rounded,
                                  size: 64, color: Colors.white24),
                              const SizedBox(height: 16),
                              const Text(
                                'Ничего не найдено',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Попробуйте изменить поисковый запрос или сбросить фильтры',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.clear_all_rounded),
                                label: const Text('Сбросить поиск и фильтры'),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  ref
                                      .read(catalogProvider.notifier)
                                      .resetFilters();
                                },
                              ),
                            ],
                          ),
                        )
                      : _buildCatalogGrid(catalogState.items, userTitles),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBtn(String category, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentCat = ref.watch(catalogProvider).filter.category;
    final isSelected = currentCat == category;

    return InkWell(
      onTap: () {
        ref.read(catalogProvider.notifier).setCategory(category);
        if (category != 'anime') {
          setState(() => _animeSubFilter = 'all');
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C3AED)
              : (isDark ? const Color(0xFF1E1E34) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF9F67FF)
                : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            if (!isDark && !isSelected)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAnimeSubFilterChip(String subFilter, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _animeSubFilter == subFilter;
    return InkWell(
      onTap: () => setState(() => _animeSubFilter = subFilter),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : (isDark ? const Color(0xFF1E1E38) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF818CF8)
                : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildCatalogGrid(List<CatalogItem> allItems, Set<String> userTitles) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentCat = ref.watch(catalogProvider).filter.category;
    List<CatalogItem> items = allItems;
    if (currentCat == 'anime') {
      if (_animeSubFilter == 'series') {
        items = allItems.where((i) => i.isSeries).toList();
      } else if (_animeSubFilter == 'movies') {
        items = allItems.where((i) => !i.isSeries).toList();
      }
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off_rounded,
                size: 56,
                color: isDark ? Colors.white24 : const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(
              _animeSubFilter == 'series'
                  ? 'В этой выборке нет аниме-сериалов'
                  : 'В этой выборке нет полнометражных фильмов',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => setState(() => _animeSubFilter = 'all'),
              child: const Text('Показать все аниме'),
            ),
          ],
        ),
      );
    }

    final catalogState = ref.watch(catalogProvider);
    final isLoadingMore = catalogState.isLoadingMore;
    final hasMore = catalogState.hasMore;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1280),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            // On desktop screens: 6 cards per row inside 1280px!
            int crossAxisCount = 6;
            if (w < 580) {
              crossAxisCount = 2;
            } else if (w < 840) {
              crossAxisCount = 3;
            } else if (w < 1080) {
              crossAxisCount = 4;
            } else {
              crossAxisCount = 6;
            }

            return NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo.metrics.extentAfter < 600 ||
                    scrollInfo.metrics.pixels >=
                        scrollInfo.metrics.maxScrollExtent - 600) {
                  ref.read(catalogProvider.notifier).loadMore();
                }
                return false;
              },
              child: GridView.builder(
                padding: EdgeInsets.fromLTRB(
                  w < 600 ? 12 : 28,
                  8,
                  w < 600 ? 12 : 28,
                  28,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: w < 600 ? 0.65 : 0.68,
                  crossAxisSpacing: w < 600 ? 10 : 16,
                  mainAxisSpacing: w < 600 ? 14 : 20,
                ),
                itemCount: items.length + (isLoadingMore || hasMore ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= items.length) {
                    if (isLoadingMore) {
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E1E34)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : const Color(0xFFCBD5E1)),
                          ),
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF9F67FF)),
                            ),
                          ),
                        ),
                      );
                    } else if (hasMore) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.read(catalogProvider.notifier).loadMore();
                      });
                      return Center(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              ref.read(catalogProvider.notifier).loadMore(),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Ещё фильмы',
                              style: TextStyle(fontSize: 12)),
                        ),
                      );
                    }
                    return const SizedBox();
                  }
                  final item = items[i];
                  final inColl =
                      userTitles.contains(item.title.toLowerCase().trim());
                  return CatalogCardWidget(
                    item: item,
                    alreadyInCollection: inColl,
                    onTap: () => _showMovieDetailDialog(item),
                    onAddToCollection: () => _addToMyCollection(item),
                    onSoloWatch: () => _startSoloWatch(item),
                    onPartyWatch: () => _startPartyWatch(item),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

