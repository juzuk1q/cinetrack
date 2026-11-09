import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/catalog_item.dart';
import '../models/media_item.dart';
import '../providers/media_provider.dart';
import '../providers/stats_provider.dart';
import 'top_notification.dart';

class MediaCard extends ConsumerStatefulWidget {
  final MediaItem item;
  final bool listView;

  const MediaCard({super.key, required this.item, this.listView = false});

  @override
  ConsumerState<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends ConsumerState<MediaCard> {
  bool _isHovered = false;

  void _openMovieDetail() {
    final item = widget.item;
    final target = (item.kinopoiskId != null && item.kinopoiskId! > 0)
        ? item.kinopoiskId.toString()
        : item.title;
    context.push('/movie/$target');
  }

  Future<void> _changeStatus(String newStatus) async {
    final item = widget.item;
    if (newStatus == 'delete') {
      try {
        await ref.read(mediaNotifierProvider.notifier).delete(item.id);
        ref.invalidate(mediaListProvider);
        ref.invalidate(statsDataProvider);
        if (mounted) {
          TopNotification.showSuccess(
            context,
            '«${item.title}» удалён из коллекции',
            title: 'Коллекция',
          );
        }
      } catch (e) {
        if (mounted) {
          TopNotification.showError(context, 'Ошибка удаления: $e');
        }
      }
      return;
    }

    try {
      final updated = item.copyWith(status: newStatus);
      await ref.read(mediaNotifierProvider.notifier).update(item.id, updated);
      ref.invalidate(mediaListProvider);
      ref.invalidate(statsDataProvider);
      if (mounted) {
        final label = AppConstants.statuses[newStatus] ?? newStatus;
        TopNotification.showSuccess(
          context,
          'Статус фильма «${item.title}» изменён на «$label»',
          title: 'Статус обновлен ⭐',
        );
      }
    } catch (e) {
      if (mounted) {
        TopNotification.showError(context, 'Ошибка обновления статуса: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.listView) return _buildListTile(context);
    return _buildGridCard(context);
  }

  Widget _buildGridCard(BuildContext context) {
    final item = widget.item;
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
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: InkWell(
            onTap: _openMovieDetail,
            borderRadius: BorderRadius.circular(16),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _isHovered
                      ? const Color(0xFF7C3AED)
                      : Colors.white12,
                  width: _isHovered ? 1.4 : 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Poster
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildPoster(),
                        // Type badge
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _TypeBadge(type: item.type),
                        ),
                        // Interactive Status menu selector
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _buildInteractiveStatusMenu(item.status),
                        ),
                      ],
                    ),
                  ),
                  // Info
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item.year != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${item.year}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                        if (item.rating != null) ...[
                          const SizedBox(height: 4),
                          _StarRatingSmall(rating: item.rating!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context) {
    final item = widget.item;
    return Card(
      child: InkWell(
        onTap: _openMovieDetail,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 52,
                  height: 74,
                  child: _buildPoster(),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _TypeBadge(type: item.type),
                        if (item.year != null) ...[
                          const SizedBox(width: 8),
                          Text('${item.year}',
                              style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ],
                    ),
                    if (item.genres.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.genres.take(3).join(', '),
                        style: Theme.of(context).textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Right: status selector + rating
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildInteractiveStatusMenu(item.status),
                  if (item.rating != null) ...[
                    const SizedBox(height: 6),
                    _RatingBadge(rating: item.rating!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveStatusMenu(String currentStatus) {
    final color = AppTheme.statusColor(currentStatus);
    final icon = AppConstants.statusIcons[currentStatus] ?? '📋';
    final label = AppConstants.statuses[currentStatus] ?? currentStatus;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: const Color(0xFF1E1E34),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white12),
          ),
        ),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Изменить статус ($label)',
        padding: EdgeInsets.zero,
        onSelected: _changeStatus,
        itemBuilder: (ctx) => [
          _buildStatusPopupItem(
            value: 'want_to_watch',
            icon: '🕒',
            text: 'Хочу посмотреть',
            isSelected: currentStatus == 'want_to_watch',
          ),
          _buildStatusPopupItem(
            value: 'watching',
            icon: '🍿',
            text: 'Смотрю',
            isSelected: currentStatus == 'watching',
          ),
          _buildStatusPopupItem(
            value: 'watched',
            icon: '✅',
            text: 'Просмотрено',
            isSelected: currentStatus == 'watched',
          ),
          const PopupMenuDivider(height: 1),
          const PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                SizedBox(width: 8),
                Text(
                  'Удалить из коллекции',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                ),
              ],
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 3),
              const Icon(Icons.arrow_drop_down_rounded, size: 14, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildStatusPopupItem({
    required String value,
    required String icon,
    required String text,
    required bool isSelected,
  }) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? const Color(0xFF9F67FF) : Colors.white,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_rounded, size: 16, color: Color(0xFF9F67FF)),
        ],
      ),
    );
  }

  Widget _buildPoster() {
    if (widget.item.posterUrl != null && widget.item.posterUrl!.isNotEmpty) {
      return Image.network(
        CatalogItem.fixPosterUrl(widget.item.posterUrl),
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFF252540),
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: const Color(0xFF7C3AED),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => _placeholderPoster(),
      );
    }
    return _placeholderPoster();
  }

  Widget _placeholderPoster() {
    return Container(
      color: const Color(0xFF252540),
      child: Center(
        child: Icon(
          widget.item.type == 'cartoon'
              ? Icons.animation_rounded
              : widget.item.type == 'series'
                  ? Icons.tv_rounded
                  : Icons.movie_rounded,
          size: 36,
          color: Colors.white12,
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 0.8),
      ),
      child: Text(
        AppConstants.mediaTypes[type] ?? type,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final int rating;
  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFCA28).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: const Color(0xFFFFCA28).withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFCA28)),
          const SizedBox(width: 2),
          Text(
            '$rating',
            style: const TextStyle(
              color: Color(0xFFFFCA28),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarRatingSmall extends StatelessWidget {
  final int rating;
  const _StarRatingSmall({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFFCA28)),
        const SizedBox(width: 3),
        Text(
          '$rating/10',
          style: const TextStyle(
            color: Color(0xFFFFCA28),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
