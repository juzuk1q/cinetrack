import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/catalog_item.dart';
import '../../models/media_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kinopoisk_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/stats_provider.dart';
import '../../services/kinopoisk_service.dart';
import '../../widgets/app_header.dart';
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
    } catch (_) {}
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
                  return _CatalogCardWidget(
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

class _CatalogCardWidget extends StatefulWidget {
  final CatalogItem item;
  final bool alreadyInCollection;
  final VoidCallback onTap;
  final VoidCallback onAddToCollection;
  final VoidCallback onSoloWatch;
  final VoidCallback onPartyWatch;

  const _CatalogCardWidget({
    required this.item,
    required this.alreadyInCollection,
    required this.onTap,
    required this.onAddToCollection,
    required this.onSoloWatch,
    required this.onPartyWatch,
  });

  @override
  State<_CatalogCardWidget> createState() => _CatalogCardWidgetState();
}

class _CatalogCardWidgetState extends State<_CatalogCardWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final alreadyInCollection = widget.alreadyInCollection;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16162A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF7C3AED)
                  : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              width: _isHovered ? 1.4 : 1,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED)
                          .withValues(alpha: isDark ? 0.35 : 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.26 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poster & click for details
              Expanded(
                flex: 8,
                child: InkWell(
                  onTap: widget.onTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        CatalogItem.fixPosterUrl(item.posterUrl),
                        fit: BoxFit.cover,
                        headers: const {'Referer': ''},
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1A1A2E),
                          child: const Center(
                            child: Icon(Icons.movie_rounded,
                                size: 36, color: Colors.white24),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),
                      ),

                      // Top Left: Compact Rating Badge
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFFFCA28).withValues(alpha: 0.8),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 11, color: Color(0xFFFFCA28)),
                              const SizedBox(width: 3),
                              Text(
                                item.rating > 0
                                    ? item.rating.toStringAsFixed(1)
                                    : (item.ratingImdb != null && item.ratingImdb! > 0
                                        ? item.ratingImdb!.toStringAsFixed(1)
                                        : '—'),
                                style: const TextStyle(
                                  color: Color(0xFFFFCA28),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Top Right: Format Pill + Bookmark button
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: item.isSeries
                                    ? const Color(0xFF6366F1)
                                    : const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                item.isSeries ? 'СЕРИАЛ' : 'ФИЛЬМ',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            InkWell(
                              onTap: widget.onAddToCollection,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(4.5),
                                decoration: BoxDecoration(
                                  color: alreadyInCollection
                                      ? const Color(0xFF10B981)
                                      : Colors.black.withValues(alpha: 0.7),
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
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Bottom on poster: Title, original title and genres
                      Positioned(
                        bottom: 6,
                        left: 8,
                        right: 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item.title} (${item.year})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.nameOriginal != null &&
                                item.nameOriginal!.isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                item.nameOriginal!,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 9.5,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (item.isSeries)
                                  Container(
                                    margin: const EdgeInsets.only(right: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(
                                          color: const Color(0xFF10B981),
                                          width: 0.5),
                                    ),
                                    child: const Text(
                                      'по сериям',
                                      style: TextStyle(
                                        color: Color(0xFF34D399),
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    item.genres.join(', '),
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 10),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Watch Mode Buttons (Taller and comfortable: 40px)
              Padding(
                padding: const EdgeInsets.all(7),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 17),
                          label: const Text(
                            'Смотреть',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                          onPressed: widget.onSoloWatch,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    SizedBox(
                      height: 38,
                      child: InkWell(
                        onTap: widget.onPartyWatch,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFF7C3AED), width: 1),
                          ),
                          child: const Tooltip(
                            message: 'Смотреть с друзьями 🍿',
                            child: Icon(Icons.groups_rounded,
                                size: 18, color: Color(0xFFC084FC)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rich Movie / Series Detail Dialog
class _MovieDetailDialog extends StatefulWidget {
  final CatalogItem item;
  final VoidCallback onSoloWatch;
  final VoidCallback onPartyWatch;
  final VoidCallback onAddToCollection;

  const _MovieDetailDialog({
    required this.item,
    required this.onSoloWatch,
    required this.onPartyWatch,
    required this.onAddToCollection,
  });

  @override
  State<_MovieDetailDialog> createState() => _MovieDetailDialogState();
}

class _MovieDetailDialogState extends State<_MovieDetailDialog> {
  late CatalogItem _item;
  bool _isLoadingFull = false;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    if (_item.kinopoiskId != null) {
      _fetchFullDetails();
    }
  }

  Future<void> _fetchFullDetails() async {
    setState(() => _isLoadingFull = true);
    try {
      final full = await KinopoiskService().getFilmById(_item.kinopoiskId!);
      if (full != null && mounted) {
        setState(() {
          _item = full;
          _isLoadingFull = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingFull = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141426),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.white12),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top title & close row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (_item.nameOriginal != null &&
                            _item.nameOriginal!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            _item.nameOriginal!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Закрыть карточку',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Colors.white12),
              const SizedBox(height: 16),

              // Main info area (Poster + Metadata + Synopsis)
              Expanded(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Poster
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 170,
                          height: 250,
                          color: const Color(0xFF1A1A2E),
                          child: Image.network(
                            _item.posterUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.movie_rounded,
                                  size: 48, color: Colors.white24),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Right: Meta tags & Full Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Badges row: Type, Year, Rating
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _item.isSeries
                                        ? const Color(0xFF6366F1)
                                        : AppTheme.typeColor(_item.type)
                                            .withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _item.displayTypeLabel,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white12,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_item.year} год',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFCA28)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color: const Color(0xFFFFCA28),
                                        width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 15, color: Color(0xFFFFCA28)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_item.rating.toStringAsFixed(1)} (Кинопоиск)',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Series / Episodes & Voiceovers player feature callout
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: _item.isSeries
                                    ? const Color(0xFF6366F1)
                                        .withValues(alpha: 0.12)
                                    : const Color(0xFF10B981)
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _item.isSeries
                                      ? const Color(0xFF6366F1)
                                          .withValues(alpha: 0.35)
                                      : const Color(0xFF10B981)
                                          .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _item.isSeries
                                        ? Icons.playlist_play_rounded
                                        : Icons.high_quality_rounded,
                                    size: 20,
                                    color: _item.isSeries
                                        ? const Color(0xFF818CF8)
                                        : const Color(0xFF34D399),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _item.isSeries
                                          ? '📺 В плеере доступен выбор всех серий (1, 2, 3...), сезонов и озвучек (Дубляж, AniLibria, Студийная банда, SHIZA Project и др.)'
                                          : '🎬 В плеере доступно качество Full HD / 4K с выбором профессионального дубляжа и субтитров',
                                      style: TextStyle(
                                        color: _item.isSeries
                                            ? const Color(0xFFC7D2FE)
                                            : const Color(0xFFA7F3D0),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Genres
                            if (_item.genres.isNotEmpty) ...[
                              Text(
                                'Жанры: ${_item.genres.join(', ')}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],

                            // Countries
                            if (_item.countries.isNotEmpty) ...[
                              Text(
                                'Страны: ${_item.countries.join(', ')}',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            const Text(
                              'СЮЖЕТ И ОПИСАНИЕ:',
                              style: TextStyle(
                                color: Color(0xFF9F67FF),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 6),

                            if (_isLoadingFull &&
                                _item.description.contains('временно'))
                              const Row(
                                children: [
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Загружаем подробное описание с Кинопоиска...',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              )
                            else
                              Text(
                                _item.description,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  height: 1.45,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: Colors.white12),
              const SizedBox(height: 14),

              // Bottom Actions: Watch Solo, Watch with friends, Add to Collection
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                    ),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text('В коллекцию'),
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onAddToCollection();
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.groups_rounded, size: 18),
                    label: const Text('Смотреть с друзьями 🍿'),
                    onPressed: widget.onPartyWatch,
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      'СМОТРЕТЬ ОНЛАЙН',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: widget.onSoloWatch,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
