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
    return PopupMenuButton<String?>(
      onSelected: onChanged,
      tooltip: label,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF1A1A2E),
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
              ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
              : const Color(0xFF252540),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFF7C3AED)
                : Colors.white24,
            width: isActive ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isActive ? const Color(0xFF9F67FF) : Colors.white54),
            const SizedBox(width: 6),
            Text(
              isActive ? (items[value] ?? label) : label,
              style: TextStyle(
                fontSize: 13,
                color: isActive ? const Color(0xFF9F67FF) : Colors.white70,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18,
                color: isActive ? const Color(0xFF9F67FF) : Colors.white38),
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
    return PopupMenuButton<String?>(
      onSelected: (v) => notifier.setGenre(v),
      tooltip: 'Жанр',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color(0xFF1A1A2E),
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
              ? const Color(0xFF7C3AED).withValues(alpha: 0.2)
              : const Color(0xFF252540),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? const Color(0xFF7C3AED) : Colors.white24,
            width: isActive ? 1.5 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.theater_comedy_outlined,
                size: 16,
                color: isActive ? const Color(0xFF9F67FF) : Colors.white54),
            const SizedBox(width: 6),
            Text(
              isActive ? filters.genre! : 'Жанр',
              style: TextStyle(
                fontSize: 13,
                color: isActive ? const Color(0xFF9F67FF) : Colors.white70,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18,
                color: isActive ? const Color(0xFF9F67FF) : Colors.white38),
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
