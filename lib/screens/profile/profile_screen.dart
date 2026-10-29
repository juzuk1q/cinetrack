import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../providers/stats_provider.dart';
import '../../repositories/stats_repository.dart';
import '../../widgets/app_sidebar.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(statsDataProvider);

    final email = user?.email ?? 'Пользователь';
    final displayName = email.split('@').first;

    return Scaffold(
      body: Row(
        children: [
          const AppSidebar(selectedIndex: -1), // Profile is opened from bottom
          Expanded(
            child: CustomScrollView(
              slivers: [
                // AppBar
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  pinned: true,
                  title: const Text('Мой профиль и статистика'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      tooltip: 'Выйти из аккаунта',
                      onPressed: () async {
                        await ref.read(authNotifierProvider.notifier).signOut();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                // User Profile Header Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A1B4E), Color(0xFF1A1A2E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: const Color(0xFF7C3AED),
                            child: Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981)
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: const Color(0xFF10B981),
                                            width: 0.8),
                                      ),
                                      child: const Text(
                                        'Киноман',
                                        style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Облачная база данных Supabase подключена и синхронизирована.',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Stats Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: statsAsync.when(
                      data: (stats) => _buildStatsBody(context, stats),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Ошибка: $e')),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBody(BuildContext context, StatsData stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ПЕРСОНАЛЬНАЯ СТАТИСТИКА ПРОСМОТРОВ',
          style: TextStyle(
            color: Color(0xFF9F67FF),
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 14),

        // KPI Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final crossCount = constraints.maxWidth > 700 ? 4 : 2;
            return GridView.count(
              crossAxisCount: crossCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.8,
              children: [
                _buildKpiCard(
                  title: 'Всего в коллекции',
                  value: '${stats.totalCount}',
                  icon: Icons.movie_filter_rounded,
                  color: const Color(0xFF7C3AED),
                ),
                _buildKpiCard(
                  title: 'Просмотрено',
                  value: '${stats.byStatus['watched'] ?? 0}',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                ),
                _buildKpiCard(
                  title: 'В процессе',
                  value: '${stats.byStatus['watching'] ?? 0}',
                  icon: Icons.play_circle_fill_rounded,
                  color: const Color(0xFFF59E0B),
                ),
                _buildKpiCard(
                  title: 'Средняя оценка',
                  value: stats.averageRating > 0
                      ? '${stats.averageRating.toStringAsFixed(1)} ★'
                      : '—',
                  icon: Icons.star_rounded,
                  color: const Color(0xFFFFCA28),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Status Chart and Favorite Genre
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPieCard(stats)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildGenreCard(stats)),
                ],
              );
            }
            return Column(
              children: [
                _buildPieCard(stats),
                const SizedBox(height: 16),
                _buildGenreCard(stats),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieCard(StatsData stats) {
    final watched = stats.byStatus['watched'] ?? 0;
    final watching = stats.byStatus['watching'] ?? 0;
    final want = stats.byStatus['want_to_watch'] ?? 0;
    final total = stats.totalCount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Распределение по статусам',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 16),
          if (total == 0)
            const SizedBox(
              height: 140,
              child: Center(
                child: Text('Добавьте фильмы, чтобы увидеть график',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            )
          else ...[
            SizedBox(
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 35,
                  sections: [
                    if (watched > 0)
                      PieChartSectionData(
                        value: watched.toDouble(),
                        color: const Color(0xFF10B981),
                        radius: 35,
                        showTitle: false,
                      ),
                    if (watching > 0)
                      PieChartSectionData(
                        value: watching.toDouble(),
                        color: const Color(0xFFF59E0B),
                        radius: 35,
                        showTitle: false,
                      ),
                    if (want > 0)
                      PieChartSectionData(
                        value: want.toDouble(),
                        color: const Color(0xFF7C3AED),
                        radius: 35,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildLegend(
                'Просмотрено ($watched)', const Color(0xFF10B981)),
            _buildLegend(
                'Смотрю ($watching)', const Color(0xFFF59E0B)),
            _buildLegend('Хочу посмотреть ($want)',
                const Color(0xFF7C3AED)),
          ],
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGenreCard(StatsData stats) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E34),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Любимый жанр & Предпочтения',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE040FB).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Color(0xFFE040FB), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stats.favoriteGenre ?? 'Ещё не определён',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Чаще всего встречается в вашей коллекции',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 12),
          const Text(
            'Чем больше фильмов вы отмечаете, тем точнее подбираются рекомендации для совместного просмотра с друзьями!',
            style: TextStyle(fontSize: 12, color: Colors.white60, height: 1.3),
          ),
        ],
      ),
    );
  }
}
