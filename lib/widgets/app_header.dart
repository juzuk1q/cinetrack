import 'header/header_search_dropdown.dart';
import 'header/header_mobile_menu.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/movie_randomizer.dart';
import '../data/curated_catalog.dart';
import '../models/catalog_item.dart';
import '../services/kinopoisk_service.dart';
import '../providers/auth_provider.dart';
import '../providers/kinopoisk_provider.dart';
import '../providers/room_provider.dart';
import '../providers/theme_provider.dart';

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
  Timer? _searchDebounce;
  List<CatalogItem> _remoteSearchResults = [];
  bool _isSearchingRemote = false;
  bool _isMobileMenuOpen = false;

  void _toggleMobileMenu({bool? open, bool focusSearch = false}) {
    setState(() {
      _isMobileMenuOpen = open ?? !_isMobileMenuOpen;
    });
    if (_isMobileMenuOpen && focusSearch) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) _searchFocus.requestFocus();
      });
    }
  }

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
    _searchDebounce?.cancel();
    _hideSearchOverlay();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val.trim();
    });
    _overlayEntry?.markNeedsBuild();
    if (_searchQuery.isNotEmpty) {
      _blurTimer?.cancel();
      _showSearchOverlay();

      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
        final currentQ = _searchQuery;
        if (currentQ.isEmpty) return;
        setState(() {
          _isSearchingRemote = true;
        });
        _overlayEntry?.markNeedsBuild();
        try {
          final results = await KinopoiskService().search(currentQ);
          if (mounted && _searchQuery == currentQ) {
            setState(() {
              _remoteSearchResults = results;
              _isSearchingRemote = false;
            });
            _overlayEntry?.markNeedsBuild();
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isSearchingRemote = false;
            });
            _overlayEntry?.markNeedsBuild();
          }
        }
      });
    } else {
      _remoteSearchResults = [];
      _isSearchingRemote = false;
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
          width: 480,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(-20, 48),
            child: Material(
              color: Colors.transparent,
              child: HeaderSearchDropdown(
                results: _getSearchResults(),
                searchQuery: _searchQuery,
                isSearchingRemote: _isSearchingRemote,
                onMovieSelected: _onMovieSelected,
                onSearchInLibrary: () {
                  _blurTimer?.cancel();
                  _hideSearchOverlay();
                  _searchFocus.unfocus();
                  context.go('/library?q=');
                },
              ),
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
    final catalogItems = ref.read(catalogProvider).items;
    MovieRandomizer.pickAndOpen(
      context,
      candidates: catalogItems,
      usePush: true,
    );
  }

  List<CatalogItem> _getSearchResults() {
    final q = _searchQuery.toLowerCase();
    final localMatches = CuratedCatalog.items.where((item) {
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

    final seen = <String>{};
    final results = <CatalogItem>[];
    for (final it in localMatches) {
      final key = it.kinopoiskId != null ? 'id_${it.kinopoiskId}' : 't_${it.title.toLowerCase()}';
      if (seen.add(key)) results.add(it);
    }
    for (final it in _remoteSearchResults) {
      final key = it.kinopoiskId != null ? 'id_${it.kinopoiskId}' : 't_${it.title.toLowerCase()}';
      if (seen.add(key)) results.add(it);
    }
    return results;
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
    } else if (_remoteSearchResults.isNotEmpty) {
      _onMovieSelected(_remoteSearchResults.first);
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentRoute = widget.activeRoute ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 960;
        final horizontalPadding = isMobile ? 12.0 : 28.0;

        Widget buildLogo() {
          return InkWell(
            onTap: () {
              setState(() => _isMobileMenuOpen = false);
              context.go('/home');
            },
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
                const SizedBox(width: 8),
                Text(
                  'CineTrack',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          );
        }

        Widget buildNavLinks() {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavLink(
                label: 'Главная',
                isSelected: currentRoute == '/home' || currentRoute == '/',
                onTap: () {
                  setState(() => _isMobileMenuOpen = false);
                  context.go('/home');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 18),
              _buildNavLink(
                label: 'Фильмы',
                isSelected: currentRoute == '/library',
                onTap: () {
                  setState(() => _isMobileMenuOpen = false);
                  context.go('/library');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 18),
              _buildNavLink(
                label: 'Комнаты 🍿',
                badgeCount: liveRoomsCount > 0 ? liveRoomsCount : null,
                isSelected: currentRoute.startsWith('/rooms'),
                onTap: () {
                  setState(() => _isMobileMenuOpen = false);
                  context.go('/rooms');
                },
                isDark: isDark,
              ),
              const SizedBox(width: 18),
              _buildNavLink(
                label: 'Моя коллекция',
                isSelected: currentRoute.startsWith('/profile'),
                onTap: () {
                  setState(() => _isMobileMenuOpen = false);
                  context.go('/profile');
                },
                isDark: isDark,
              ),
            ],
          );
        }

        Widget buildSearchField() {
          return CompositedTransformTarget(
            link: _layerLink,
            child: SizedBox(
              width: isMobile ? 220 : 400,
              height: 42,
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                onSubmitted: _onSubmitted,
                style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1B1B2F)
                      : const Color(0xFFF1F5F9),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  hintText: 'Поиск фильмов, сериалов, аниме...',
                  hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search_rounded,
                      size: 18,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              size: 16,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B)),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide:
                        const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                  ),
                ),
              ),
            ),
          );
        }

        Widget buildRandomBtn() {
          return Tooltip(
            message: 'Случайный фильм 🎲',
            child: IconButton(
              icon: const Text('🎲', style: TextStyle(fontSize: 18)),
              onPressed: _openRandomMovie,
            ),
          );
        }

        Widget buildThemeToggle() {
          return Tooltip(
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
          );
        }

        Widget buildProfilePill() {
          return InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1B1B2F)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isAdmin
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                      : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
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
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
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
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F0F1A).withValues(alpha: 0.98)
                : Colors.white.withValues(alpha: 0.98),
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isMobile
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mobile Top Bar (Clean, fixed 64px, zero horizontal scrolling)
                    SizedBox(
                      height: 64,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        child: Row(
                          children: [
                            buildLogo(),
                            const Spacer(),
                            // Search toggle button
                            IconButton(
                              icon: Icon(
                                Icons.search_rounded,
                                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                size: 21,
                              ),
                              tooltip: 'Поиск фильмов',
                              onPressed: () => _toggleMobileMenu(open: !_isMobileMenuOpen, focusSearch: true),
                            ),
                            // Theme toggle button
                            buildThemeToggle(),
                            // Mobile user avatar
                            InkWell(
                              onTap: () {
                                setState(() => _isMobileMenuOpen = false);
                                context.go('/profile');
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundColor: isAdmin ? const Color(0xFFF59E0B) : const Color(0xFF7C3AED),
                                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                                child: (avatarUrl == null || avatarUrl.isEmpty)
                                    ? Text(
                                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Hamburger Menu Button (GameVault style)
                            InkWell(
                              onTap: () => _toggleMobileMenu(),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E34) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _isMobileMenuOpen
                                        ? const Color(0xFF7C3AED)
                                        : (isDark ? Colors.white12 : const Color(0xFFCBD5E1)),
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  _isMobileMenuOpen ? Icons.close_rounded : Icons.menu_rounded,
                                  color: _isMobileMenuOpen
                                      ? const Color(0xFFC084FC)
                                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Dropdown Mobile Menu (GameVault style)
                    if (_isMobileMenuOpen)
                      HeaderMobileMenu(
                        searchCtrl: _searchCtrl,
                        searchFocus: _searchFocus,
                        searchQuery: _searchQuery,
                        results: _getSearchResults(),
                        isSearchingRemote: _isSearchingRemote,
                        onSearchChanged: _onSearchChanged,
                        onSearchSubmitted: _onSubmitted,
                        onMovieSelected: _onMovieSelected,
                        onSearchInLibrary: () {
                          _searchFocus.unfocus();
                          context.go('/library?q=');
                        },
                        currentRoute: currentRoute,
                        liveRoomsCount: liveRoomsCount,
                        displayName: displayName,
                        avatarUrl: avatarUrl,
                        isAdmin: isAdmin,
                        onOpenRandomMovie: _openRandomMovie,
                        onCloseMenu: () => setState(() => _isMobileMenuOpen = false),
                      ),
                  ],
                )
              : Container(
                  height: 68,
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
                  child: Row(
                    children: [
                      buildLogo(),
                      const SizedBox(width: 28),
                      buildNavLinks(),
                      const Spacer(),
                      buildRandomBtn(),
                      const SizedBox(width: 6),
                      buildSearchField(),
                      const SizedBox(width: 14),
                      buildThemeToggle(),
                      const SizedBox(width: 8),
                      buildProfilePill(),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildNavLink({
    required String label,
    required bool isSelected,
    int? badgeCount,
    bool isSpecialAdmin = false,
    required VoidCallback onTap,
    bool isDark = true,
  }) {
    Color textColor = isDark
        ? (isSelected ? Colors.white : Colors.white60)
        : (isSelected ? const Color(0xFF7C3AED) : const Color(0xFF475569));
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
