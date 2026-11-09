import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

class AppSidebar extends ConsumerWidget {
  final int selectedIndex;
  const AppSidebar({super.key, required this.selectedIndex});

  static const _destinations = [
    _NavItem(
      label: 'Главная',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      route: '/home',
    ),
    _NavItem(
      label: 'Библиотека',
      icon: Icons.local_movies_outlined,
      selectedIcon: Icons.local_movies_rounded,
      route: '/library',
    ),
    _NavItem(
      label: 'Комнаты',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      route: '/rooms',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isScreenWide = MediaQuery.of(context).size.width > 768;
    final isCollapsed = ref.watch(sidebarCollapsedProvider);

    if (!isScreenWide) {
      return _buildRail(context, ref);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: isCollapsed ? 76 : 248,
      decoration: const BoxDecoration(
        color: Color(0xFF141424),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // Logo & Toggle Button Row
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isCollapsed ? 12 : 16,
              vertical: 16,
            ),
            child: isCollapsed
                ? Center(
                    child: _SidebarLogoButton(
                      isCollapsed: true,
                      onTap: () => ref
                          .read(sidebarCollapsedProvider.notifier)
                          .state = false,
                    ),
                  )
                : Row(
                    children: [
                      _SidebarLogoButton(
                        isCollapsed: false,
                        onTap: () {},
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'CineTrack',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.menu_open_rounded,
                            size: 20, color: Colors.white70),
                        tooltip: 'Свернуть меню',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => ref
                            .read(sidebarCollapsedProvider.notifier)
                            .state = true,
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 10),

          // Nav items
          ...List.generate(_destinations.length, (i) {
            final item = _destinations[i];
            final selected = i == selectedIndex;
            return _SidebarNavItem(
              item: item,
              selected: selected,
              isCollapsed: isCollapsed,
              onTap: () => context.go(item.route),
            );
          }),

          // Admin panel nav item (available to Admins)
          if (ref.watch(isAdminProvider)) ...[
            const SizedBox(height: 6),
            _SidebarNavItem(
              item: const _NavItem(
                label: 'Админ-панель',
                icon: Icons.admin_panel_settings_outlined,
                selectedIcon: Icons.admin_panel_settings_rounded,
                route: '/admin',
              ),
              selected: selectedIndex == -2,
              isCollapsed: isCollapsed,
              onTap: () => context.go('/admin'),
            ),
          ],

          const Spacer(),
          const Divider(height: 1, color: Colors.white12),

          // User Profile Tile at Bottom
          _buildUserProfileTile(context, ref, isCollapsed),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildUserProfileTile(
      BuildContext context, WidgetRef ref, bool isCollapsed) {
    final customProfile = ref.watch(profileCustomizationProvider);
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(isAdminProvider);
    final displayName = customProfile?.displayName ??
        user?.userMetadata?['display_name'] as String? ??
        (user?.email?.contains('@') == true
            ? user!.email!.split('@').first
            : (user?.email ?? 'Пользователь'));
    final isSelected = selectedIndex == -1;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Tooltip(
          message: isAdmin ? '$displayName 👑' : displayName,
          child: InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: isSelected
                      ? const Color(0xFF9F67FF)
                      : const Color(0xFF7C3AED),
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (isAdmin)
                  const Positioned(
                    right: -4,
                    bottom: -4,
                    child: Text('👑', style: TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Material(
        color: isSelected
            ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
            : const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/profile'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: isAdmin
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF7C3AED),
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                          if (isAdmin)
                            const Text(' 👑', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        'Мой профиль',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Colors.white24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRail(BuildContext context, WidgetRef ref) {
    final effectiveIndex =
        (selectedIndex >= 0 && selectedIndex < _destinations.length)
            ? selectedIndex
            : 0;

    return NavigationRail(
      selectedIndex: effectiveIndex,
      onDestinationSelected: (i) => context.go(_destinations[i].route),
      labelType: NavigationRailLabelType.selected,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFE040FB)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.movie_filter_rounded,
              size: 20, color: Colors.white),
        ),
      ),
      trailing: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: IconButton(
          icon: const Icon(Icons.person_rounded),
          tooltip: 'Профиль и настройки',
          color: selectedIndex == -1
              ? const Color(0xFF7C3AED)
              : Colors.white60,
          onPressed: () => context.go('/profile'),
        ),
      ),
      destinations: _destinations
          .map((d) => NavigationRailDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: Text(d.label),
              ))
          .toList(),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });
}

class _SidebarNavItem extends StatefulWidget {
  final _NavItem item;
  final bool selected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.selected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Tooltip(
          message: widget.item.label,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              transform: Matrix4.diagonal3Values(
                  _isHovered ? 1.08 : 1.0, _isHovered ? 1.08 : 1.0, 1.0),
              decoration: BoxDecoration(
                color: widget.selected
                    ? const Color(0xFF7C3AED)
                    : (_isHovered
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                        : Colors.transparent),
                borderRadius: BorderRadius.circular(10),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Icon(
                      widget.selected
                          ? widget.item.selectedIcon
                          : widget.item.icon,
                      size: 22,
                      color: widget.selected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(_isHovered ? 4 : 0, 0, 0),
          decoration: BoxDecoration(
            color: widget.selected
                ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
                : (_isHovered
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.selected
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                  : (_isHovered ? Colors.white12 : Colors.transparent),
              width: 0.8,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    widget.selected
                        ? widget.item.selectedIcon
                        : widget.item.icon,
                    size: 20,
                    color: widget.selected
                        ? const Color(0xFF9F67FF)
                        : (_isHovered ? Colors.white : Colors.white70),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.item.label,
                    style: TextStyle(
                      color: widget.selected
                          ? Colors.white
                          : (_isHovered ? Colors.white : Colors.white70),
                      fontWeight:
                          widget.selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
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
}

class _SidebarLogoButton extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onTap;

  const _SidebarLogoButton({
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_SidebarLogoButton> createState() => _SidebarLogoButtonState();
}

class _SidebarLogoButtonState extends State<_SidebarLogoButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isCollapsed) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C3AED), Color(0xFFE040FB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.movie_filter_rounded, size: 20, color: Colors.white),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Tooltip(
        message: 'Развернуть боковое меню',
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isHovered
                    ? [const Color(0xFF9F67FF), const Color(0xFFF472B6)]
                    : [const Color(0xFF7C3AED), const Color(0xFFE040FB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.6),
                        blurRadius: 10,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: _isHovered
                  ? const Icon(
                      Icons.chevron_right_rounded,
                      key: ValueKey('chevron'),
                      size: 24,
                      color: Colors.white,
                    )
                  : const Icon(
                      Icons.movie_filter_rounded,
                      key: ValueKey('logo'),
                      size: 20,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
