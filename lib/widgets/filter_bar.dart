import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../providers/media_provider.dart';

class FilterBar extends ConsumerWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(filtersProvider);
    final notifier = ref.read(filtersProvider.notifier);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          // Reset all
          if (filters.hasActiveFilters) ...[
            ActionChip(
              label: const Text('Сбросить всё'),
              avatar: const Icon(Icons.clear_all_rounded, size: 16),
              onPressed: () => notifier.reset(),
              backgroundColor: Colors.red.withValues(alpha: 0.15),
              side: const BorderSide(color: Colors.red, width: 0.8),
              labelStyle: const TextStyle(color: Colors.red),
            ),
            const SizedBox(width: 8),
          ],

          // Status filter
          _buildDropdown<String>(
            context,
            label: 'Статус',
            value: filters.status,
            items: AppConstants.statuses,
            onChanged: (v) => notifier.setStatus(v),
            icon: Icons.bookmark_outline_rounded,
          ),
          const SizedBox(width: 8),

          // Type filter
          _buildDropdown<String>(
            context,
            label: 'Тип',
            value: filters.type,
            items: AppConstants.mediaTypes,
            onChanged: (v) => notifier.setType(v),
            icon: Icons.movie_filter_outlined,
          ),
          const SizedBox(width: 8),

          // Genre filter
          _buildGenreDropdown(context, filters, notifier),
          const SizedBox(width: 8),

          // Year filter chips (recent years)
          ..._buildYearChips(context, filters, notifier),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
    BuildContext context, {
    required String label,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    final isActive = value != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String?>(
      onSelected: onChanged,
      tooltip: label,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem<String?>(
          value: null,
          child: Row(
            children: [
              Icon(Icons.clear_rounded, size: 16),
              SizedBox(width: 8),
              Text('Все'),
            ],
          ),
        ),
        ...items.entries.map(
          (e) => PopupMenuItem<String?>(
            value: e.key,
            child: Text(e.value),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF7C3AED).withValues(alpha: 0.18)
              : (isDark ? const Color(0xFF252540) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF7C3AED)
                : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
            width: isActive ? 1.5 : 0.8,
          ),
          boxShadow: !isDark && !isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isActive
                    ? const Color(0xFF7C3AED)
                    : (isDark ? Colors.white54 : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              isActive ? (items[value] ?? label) : label,
              style: TextStyle(
                fontSize: 13,
                color: isActive
                    ? const Color(0xFF7C3AED)
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18,
                color: isActive
                    ? const Color(0xFF7C3AED)
                    : (isDark ? Colors.white38 : const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreDropdown(
    BuildContext context,
    filters,
    FiltersNotifier notifier,
  ) {
    final isActive = filters.genre != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PopupMenuButton<String?>(
      onSelected: (v) => notifier.setGenre(v),
      tooltip: 'Жанр',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem<String?>(
          value: null,
          child: Row(
            children: [
              Icon(Icons.clear_rounded, size: 16),
              SizedBox(width: 8),
              Text('Все жанры'),
            ],
          ),
        ),
        ...AppConstants.genres.map(
          (g) => PopupMenuItem<String?>(value: g, child: Text(g)),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF7C3AED).withValues(alpha: 0.18)
              : (isDark ? const Color(0xFF252540) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF7C3AED)
                : (isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
            width: isActive ? 1.5 : 0.8,
          ),
          boxShadow: !isDark && !isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.theater_comedy_outlined,
                size: 16,
                color: isActive
                    ? const Color(0xFF7C3AED)
                    : (isDark ? Colors.white54 : const Color(0xFF64748B))),
            const SizedBox(width: 6),
            Text(
              isActive ? filters.genre! : 'Жанр',
              style: TextStyle(
                fontSize: 13,
                color: isActive
                    ? const Color(0xFF7C3AED)
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18,
                color: isActive
                    ? const Color(0xFF7C3AED)
                    : (isDark ? Colors.white38 : const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildYearChips(
    BuildContext context,
    filters,
    FiltersNotifier notifier,
  ) {
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => currentYear - i);

    return years.map((year) {
      final selected = filters.year == year;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: FilterChip(
          label: Text('$year'),
          selected: selected,
          onSelected: (v) => notifier.setYear(v ? year : null),
        ),
      );
    }).toList();
  }
}
