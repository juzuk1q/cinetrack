import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/media_item.dart';
import '../../providers/media_provider.dart';
import '../../widgets/app_sidebar.dart';

class MediaDetailScreen extends ConsumerWidget {
  final String mediaId;
  const MediaDetailScreen({super.key, required this.mediaId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(mediaItemProvider(mediaId));

    return Scaffold(
      body: Row(
        children: [
          const AppSidebar(selectedIndex: 1),
          Expanded(
            child: itemAsync.when(
              data: (item) {
                if (item == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Запись не найдена'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => context.go('/library'),
                          child: const Text('Назад к списку'),
                        ),
                      ],
                    ),
                  );
                }

                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      automaticallyImplyLeading: false,
                      expandedHeight: 240,
                      pinned: true,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => context.go('/library'),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        background: item.posterUrl != null &&
                                item.posterUrl!.isNotEmpty
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.network(
                                    item.posterUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _buildPosterPlaceholder(item),
                                  ),
                                  Container(
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
                                ],
                              )
                            : _buildPosterPlaceholder(item),
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.edit_rounded),
                          tooltip: 'Редактировать',
                          onPressed: () =>
                              context.go('/media/$mediaId/edit'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          tooltip: 'Удалить',
                          onPressed: () =>
                              _confirmDelete(context, ref),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Type + Status chips
                          Wrap(
                            spacing: 8,
                            children: [
                              _TypeChip(type: item.type),
                              _StatusChip(status: item.status),
                              if (item.year != null)
                                Chip(label: Text('${item.year}')),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Genres
                          if (item.genres.isNotEmpty) ...[
                            _buildSection(
                              context,
                              'Жанры',
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: item.genres
                                    .map((g) => Chip(
                                          label: Text(g),
                                          visualDensity:
                                              VisualDensity.compact,
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Rating
                          if (item.rating != null)
                            _buildSection(
                              context,
                              'Оценка',
                              Row(
                                children: [
                                  RatingBarIndicator(
                                    rating: item.rating! / 2.0,
                                    itemBuilder: (context, _) => const Icon(
                                        Icons.star_rounded,
                                        color: Color(0xFFFFCA28)),
                                    itemCount: 5,
                                    itemSize: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '${item.rating}/10',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFFCA28),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          if (item.rating != null) const SizedBox(height: 16),

                          // Director
                          if (item.director != null &&
                              item.director!.isNotEmpty)
                            _buildInfoRow(
                                context, 'Режиссёр', item.director!),

                          // Actors
                          if (item.actors != null &&
                              item.actors!.isNotEmpty)
                            _buildInfoRow(context, 'Актёры', item.actors!),

                          // Planned date
                          if (item.plannedDate != null)
                            _buildInfoRow(
                              context,
                              'Дата просмотра',
                              DateFormat('d MMMM y', 'ru')
                                  .format(item.plannedDate!),
                            ),

                          // Description
                          if (item.description != null &&
                              item.description!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildSection(
                              context,
                              'Описание',
                              Text(
                                item.description!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],

                          // Review
                          if (item.review != null &&
                              item.review!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildSection(
                              context,
                              'Мой отзыв',
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF252540),
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  item.review!,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Where to watch online
                          _buildStreamingSection(context, item),

                          const SizedBox(height: 24),

                          // Meta info
                          Text(
                            'Добавлено: ${DateFormat('d MMMM y, HH:mm', 'ru').format(item.createdAt.toLocal())}',
                            style:
                                Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 40),
                        ]),
                      ),
                    ),
                  ],
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Ошибка: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterPlaceholder(item) {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: const Center(
        child: Icon(Icons.movie_rounded, size: 80, color: Colors.white12),
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF9F67FF),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  Widget _buildInfoRow(
      BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF9F67FF),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingSection(BuildContext context, MediaItem item) {
    final query = Uri.encodeComponent('${item.title} ${item.year ?? ''}');
    return _buildSection(
      context,
      'ГДЕ СМОТРЕТЬ ОНЛАЙН',
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _StreamingPill(
            label: 'Lordfilm',
            icon: Icons.movie_filter_rounded,
            color: const Color(0xFFF59E0B),
            url: 'https://yandex.ru/search/?text=${Uri.encodeComponent('lordfilm ${item.title} ${item.year ?? ''}')}',
          ),
          _StreamingPill(
            label: 'Кинопоиск',
            icon: Icons.play_circle_fill_rounded,
            color: const Color(0xFFFF5500),
            url: 'https://www.kinopoisk.ru/index.php?kp_query=$query',
          ),
          _StreamingPill(
            label: 'Иви (ivi)',
            icon: Icons.movie_creation_rounded,
            color: const Color(0xFFEA125E),
            url: 'https://www.ivi.ru/search/?q=$query',
          ),
          _StreamingPill(
            label: 'Трейлер (YouTube)',
            icon: Icons.video_library_rounded,
            color: const Color(0xFFFF0000),
            url: 'https://www.youtube.com/results?search_query=${Uri.encodeComponent('${item.title} ${item.year ?? ''} трейлер')}',
          ),
          _StreamingPill(
            label: 'Поиск онлайн',
            icon: Icons.search_rounded,
            color: const Color(0xFF3B82F6),
            url: 'https://yandex.ru/search/?text=${Uri.encodeComponent('${item.title} ${item.year ?? ''} смотреть онлайн')}',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: const Text(
            'Это действие нельзя отменить. Запись будет удалена навсегда.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final success =
        await ref.read(mediaNotifierProvider.notifier).delete(mediaId);

    if (!context.mounted) return;
    if (success) {
      ref.invalidate(mediaListProvider);
      context.go('/library');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запись удалена')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при удалении'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        AppConstants.mediaTypes[type] ?? type,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppConstants.statusIcons[status] ?? '',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(width: 4),
          Text(
            AppConstants.statuses[status] ?? status,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StreamingPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String url;

  const _StreamingPill({
    required this.label,
    required this.icon,
    required this.color,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => launchUrl(
        Uri.parse(url),
        mode: LaunchMode.platformDefault,
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new_rounded, size: 13, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
