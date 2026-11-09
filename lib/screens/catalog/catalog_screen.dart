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
import '../../providers/stats_provider.dart';
import '../../widgets/app_header.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String _selectedType = 'all';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CatalogItem> _getFilteredItems() {
    return CuratedCatalog.items.where((item) {
      if (_selectedType != 'all' && item.type != _selectedType) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = item.title.toLowerCase().contains(q);
        final matchDirector = item.director.toLowerCase().contains(q);
        final matchActors = item.actors.toLowerCase().contains(q);
        final matchGenre =
            item.genres.any((g) => g.toLowerCase().contains(q));
        if (!matchTitle && !matchDirector && !matchActors && !matchGenre) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _addToMyCollection(CatalogItem catalogItem) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, войдите в систему')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${catalogItem.title}» добавлен в коллекцию!'),
          backgroundColor: const Color(0xFF7C3AED),
          action: SnackBarAction(
            label: 'Перейти',
            textColor: Colors.white,
            onPressed: () => context.go('/media'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка добавления: $e'),
          backgroundColor: Colors.red[700],
        ),
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

    final filtered = _getFilteredItems();

    return Scaffold(
      body: Column(
        children: [
          const AppHeader(activeRoute: '/library'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // AppBar
                const SliverAppBar(
                  automaticallyImplyLeading: false,
                  floating: true,
                  title: Text('Библиотека и каталог фильмов'),
                ),

                // Top banner & filters
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Готовая коллекция шедевров мирового кинематографа. Выберите фильм, сериал или мультфильм и добавьте в свой трекер в один клик!',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                        const SizedBox(height: 16),

                        // Search
                        TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Поиск по названию, режиссёру или жанру...',
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

                        // Filter chips
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildFilterChip('all', 'Все категории', Icons.all_inclusive_rounded),
                            _buildFilterChip('movie', 'Фильмы', Icons.movie_outlined),
                            _buildFilterChip('series', 'Сериалы', Icons.tv_outlined),
                            _buildFilterChip('cartoon', 'Мультфильмы', Icons.animation_outlined),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Grid of items
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 320,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = filtered[index];
                        final alreadyInCollection =
                            userTitles.contains(item.title.toLowerCase().trim());
                        return _buildCatalogCard(item, alreadyInCollection);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
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
      onSelected: (_) => setState(() => _selectedType = type),
    );
  }

  Widget _buildCatalogCard(CatalogItem item, bool alreadyInCollection) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Poster with badges
          Expanded(
            flex: 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  item.posterUrl,
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Rating badge
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFFCA28), width: 0.8),
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
                            fontWeight: FontWeight.w700,
                          ),
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
                      const SizedBox(height: 2),
                      Text(
                        item.genres.join(', '),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Description snippet
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                height: 1.25,
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Row(
              children: [
                // Watch online Lordfilm button
                IconButton.filledTonal(
                  icon: const Icon(Icons.movie_filter_rounded, size: 18, color: Color(0xFFF59E0B)),
                  tooltip: 'Смотреть на Lordfilm',
                  onPressed: () {
                    final query = Uri.encodeComponent('lordfilm ${item.title} ${item.year}');
                    launchUrl(
                      Uri.parse('https://yandex.ru/search/?text=$query'),
                      mode: LaunchMode.platformDefault,
                    );
                  },
                ),
                const SizedBox(width: 4),
                // Watch online Kinopoisk button
                IconButton.filledTonal(
                  icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                  tooltip: 'Смотреть онлайн (Кинопоиск)',
                  onPressed: () {
                    final query = Uri.encodeComponent('${item.title} ${item.year}');
                    launchUrl(
                      Uri.parse('https://www.kinopoisk.ru/index.php?kp_query=$query'),
                      mode: LaunchMode.platformDefault,
                    );
                  },
                ),
                const SizedBox(width: 8),

                // Add to collection button
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      backgroundColor: alreadyInCollection
                          ? const Color(0xFF10B981)
                          : const Color(0xFF7C3AED),
                    ),
                    icon: Icon(
                      alreadyInCollection
                          ? Icons.check_circle_rounded
                          : Icons.bookmark_add_rounded,
                      size: 16,
                    ),
                    label: Text(
                      alreadyInCollection ? 'В коллекции' : 'В коллекцию',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: alreadyInCollection
                        ? null
                        : () => _addToMyCollection(item),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
