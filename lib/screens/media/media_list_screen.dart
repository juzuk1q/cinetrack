import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/media_provider.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/media_card.dart';

class MediaListScreen extends ConsumerStatefulWidget {
  const MediaListScreen({super.key});

  @override
  ConsumerState<MediaListScreen> createState() => _MediaListScreenState();
}

class _MediaListScreenState extends ConsumerState<MediaListScreen> {
  final _searchController = TextEditingController();
  bool _isGridView = true;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(mediaListProvider);
    final filters = ref.watch(filtersProvider);

    return Scaffold(
      body: Row(
        children: [
          const AppSidebar(selectedIndex: 1),
          Expanded(
            child: Column(
              children: [
                // Top bar
                _buildTopBar(context),

                // Filter bar
                const FilterBar(),

                // Content
                Expanded(
                  child: mediaAsync.when(
                    data: (items) {
                      if (items.isEmpty) {
                        return _buildEmpty(filters.hasActiveFilters);
                      }
                      if (_isGridView) {
                        return GridView.builder(
                          padding: const EdgeInsets.all(24),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, i) =>
                              MediaCard(item: items[i]),
                        );
                      } else {
                        return ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) =>
                              MediaCard(item: items[i], listView: true),
                        );
                      }
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(
                      child: Text('Ошибка загрузки: $e',
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/media/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить'),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Text(
            'Моя коллекция',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Поиск по названию, актёру...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(filtersProvider.notifier)
                              .setSearch('');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
              onChanged: (v) {
                ref.read(filtersProvider.notifier).setSearch(v);
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: Icon(
              _isGridView
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
            tooltip: _isGridView ? 'Список' : 'Сетка',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool hasFilters) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasFilters
                ? Icons.filter_list_off_rounded
                : Icons.movie_creation_outlined,
            size: 64,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters
                ? 'По вашему запросу ничего не найдено'
                : 'Ваша коллекция пуста',
            style: const TextStyle(color: Colors.white54, fontSize: 16),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                ref.read(filtersProvider.notifier).reset();
                _searchController.clear();
              },
              icon: const Icon(Icons.clear_all_rounded),
              label: const Text('Сбросить фильтры'),
            ),
          ],
        ],
      ),
    );
  }
}
