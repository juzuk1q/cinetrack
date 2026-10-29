import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers/stats_provider.dart';
import '../../repositories/stats_repository.dart';
import '../../widgets/app_sidebar.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsDataProvider);

    return Scaffold(
      body: Row(
        children: [
          const AppSidebar(selectedIndex: 5),
          Expanded(
            child: statsAsync.when(
              data: (stats) => _buildContent(context, ref, stats),
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Ошибка загрузки статистики: $e'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(statsDataProvider),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, StatsData stats) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          automaticallyImplyLeading: false,
          floating: true,
          title: Row(
            children: [
              const Icon(Icons.bar_chart_rounded,
                  color: Color(0xFF7C3AED), size: 26),
              const SizedBox(width: 10),
              Text('Статистика',
                  style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Обновить',
              onPressed: () => ref.invalidate(statsDataProvider),
            ),
            const SizedBox(width: 8),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // KPI cards
              _buildKpiCards(context, stats),
              const SizedBox(height: 32),

              // Charts row
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 800) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildStatusPieChart(context, stats),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildMonthlyLineChart(context, stats),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _buildStatusPieChart(context, stats),
                      const SizedBox(height: 24),
                      _buildMonthlyLineChart(context, stats),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Genre bar chart
              _buildGenreBarChart(context, stats),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCards(BuildContext context, StatsData stats) {
    final cards = [
      _KpiData(
        'Всего записей',
        stats.totalCount.toString(),
        Icons.movie_filter_rounded,
        const Color(0xFF7C3AED),
      ),
      _KpiData(
        'Просмотрено',
        (stats.byStatus['watched'] ?? 0).toString(),
        Icons.check_circle_rounded,
        const Color(0xFF4CAF50),
      ),
      _KpiData(
        'Смотрю сейчас',
        (stats.byStatus['watching'] ?? 0).toString(),
        Icons.play_circle_filled_rounded,
        const Color(0xFFFFB74D),
      ),
      _KpiData(
        'Ср. оценка',
        stats.averageRating > 0
            ? stats.averageRating.toStringAsFixed(1)
            : '—',
        Icons.star_rounded,
        const Color(0xFFFFCA28),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        childAspectRatio: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: cards.length,
      itemBuilder: (context, i) => _KpiCard(data: cards[i]),
    );
  }

  Widget _buildStatusPieChart(BuildContext context, StatsData stats) {
    final statusColors = {
      'watched': const Color(0xFF4CAF50),
      'watching': const Color(0xFFFFB74D),
      'want_to_watch': const Color(0xFF7C3AED),
    };

    final sections = stats.byStatus.entries.where((e) => e.value > 0).map(
      (e) {
        final total = stats.totalCount;
        final pct = total > 0 ? e.value / total * 100 : 0.0;
        return PieChartSectionData(
          value: e.value.toDouble(),
          title: '${pct.toStringAsFixed(0)}%',
          color: statusColors[e.key] ?? Colors.grey,
          radius: 80,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        );
      },
    ).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('По статусу',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            if (sections.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Нет данных', style: TextStyle(color: Colors.white38)),
                ),
              )
            else ...[
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 3,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...stats.byStatus.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: statusColors[e.key],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppConstants.statuses[e.key] ?? e.key,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      Text(
                        '${e.value}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyLineChart(BuildContext context, StatsData stats) {
    final entries = stats.byMonth.entries.toList();

    final spots = entries.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.value.toDouble());
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Просмотрено по месяцам',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: spots.isEmpty
                  ? const Center(
                      child: Text('Нет данных',
                          style: TextStyle(color: Colors.white38)))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (v) => const FlLine(
                            color: Colors.white10,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, m) => Text(
                                '${v.toInt()}',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                              reservedSize: 28,
                              interval: 1,
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, m) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= entries.length) {
                                  return const SizedBox.shrink();
                                }
                                final key = entries[idx].key;
                                final parts = key.split('-');
                                if (parts.length < 2) {
                                  return const SizedBox.shrink();
                                }
                                final month = int.tryParse(parts[1]) ?? 0;
                                final months = [
                                  '', 'Янв', 'Фев', 'Мар', 'Апр',
                                  'Май', 'Июн', 'Июл', 'Авг',
                                  'Сен', 'Окт', 'Ноя', 'Дек'
                                ];
                                return Text(
                                  months[month],
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 11),
                                );
                              },
                              reservedSize: 24,
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: const Color(0xFF7C3AED),
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreBarChart(BuildContext context, StatsData stats) {
    if (stats.byGenre.isEmpty) return const SizedBox.shrink();

    final sorted = stats.byGenre.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(10).toList();
    final maxVal = top.isNotEmpty ? top.first.value.toDouble() : 1.0;

    final barGroups = top.asMap().entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.value.toDouble(),
            color: const Color(0xFFE040FB),
            width: 18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('По жанрам (топ 10)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxVal + 1,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (v) => const FlLine(
                      color: Colors.white10,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) => Text(
                          '${v.toInt()}',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                        reservedSize: 24,
                        interval: 1,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, m) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= top.length) {
                            return const SizedBox.shrink();
                          }
                          final name = top[idx].key;
                          return Transform.rotate(
                            angle: -0.5,
                            child: Text(
                              name.length > 8
                                  ? '${name.substring(0, 7)}…'
                                  : name,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiData(this.label, this.value, this.icon, this.color);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(data.icon, color: data.color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: data.color,
                    ),
                  ),
                  Text(
                    data.label,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
