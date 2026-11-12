import '../../../core/theme.dart';
import 'package:flutter/material.dart';
import '../../../models/catalog_item.dart';
import '../../../services/kinopoisk_service.dart';

class LibraryMovieDetailDialog extends StatefulWidget {
  final CatalogItem item;
  final VoidCallback onSoloWatch;
  final VoidCallback onPartyWatch;
  final VoidCallback onAddToCollection;

  const LibraryMovieDetailDialog({super.key, 
    required this.item,
    required this.onSoloWatch,
    required this.onPartyWatch,
    required this.onAddToCollection,
  });

  @override
  State<LibraryMovieDetailDialog> createState() => _MovieDetailDialogState();
}

class _MovieDetailDialogState extends State<LibraryMovieDetailDialog> {
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
    } catch (e) {
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
