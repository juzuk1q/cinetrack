import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/catalog_item.dart';
import '../models/media_item.dart';

class MediaCard extends StatefulWidget {
  final MediaItem item;
  final bool listView;

  const MediaCard({super.key, required this.item, this.listView = false});

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  bool _isHovered = false;

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
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: InkWell(
            onTap: () => context.go('/media/${item.id}'),
            borderRadius: BorderRadius.circular(16),
            child: Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _isHovered
                      ? const Color(0xFF7C3AED)
                      : Colors.white10,
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
                        // Status badge
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _StatusBadge(status: item.status),
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
        onTap: () => context.go('/media/${item.id}'),
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
              // Right: status + rating
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatusBadge(status: item.status),
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

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    final icon = AppConstants.statusIcons[status] ?? '';
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(icon, style: const TextStyle(fontSize: 12)),
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
