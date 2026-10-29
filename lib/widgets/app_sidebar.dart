import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

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
    final isWide = MediaQuery.of(context).size.width > 900;

    if (isWide) {
      return _buildWideSidebar(context, ref);
    } else {
      return _buildRail(context, ref);
    }
  }

  Widget _buildWideSidebar(BuildContext context, WidgetRef ref) {
    return Container(
      width: 230,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        border: Border(right: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFFE040FB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.movie_filter_rounded,
                      size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text(
                  'CineTrack',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Nav items
          ...List.generate(_destinations.length, (i) {
            final item = _destinations[i];
            final selected = i == selectedIndex;
            return _SidebarNavItem(
              item: item,
              selected: selected,
              onTap: () => context.go(item.route),
            );
          }),

          const Spacer(),
          const Divider(height: 1),

          // Profile & Stats Card at Bottom of Sidebar
          _buildUserProfileTile(context, ref),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildUserProfileTile(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final email = user?.email ?? 'Гость';
    final name = email.split('@').first;
    final isSelected = selectedIndex == -1;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: isSelected
            ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
            : const Color(0xFF252540),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.go('/profile'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF7C3AED),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
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
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Профиль & Статистика',
                        style: TextStyle(color: Colors.white54, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  color: Colors.white38,
                  tooltip: 'Выйти',
                  onPressed: () =>
                      ref.read(authNotifierProvider.notifier).signOut(),
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
        child: Column(
          children: [
            IconButton(
              icon: const Icon(Icons.person_rounded),
              tooltip: 'Профиль и статистика',
              color: selectedIndex == -1
                  ? const Color(0xFF7C3AED)
                  : Colors.white60,
              onPressed: () => context.go('/profile'),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              color: Colors.white38,
              tooltip: 'Выйти',
              onPressed: () =>
                  ref.read(authNotifierProvider.notifier).signOut(),
            ),
          ],
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

class _SidebarNavItem extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: selected
                      ? const Color(0xFF9F67FF)
                      : Colors.white38,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? const Color(0xFF9F67FF) : Colors.white54,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
