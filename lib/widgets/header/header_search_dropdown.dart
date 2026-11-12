import 'package:flutter/material.dart';
import '../../models/catalog_item.dart';

class HeaderSearchDropdown extends StatelessWidget {
  final List<CatalogItem> results;
  final String searchQuery;
  final bool isSearchingRemote;
  final ValueChanged<CatalogItem> onMovieSelected;
  final VoidCallback onSearchInLibrary;

  const HeaderSearchDropdown({
    super.key,
    required this.results,
    required this.searchQuery,
    required this.isSearchingRemote,
    required this.onMovieSelected,
    required this.onSearchInLibrary,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.5 : 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.7 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF1E1E34) : const Color(0xFFF1F5F9),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 16, color: Color(0xFF9F67FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Результаты поиска: «$searchQuery»',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSearchingRemote) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9F67FF)),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${results.length} найдено',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Ничего не найдено по запросу «$searchQuery»',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: results.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
                itemBuilder: (context, i) {
                  final movie = results[i];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      hoverColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                      onTap: () => onMovieSelected(movie),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                CatalogItem.fixPosterUrl(movie.posterUrl, kpId: movie.kinopoiskId),
                                width: 38,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 38,
                                  height: 52,
                                  color: const Color(0xFF7C3AED),
                                  child: const Icon(Icons.movie_rounded, size: 20, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${movie.year} • ${movie.displayTypeLabel} • ${movie.genres.take(2).join(', ')}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '★ ${movie.rating.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Material(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
            child: InkWell(
              onTap: onSearchInLibrary,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: const Text(
                  'Искать по всему каталогу в библиотеке →',
                  style: TextStyle(
                    color: Color(0xFFC084FC),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
