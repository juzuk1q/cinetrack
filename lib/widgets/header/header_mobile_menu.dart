import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/catalog_item.dart';

class HeaderMobileMenu extends StatelessWidget {
  final TextEditingController searchCtrl;
  final FocusNode searchFocus;
  final String searchQuery;
  final List<CatalogItem> results;
  final bool isSearchingRemote;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<CatalogItem> onMovieSelected;
  final VoidCallback onSearchInLibrary;
  final String currentRoute;
  final int liveRoomsCount;
  final String displayName;
  final String? avatarUrl;
  final bool isAdmin;
  final VoidCallback onOpenRandomMovie;
  final VoidCallback onCloseMenu;

  const HeaderMobileMenu({
    super.key,
    required this.searchCtrl,
    required this.searchFocus,
    required this.searchQuery,
    required this.results,
    required this.isSearchingRemote,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onMovieSelected,
    required this.onSearchInLibrary,
    required this.currentRoute,
    required this.liveRoomsCount,
    required this.displayName,
    required this.avatarUrl,
    required this.isAdmin,
    required this.onOpenRandomMovie,
    required this.onCloseMenu,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mobile Search Input
          Container(
            height: 42,
            margin: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: searchCtrl,
              focusNode: searchFocus,
              onChanged: onSearchChanged,
              onSubmitted: (val) {
                onCloseMenu();
                onSearchSubmitted(val);
              },
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF1A1A2E)
                    : const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                hintText: 'Поиск фильмов, сериалов...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
                suffixIcon: searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          size: 16,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                        onPressed: () {
                          searchCtrl.clear();
                          onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                ),
              ),
            ),
          ),

          // If searching: show live search results
          if (searchQuery.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    'Найдено: ${results.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                  if (isSearchingRemote) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),
            if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'Ничего не найдено по запросу «$searchQuery»',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                  ),
                ),
              )
            else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: results.take(4).length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                  itemBuilder: (context, i) {
                    final movie = results[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      dense: true,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          CatalogItem.fixPosterUrl(movie.posterUrl, kpId: movie.kinopoiskId),
                          width: 30,
                          height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 30,
                            height: 42,
                            color: const Color(0xFF7C3AED),
                            child: const Icon(Icons.movie_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                      title: Text(
                        movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: Text(
                        '${movie.year} • ${movie.displayTypeLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '★ ${movie.rating.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                      onTap: () {
                        onCloseMenu();
                        onMovieSelected(movie);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () {
                  onCloseMenu();
                  onSearchInLibrary();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Смотреть все результаты в библиотеке →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC084FC),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],

          // 2-Column Grid of Navigation Buttons
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.8,
            children: [
              _buildMobileNavCard(
                label: 'Главная',
                icon: Icons.home_rounded,
                isSelected: currentRoute == '/home' || currentRoute == '/',
                isDark: isDark,
                onTap: () {
                  onCloseMenu();
                  context.go('/home');
                },
              ),
              _buildMobileNavCard(
                label: 'Каталог',
                icon: Icons.movie_filter_rounded,
                isSelected: currentRoute == '/library',
                isDark: isDark,
                onTap: () {
                  onCloseMenu();
                  context.go('/library');
                },
              ),
              _buildMobileNavCard(
                label: 'Комнаты 🍿',
                icon: Icons.live_tv_rounded,
                badgeCount: liveRoomsCount > 0 ? liveRoomsCount : null,
                isSelected: currentRoute.startsWith('/rooms'),
                isDark: isDark,
                onTap: () {
                  onCloseMenu();
                  context.go('/rooms');
                },
              ),
              _buildMobileNavCard(
                label: 'Коллекция',
                icon: Icons.bookmark_rounded,
                isSelected: currentRoute.startsWith('/profile'),
                isDark: isDark,
                onTap: () {
                  onCloseMenu();
                  context.go('/profile');
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Random Movie
          InkWell(
            onTap: () {
              onCloseMenu();
              onOpenRandomMovie();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: 0.25),
                    const Color(0xFF9333EA).withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🎲', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    'Случайный фильм',
                    style: TextStyle(
                      color: Color(0xFFC084FC),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // User Profile / Settings Footer Card
          InkWell(
            onTap: () {
              onCloseMenu();
              context.go('/profile');
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF16162A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: isAdmin ? const Color(0xFFF59E0B) : const Color(0xFF7C3AED),
                    backgroundImage: (avatarUrl ?? '').isNotEmpty ? NetworkImage(avatarUrl!) : null,
                    child: (avatarUrl ?? '').isEmpty
                        ? Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          isAdmin ? 'Администратор ⭐' : 'Перейти в профиль →',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isAdmin ? const Color(0xFFF59E0B) : const Color(0xFF9F67FF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAdmin)
                    IconButton(
                      icon: const Icon(Icons.admin_panel_settings_rounded, size: 20, color: Color(0xFFF59E0B)),
                      tooltip: 'Админ-панель',
                      onPressed: () {
                        onCloseMenu();
                        context.go('/admin');
                      },
                    )
                  else
                    const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Colors.white38),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileNavCard({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF7C3AED)
              : (isDark ? const Color(0xFF16162A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF9333EA)
                : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFF9F67FF) : const Color(0xFF7C3AED)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
