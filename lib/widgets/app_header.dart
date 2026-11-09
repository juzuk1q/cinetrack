import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/curated_catalog.dart';
import '../models/catalog_item.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';
import '../providers/theme_provider.dart';
import 'top_notification.dart';

class AppHeader extends ConsumerStatefulWidget implements PreferredSizeWidget {
  final String? activeRoute;

  const AppHeader({super.key, this.activeRoute});

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  ConsumerState<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends ConsumerState<AppHeader> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  String _searchQuery = '';
  Timer? _blurTimer;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) {
        _blurTimer?.cancel();
        _blurTimer = Timer(const Duration(milliseconds: 250), () {
          if (mounted && !_searchFocus.hasFocus) {
            _hideSearchOverlay();
          }
        });
      } else if (_searchQuery.isNotEmpty) {
        _blurTimer?.cancel();
        _showSearchOverlay();
      }
    });
  }

  @override
  void dispose() {
    _blurTimer?.cancel();
    _hideSearchOverlay();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val.trim();
    });
    if (_searchQuery.isNotEmpty) {
      _blurTimer?.cancel();
      _showSearchOverlay();
    } else {
      _hideSearchOverlay();
    }
  }

  void _onMovieSelected(CatalogItem movie) {
    _blurTimer?.cancel();
    _hideSearchOverlay();
    _searchFocus.unfocus();
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
    });
    context.push('/movie/${movie.kinopoiskId ?? movie.title}', extra: movie);
  }

  void _showSearchOverlay() {
    if (_overlayEntry == null) {
      final overlayState = Overlay.of(context, rootOverlay: true);
      _overlayEntry = OverlayEntry(
        builder: (ctx) => Positioned(
          width: 440,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(-40, 48),
            child: Material(
              color: Colors.transparent,
              child: _buildSearchDropdown(),
            ),
          ),
        ),
      );
      overlayState.insert(_overlayEntry!);
    } else {
      _overlayEntry!.markNeedsBuild();
    }
  }

  void _hideSearchOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _openRandomMovie() {
    const list = CuratedCatalog.items;
    if (list.isEmpty) return;
    final randomItem = list[Random().nextInt(list.length)];
    TopNotification.showSuccess(
      context,
      'Выбран фильм: «${randomItem.title}» (${randomItem.year}) 🎲',
      title: 'Случайный фильм 🎲',
    );
    context.push('/movie/${randomItem.kinopoiskId ?? randomItem.title}', extra: randomItem);
  }

  Widget _buildSearchDropdown() {
    final q = _searchQuery.toLowerCase();
    final results = CuratedCatalog.items.where((item) {
      final matchTitle = item.title.toLowerCase().contains(q);
      final matchOriginal = item.nameOriginal?.toLowerCase().contains(q) ?? false;
      final matchGenre = item.genres.any((g) => g.toLowerCase().contains(q));
      final matchActors = item.actors.toLowerCase().contains(q);
      final matchDirector = item.director.toLowerCase().contains(q);
      final matchDesc = item.description.toLowerCase().contains(q);
      final matchYear = item.year.toString().contains(q);
      final matchKpId = item.kinopoiskId != null && item.kinopoiskId.toString().contains(q);
      return matchTitle ||
          matchOriginal ||
          matchGenre ||
          matchActors ||
          matchDirector ||
          matchDesc ||
          matchYear ||
          matchKpId;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
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
            color: const Color(0xFF1E1E34),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 16, color: Color(0xFF9F67FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Результаты поиска: «$_searchQuery»',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${results.length} найдено',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Ничего не найдено по запросу «$_searchQuery»',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
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
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Colors.white10),
                itemBuilder: (context, i) {
                  final movie = results[i];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      hoverColor: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                      onTap: () => _onMovieSelected(movie),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
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
                                  child: const Icon(Icons.movie_rounded,
                                      size: 20, color: Colors.white),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${movie.year} • ${movie.displayTypeLabel} • ${movie.genres.take(2).join(', ')}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
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
              onTap: () {
                _blurTimer?.cancel();
                _hideSearchOverlay();
                _searchFocus.unfocus();
                context.go('/library?q=${Uri.encodeComponent(_searchQuery)}');
              },
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

  void _onSubmitted(String q) {
    _blurTimer?.cancel();
    _hideSearchOverlay();
    _searchFocus.unfocus();
    if (q.trim().isEmpty) return;
    final query = q.trim().toLowerCase();
    final match = CuratedCatalog.items.where((item) =>
        item.title.toLowerCase().contains(query) ||
        (item.nameOriginal?.toLowerCase().contains(query) ?? false) ||
        item.actors.toLowerCase().contains(query) ||
        item.director.toLowerCase().contains(query)).firstOrNull;
    if (match != null) {
      _onMovieSelected(match);
    } else {
      context.go('/library?q=${Uri.encodeComponent(q.trim())}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final customProfile = ref.watch(profileCustomizationProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    final userProf = userProfileAsync.value;
    final rooms = ref.watch(roomsProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    final googleAvatar = user?.userMetadata?['avatar_url'] as String? ??
        user?.userMetadata?['picture'] as String?;
    final googleName = user?.userMetadata?['full_name'] as String? ??
        user?.userMetadata?['name'] as String?;

    final displayName = customProfile?.displayName.isNotEmpty == true
        ? customProfile!.displayName
        : (userProf?.displayName.isNotEmpty == true
            ? userProf!.displayName
            : (googleName ??
                (user?.email?.contains('@') == true
                    ? user!.email!.split('@').first
                    : (user?.email ?? 'Пользователь'))));

    final avatarUrl = customProfile?.avatarUrl?.isNotEmpty == true
        ? customProfile!.avatarUrl
        : (userProf?.avatarUrl?.isNotEmpty == true
            ? userProf!.avatarUrl
            : googleAvatar);

    final roleIcon = userProf?.roleIcon ?? (isAdmin ? '⭐' : '🍿');
    final liveRoomsCount = rooms.where((r) => r.status != 'finished').length;

    final currentRoute = widget.activeRoute ?? '';

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A).withValues(alpha: 0.98),
        border: const Border(bottom: BorderSide(color: Colors.white12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo & Brand
          InkWell(
            onTap: () => context.go('/home'),
            borderRadius: BorderRadius.circular(10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFE040FB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.movie_filter_rounded,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                const Text(
                  'CineTrack',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),

          // Main Navigation Links
          Row(
            children: [
              _buildNavLink(
                label: 'Главная',
                isSelected: currentRoute == '/home' || currentRoute == '/',
                onTap: () => context.go('/home'),
              ),
              const SizedBox(width: 18),
              _buildNavLink(
                label: 'Фильмы',
                isSelected: currentRoute == '/library',
                onTap: () => context.go('/library'),
              ),
              const SizedBox(width: 18),
              _buildNavLink(
                label: 'Комнаты 🍿',
                badgeCount: liveRoomsCount > 0 ? liveRoomsCount : null,
                isSelected: currentRoute.startsWith('/rooms'),
                onTap: () => context.go('/rooms'),
              ),
              const SizedBox(width: 18),
              _buildNavLink(
                label: 'Моя коллекция',
                isSelected: currentRoute.startsWith('/profile'),
                onTap: () => context.go('/profile'),
              ),
            ],
          ),
          const Spacer(),

          // Random Movie Button 🎲
          Tooltip(
            message: 'Случайный фильм 🎲',
            child: IconButton(
              icon: const Text('🎲', style: TextStyle(fontSize: 18)),
              onPressed: _openRandomMovie,
            ),
          ),
          const SizedBox(width: 6),

          // Search Field with Live Dropdown Anchor (Enlarged)
          CompositedTransformTarget(
            link: _layerLink,
            child: SizedBox(
              width: 340,
              height: 42,
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                onSubmitted: _onSubmitted,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1B1B2F),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  hintText: 'Поиск фильмов, сериалов, аниме...',
                  hintStyle:
                      const TextStyle(fontSize: 12, color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: Colors.white54),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              size: 16, color: Colors.white54),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Light / Dark Theme Toggle Button
          Tooltip(
            message: currentThemeMode == ThemeMode.dark
                ? 'Включить светлую тему ☀️'
                : 'Включить тёмную тему 🌙',
            child: IconButton(
              icon: Icon(
                currentThemeMode == ThemeMode.dark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                color: currentThemeMode == ThemeMode.dark
                    ? const Color(0xFFFFCA28)
                    : const Color(0xFF9F67FF),
                size: 20,
              ),
              onPressed: () {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
          ),
          const SizedBox(width: 8),

          // User Profile Pill (Avatar + Display Name)
          InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B2F),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isAdmin
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                      : Colors.white12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: isAdmin
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF7C3AED),
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  if (isAdmin || userProf?.isModerator == true) ...[
                    const SizedBox(width: 4),
                    Text(roleIcon, style: const TextStyle(fontSize: 12)),
                  ],
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavLink({
    required String label,
    required bool isSelected,
    int? badgeCount,
    bool isSpecialAdmin = false,
    required VoidCallback onTap,
  }) {
    Color textColor = isSelected ? Colors.white : Colors.white60;
    if (isSpecialAdmin) {
      textColor = isSelected ? const Color(0xFFF59E0B) : const Color(0xFFFBBF24);
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
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
