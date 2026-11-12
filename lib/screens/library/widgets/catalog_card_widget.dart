import 'package:flutter/material.dart';
import '../../../models/catalog_item.dart';

class CatalogCardWidget extends StatefulWidget {
  final CatalogItem item;
  final bool alreadyInCollection;
  final VoidCallback onTap;
  final VoidCallback onAddToCollection;
  final VoidCallback onSoloWatch;
  final VoidCallback onPartyWatch;

  const CatalogCardWidget({super.key, 
    required this.item,
    required this.alreadyInCollection,
    required this.onTap,
    required this.onAddToCollection,
    required this.onSoloWatch,
    required this.onPartyWatch,
  });

  @override
  State<CatalogCardWidget> createState() => _CatalogCardWidgetState();
}

class _CatalogCardWidgetState extends State<CatalogCardWidget> {
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
