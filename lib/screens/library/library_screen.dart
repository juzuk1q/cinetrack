import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../data/curated_catalog.dart';
import '../../models/catalog_item.dart';
import '../../models/media_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/media_card.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _selectedType = 'all';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CatalogItem> _getFilteredCatalog() {
    return CuratedCatalog.items.where((item) {
      if (_selectedType != 'all' && item.type != _selectedType) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = item.title.toLowerCase().contains(q) ||
            item.director.toLowerCase().contains(q) ||
            item.genres.any((g) => g.toLowerCase().contains(q));
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  void _startSoloWatch(String title, int? year) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E34),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final query = Uri.encodeComponent('$title ${year?.toString() ?? ''}');
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_rounded, color: Color(0xFF9F67FF)),
                  const SizedBox(width: 10),
                  Text(
                    'Одиночный просмотр: $title',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Выберите сервис для просмотра:',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white12)),
                leading: const Icon(Icons.movie_filter_rounded,
                    color: Color(0xFFF59E0B)),
                title: const Text('Смотреть на Lordfilm'),
                subtitle: const Text('Бесплатный плеер со всеми озвучками',
                    style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(
                    Uri.parse('https://yandex.ru/search/?text=${Uri.encodeComponent('lordfilm $title ${year ?? ''}')}'),
                    mode: LaunchMode.platformDefault,
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white12)),
                leading: const Icon(Icons.play_circle_fill_rounded,
                    color: Color(0xFFFF5500)),
                title: const Text('Смотреть на Кинопоиске'),
                subtitle: const Text('Официальное высокое качество',
                    style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.open_in_new_rounded, size: 16),
                onTap: () {
                  Navigator.pop(ctx);
                  launchUrl(
                    Uri.parse('https://www.kinopoisk.ru/index.php?kp_query=$query'),
                    mode: LaunchMode.platformDefault,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _startPartyWatch(String title, String type, String? poster, int? year) {
    final user = ref.read(currentUserProvider);
    final ownerName = user?.email?.split('@').first ?? 'Организатор';

    final room = ref.read(roomsProvider.notifier).createRoom(
          title: 'Совместный просмотр: $title',
          movieTitle: title,
          movieType: type,
          moviePoster: poster,
          movieYear: year,
          scheduledAt: DateTime.now(),
          ownerName: ownerName,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Комната для «$title» создана! Подключаем к чату...'),
        backgroundColor: const Color(0xFF7C3AED),
      ),
    );

    context.go('/rooms/${room.id}');
  }

  Future<void> _addToMyCollection(CatalogItem catalogItem) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${catalogItem.title}» добавлен в коллекцию!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userMediaAsync = ref.watch(mediaListProvider);
    final userTitles = userMediaAsync.maybeWhen(
      data: (items) => items.map((e) => e.title.toLowerCase().trim()).toSet(),
      orElse: () => <String>{},
    );

    final catalogItems = _getFilteredCatalog();

    return Scaffold(
      body: Row(
        children: [
          const AppSidebar(selectedIndex: 1),
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  pinned: true,
                  floating: true,
                  title: const Text('Библиотека фильмов и сериалов'),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Свой фильм'),
                        onPressed: () => context.go('/media/add'),
                      ),
                    ),
                  ],
                  bottom: TabBar(
                    controller: _tabCtrl,
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.public_rounded),
                        text: 'Каталог фильмов & Сериалов',
                      ),
                      Tab(
                        icon: Icon(Icons.bookmark_added_rounded),
                        text: 'Моя коллекция',
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search bar
                        TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Поиск фильма, сериала или мультфильма...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (v) =>
                              setState(() => _searchQuery = v.trim()),
                        ),
                        const SizedBox(height: 12),

                        // Categories
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip('all', 'Все'),
                            _buildFilterChip('movie', 'Фильмы'),
                            _buildFilterChip('series', 'Сериалы'),
                            _buildFilterChip('cartoon', 'Мультфильмы'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabCtrl,
                children: [
                  // Tab 1: Catalog
                  _buildCatalogGrid(catalogItems, userTitles),

                  // Tab 2: User's personal collection
                  _buildUserCollectionTab(userMediaAsync),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type, String label) {
    final selected = _selectedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedType = type),
    );
  }

  Widget _buildCatalogGrid(
      List<CatalogItem> items, Set<String> userTitles) {
    if (items.isEmpty) {
      return const Center(child: Text('Ничего не найдено'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 360,
        childAspectRatio: 0.72,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final inColl = userTitles.contains(item.title.toLowerCase().trim());
        return _buildCatalogCard(item, inColl);
      },
    );
  }

  Widget _buildCatalogCard(CatalogItem item, bool alreadyInCollection) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poster
          Expanded(
            flex: 8,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  item.posterUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1A1A2E),
                    child: const Icon(Icons.movie_rounded, size: 48),
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
                // Type badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.typeColor(item.type).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      AppConstants.mediaTypes[item.type] ?? item.type,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                // Rating
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFFFFCA28), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFFFCA28)),
                        const SizedBox(width: 4),
                        Text(
                          item.rating.toStringAsFixed(1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                // Title and genres
                Positioned(
                  bottom: 8,
                  left: 10,
                  right: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.title} (${item.year})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        item.genres.join(', '),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Two Watch Mode Buttons: Solo vs Party
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    // Solo watch button
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          side: const BorderSide(color: Color(0xFFF59E0B)),
                        ),
                        icon: const Icon(Icons.person_rounded,
                            size: 15, color: Color(0xFFF59E0B)),
                        label: const Text('Один',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFF59E0B))),
                        onPressed: () =>
                            _startSoloWatch(item.title, item.year),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Party watch button (with live chat)
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          backgroundColor: const Color(0xFF7C3AED),
                        ),
                        icon: const Icon(Icons.groups_rounded, size: 15),
                        label: const Text('С друзьями 🍿',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => _startPartyWatch(
                            item.title, item.type, item.posterUrl, item.year),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Add to collection button
                InkWell(
                  onTap: alreadyInCollection
                      ? null
                      : () => _addToMyCollection(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          alreadyInCollection
                              ? Icons.bookmark_added_rounded
                              : Icons.bookmark_add_outlined,
                          size: 14,
                          color: alreadyInCollection
                              ? const Color(0xFF10B981)
                              : Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          alreadyInCollection
                              ? 'В вашей коллекции'
                              : '+ В коллекцию («Хочу посмотреть»)',
                          style: TextStyle(
                            fontSize: 11,
                            color: alreadyInCollection
                                ? const Color(0xFF10B981)
                                : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCollectionTab(AsyncValue<List<MediaItem>> userMediaAsync) {
    return userMediaAsync.when(
      data: (items) {
        var filtered = items;
        if (_selectedType != 'all') {
          filtered = filtered.where((e) => e.type == _selectedType).toList();
        }
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          filtered = filtered
              .where((e) => e.title.toLowerCase().contains(q))
              .toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.movie_filter_outlined,
                    size: 56, color: Colors.white24),
                const SizedBox(height: 12),
                const Text('В вашей коллекции пока нет таких записей',
                    style: TextStyle(color: Colors.white54)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Добавить фильм'),
                  onPressed: () => context.go('/media/add'),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 0.62,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, i) => MediaCard(item: filtered[i]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Ошибка: $e')),
    );
  }
}
