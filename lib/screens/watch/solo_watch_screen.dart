// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../data/curated_catalog.dart';
import '../../models/catalog_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/top_notification.dart';

class SoloWatchComment {
  final String id;
  final String authorName;
  final String? authorAvatar;
  final String? authorTitle;
  final String text;
  final String timeAgo;
  int likes;
  bool isLiked;

  SoloWatchComment({
    required this.id,
    required this.authorName,
    this.authorAvatar,
    this.authorTitle,
    required this.text,
    required this.timeAgo,
    this.likes = 0,
    this.isLiked = false,
  });
}

class FranchiseStep {
  final String title;
  final String typeLabel;
  final int year;
  final bool isCurrent;
  final int? kinopoiskId;
  final String? posterUrl;

  const FranchiseStep({
    required this.title,
    required this.typeLabel,
    required this.year,
    required this.isCurrent,
    this.kinopoiskId,
    this.posterUrl,
  });
}

class SoloWatchScreen extends ConsumerStatefulWidget {
  final String title;
  final int? year;
  final int? kinopoiskId;
  final String? posterUrl;
  final String type;
  final String? description;
  final String? genres;

  const SoloWatchScreen({
    super.key,
    required this.title,
    this.year,
    this.kinopoiskId,
    this.posterUrl,
    required this.type,
    this.description,
    this.genres,
  });

  @override
  ConsumerState<SoloWatchScreen> createState() => _SoloWatchScreenState();
}

class _SoloWatchScreenState extends ConsumerState<SoloWatchScreen> {
  String _activeTab = 'collaps'; // 'collaps', 'alloha', 'backup', 'trailer'
  late String _viewId;
  html.IFrameElement? _iframe;

  final TextEditingController _commentCtrl = TextEditingController();
  final List<SoloWatchComment> _comments = [];

  @override
  void initState() {
    super.initState();
    _viewId = 'cinetrack-solo-player-${DateTime.now().microsecondsSinceEpoch}';
    _initIframe();
    _initComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _initComments() {
    _comments.addAll([
      SoloWatchComment(
        id: 'c1',
        authorName: 'Артем Киноманов',
        authorTitle: 'Создатель 👑',
        authorAvatar:
            'https://avatars.mds.yandex.net/get-kinopoisk-image/1601250/20399d86-a579-4a00-b6e5-4a69ec40fe50/orig',
        text:
            'Шедевральная сцена на 00:43:15! Музыка Ханса Циммера до мурашек, просто разрыв шаблона 🎬',
        timeAgo: '2 часа назад',
        likes: 14,
      ),
      SoloWatchComment(
        id: 'c2',
        authorName: 'Дарья MovieLover',
        authorTitle: 'Кинокритик 💬',
        text:
            'На таймкоде 01:28:40 обратите внимание на детали на заднем плане! Пересматриваю уже в третий раз.',
        timeAgo: '4 часа назад',
        likes: 9,
      ),
      SoloWatchComment(
        id: 'c3',
        authorName: 'Макс_Stream',
        authorTitle: 'Новичок стримов 🍿',
        text:
            'Звук и качество 4K в этом плеере просто топовые. Особенно кульминация с 02:14:00!',
        timeAgo: 'вчера',
        likes: 5,
      ),
    ]);
  }

  String _getCurrentUrl() {
    final kpId = widget.kinopoiskId ?? 258687;

    if (_activeTab == 'collaps') {
      return 'https://kinobox.tv/embed/kinopoisk/$kpId';
    } else if (_activeTab == 'alloha') {
      return 'https://alloha.club/embed/kp/$kpId';
    } else if (_activeTab == 'backup') {
      return 'https://kodik.info/find-player?kinopoiskID=$kpId';
    } else {
      return 'https://api.atomics.ws/embed/trailer-kp/$kpId';
    }
  }

  void _initIframe() {
    final url = _getCurrentUrl();
    _iframe = html.IFrameElement()
      ..src = url
      ..referrerPolicy = 'no-referrer'
      ..setAttribute('referrerpolicy', 'no-referrer')
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#0A0A14'
      ..allow = 'autoplay; fullscreen; encrypted-media; picture-in-picture';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _iframe!,
    );
  }

  void _switchTab(String mode) {
    if (_activeTab == mode) return;
    setState(() {
      _activeTab = mode;
    });
    _iframe?.src = _getCurrentUrl();
  }

  void _createRoomAndInvite() {
    final user = ref.read(currentUserProvider);
    final ownerName = user?.email?.split('@').first ?? 'Организатор';
    final clientToken = RoomRepository.getClientToken();
    final ownerId = user?.id ?? clientToken;

    final room = ref.read(roomsProvider.notifier).createRoom(
      title: 'Смотрим: ${widget.title} 🍿',
      movieTitle: widget.title,
      movieType: widget.type,
      moviePoster: widget.posterUrl,
      movieYear: widget.year,
      kinopoiskId: widget.kinopoiskId,
      scheduledAt: DateTime.now(),
      ownerName: ownerName,
      ownerId: ownerId,
      videoSourceType: 'catalog',
      videoUrl: _getCurrentUrl(),
    );

    context.go('/rooms/${room.id}');
  }

  void _addComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    final profile = ref.read(userProfileProvider).value;
    final authorName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (user?.email?.split('@').first ?? 'Киноман');
    final authorTitle = profile?.effectiveTitle ?? 'Зритель 🍿';
    final authorAvatar = profile?.avatarUrl;

    setState(() {
      _comments.insert(
        0,
        SoloWatchComment(
          id: 'c_${DateTime.now().millisecondsSinceEpoch}',
          authorName: authorName,
          authorAvatar: authorAvatar,
          authorTitle: authorTitle,
          text: text,
          timeAgo: 'Только что',
          likes: 0,
        ),
      );
      _commentCtrl.clear();
    });

    TopNotification.showSuccess(
      context,
      'Комментарий опубликован! ✨',
      title: 'Обсуждение',
    );
  }

  void _insertTimestampHelper(String timestamp) {
    final cur = _commentCtrl.text;
    final selection = _commentCtrl.selection;
    if (selection.isValid && selection.start >= 0) {
      final newText = cur.replaceRange(
          selection.start, selection.end, ' $timestamp ');
      _commentCtrl.text = newText;
      _commentCtrl.selection = TextSelection.collapsed(
          offset: selection.start + timestamp.length + 2);
    } else {
      _commentCtrl.text = cur.isEmpty ? timestamp : '$cur $timestamp';
    }
  }

  List<FranchiseStep> _getFranchiseTimeline() {
    final curTitle = widget.title.toLowerCase();

    if (curTitle.contains('гуль') || curTitle.contains('ghoul')) {
      return [
        const FranchiseStep(
          title: 'Токийский гуль (Сезон 1)',
          typeLabel: 'Сериал',
          year: 2014,
          isCurrent: true,
          kinopoiskId: 841681,
        ),
        const FranchiseStep(
          title: 'Токийский гуль √A (Сезон 2)',
          typeLabel: 'Сериал',
          year: 2015,
          isCurrent: false,
          kinopoiskId: 841681,
        ),
        const FranchiseStep(
          title: 'Токийский гуль: Джек (OVA)',
          typeLabel: 'Спецвыпуск',
          year: 2015,
          isCurrent: false,
          kinopoiskId: 841681,
        ),
        const FranchiseStep(
          title: 'Токийский гуль: Фильм',
          typeLabel: 'Полный метр',
          year: 2017,
          isCurrent: false,
          kinopoiskId: 841681,
        ),
        const FranchiseStep(
          title: 'Токийский гуль:re (Сезон 3)',
          typeLabel: 'Сериал',
          year: 2018,
          isCurrent: false,
          kinopoiskId: 841681,
        ),
      ];
    } else if (curTitle.contains('тяжк') || curTitle.contains('breaking bad')) {
      return [
        const FranchiseStep(
          title: 'Лучше звоните Солу (Приквел)',
          typeLabel: 'Сериал',
          year: 2015,
          isCurrent: false,
          kinopoiskId: 841681,
        ),
        const FranchiseStep(
          title: 'Во все тяжкие (Breaking Bad)',
          typeLabel: 'Сериал',
          year: 2008,
          isCurrent: true,
          kinopoiskId: 404900,
        ),
        const FranchiseStep(
          title: 'El Camino: Во все тяжкие',
          typeLabel: 'Полнометражный фильм',
          year: 2019,
          isCurrent: false,
          kinopoiskId: 404900,
        ),
      ];
    } else if (curTitle.contains('титан') || curTitle.contains('titan')) {
      return [
        const FranchiseStep(
          title: 'Атака титанов (Сезон 1)',
          typeLabel: 'Сериал',
          year: 2013,
          isCurrent: true,
          kinopoiskId: 749374,
        ),
        const FranchiseStep(
          title: 'Атака титанов: Выбор без сожалений',
          typeLabel: 'OVA / Приквел',
          year: 2014,
          isCurrent: false,
          kinopoiskId: 749374,
        ),
        const FranchiseStep(
          title: 'Атака титанов (Сезон 2-3)',
          typeLabel: 'Сериал',
          year: 2017,
          isCurrent: false,
          kinopoiskId: 749374,
        ),
        const FranchiseStep(
          title: 'Атака титанов: Финал',
          typeLabel: 'Сериал / Кульминация',
          year: 2023,
          isCurrent: false,
          kinopoiskId: 749374,
        ),
      ];
    } else if (curTitle.contains('демон') || curTitle.contains('kimetsu') || curTitle.contains('клинок')) {
      return [
        const FranchiseStep(
          title: 'Клинок, рассекающий демонов (Сезон 1)',
          typeLabel: 'Сериал',
          year: 2019,
          isCurrent: true,
          kinopoiskId: 1220920,
        ),
        const FranchiseStep(
          title: 'Поезд «Бесконечный» (Фильм)',
          typeLabel: 'Полный метр',
          year: 2020,
          isCurrent: false,
          kinopoiskId: 1347949,
        ),
        const FranchiseStep(
          title: 'Квартал красных фонарей (Сезон 2)',
          typeLabel: 'Сериал',
          year: 2021,
          isCurrent: false,
          kinopoiskId: 1220920,
        ),
        const FranchiseStep(
          title: 'Деревня кузнецов (Сезон 3)',
          typeLabel: 'Сериал',
          year: 2023,
          isCurrent: false,
          kinopoiskId: 1220920,
        ),
        const FranchiseStep(
          title: 'Тренировки столпов (Сезон 4)',
          typeLabel: 'Сериал',
          year: 2024,
          isCurrent: false,
          kinopoiskId: 1220920,
        ),
      ];
    }

    // Only return franchise steps if movie is part of a real franchise!
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = AppConstants.mediaTypes[widget.type] ?? 'Фильм';
    final isSeries = widget.type == 'series' ||
        widget.type == 'anime' ||
        (widget.genres?.toLowerCase().contains('сериал') ?? false) ||
        (widget.genres?.toLowerCase().contains('аниме') ?? false);

    final franchiseTimeline = _getFranchiseTimeline();

    // Similar items
    final similar = CuratedCatalog.items.where((ci) {
      if (ci.title == widget.title ||
          (widget.kinopoiskId != null && ci.kinopoiskId == widget.kinopoiskId)) {
        return false;
      }
      return ci.type == widget.type ||
          (widget.genres != null &&
              ci.genres.any((g) => widget.genres!.contains(g)));
    }).take(8).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C16),
      body: Column(
        children: [
          const AppHeader(activeRoute: '/library'),
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Top App Header Banner
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF141424),
                      border: Border(bottom: BorderSide(color: Colors.white12)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Colors.white),
                          tooltip: 'Назад',
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              context.go('/library');
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.title}${widget.year != null ? ' (${widget.year})' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Смотреть онлайн $typeLabel в высоком качестве HD 1080p',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Invite Friends / Watch Together Button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.groups_rounded, size: 16),
                          label: const Text('Смотреть с друзьями 🍿',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: _createRoomAndInvite,
                        ),
                      ],
                    ),
                  ),
                ),

                // Player Area
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1080),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Compact Player Tabs Bar with Seasons/Episodes Count on the Right
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF141424),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  // Compact Player Tabs
                                  _buildCompactTab(
                                    label: 'Основной',
                                    isActive: _activeTab == 'collaps',
                                    onTap: () => _switchTab('collaps'),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildCompactTab(
                                    label: 'Резервный',
                                    isActive: _activeTab == 'alloha',
                                    onTap: () => _switchTab('alloha'),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildCompactTab(
                                    label: 'Резервный-2',
                                    isActive: _activeTab == 'backup',
                                    onTap: () => _switchTab('backup'),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildCompactTab(
                                    label: 'Трейлер ▶',
                                    isActive: _activeTab == 'trailer',
                                    onTap: () => _switchTab('trailer'),
                                  ),

                                  const Spacer(),

                                  // Right Badge: Season & Episode Counter (or Movie Duration)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isSeries
                                          ? const Color(0xFF7C3AED)
                                              .withValues(alpha: 0.25)
                                          : Colors.white10,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSeries
                                            ? const Color(0xFF9F67FF)
                                                .withValues(alpha: 0.5)
                                            : Colors.white24,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSeries
                                              ? Icons.video_library_rounded
                                              : Icons.hd_rounded,
                                          size: 14,
                                          color: isSeries
                                              ? const Color(0xFFC084FC)
                                              : const Color(0xFFFFCA28),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isSeries
                                              ? 'Все сезоны • Все серии'
                                              : 'Full HD • 1080p Ultra',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isSeries
                                                ? const Color(0xFFE9D5FF)
                                                : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Cinema 16:9 Player Stage
                            AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.15)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      blurRadius: 28,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15.5),
                                  child: HtmlElementView(viewType: _viewId),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            // Movie Details Block
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF141424),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline_rounded,
                                          color: Color(0xFF9F67FF), size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'О фильме / Сериале',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (widget.genres != null &&
                                          widget.genres!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white10,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            widget.genres!,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.white70),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    widget.description ??
                                        'Приятного просмотра! Вы можете выбрать плеер Collaps HD или запасные Alloha / Kodik вверху, либо создать синхронную комнату с друзьями.',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // 1. Franchise Chronology / Universe Sequence Timeline (only if movie belongs to a franchise)
                            if (franchiseTimeline.isNotEmpty) ...[
                              _buildFranchiseTimelineSection(franchiseTimeline),
                              const SizedBox(height: 28),
                            ],

                            // 2. Similar Movies Carousel
                            if (similar.isNotEmpty) ...[
                              _buildSimilarCarouselSection(similar),
                              const SizedBox(height: 28),
                            ],

                            // 3. Comments & Timestamps Section
                            _buildCommentsSection(),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTab({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF7C3AED) : const Color(0xFF1E1E34),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF9F67FF) : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  // Franchise Chronology Timeline Widget ("сериал, фильм, фильм - вы тут, сериал...")
  Widget _buildFranchiseTimelineSection(List<FranchiseStep> steps) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Хронология франшизы и порядок просмотра',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Сюжетный порядок',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal Timeline Sequence
          SizedBox(
            height: 115,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: steps.length,
              separatorBuilder: (_, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 16, color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
              itemBuilder: (context, idx) {
                final step = steps[idx];
                final isCur = step.isCurrent;

                return InkWell(
                  onTap: () {
                    if (!step.isCurrent && step.kinopoiskId != null) {
                      context.push(
                        '/movie/${step.kinopoiskId}',
                        extra: CatalogItem(
                          kinopoiskId: step.kinopoiskId,
                          title: step.title,
                          type: 'movie',
                          genres: const ['Франшиза'],
                          year: step.year,
                          director: '',
                          actors: '',
                          description: '',
                          posterUrl: '',
                          rating: 8.0,
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 175,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCur
                          ? const Color(0xFF7C3AED).withValues(alpha: 0.25)
                          : const Color(0xFF1B1B32),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCur
                            ? const Color(0xFF9F67FF)
                            : Colors.white.withValues(alpha: 0.1),
                        width: isCur ? 1.5 : 0.8,
                      ),
                      boxShadow: isCur
                          ? [
                              BoxShadow(
                                color: const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isCur
                                    ? const Color(0xFF7C3AED)
                                    : Colors.white12,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                step.typeLabel,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${step.year}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isCur ? FontWeight.w900 : FontWeight.w600,
                            color: isCur ? Colors.white : Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (isCur)
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Вы тут 📍',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF34D399),
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            'Перейти →',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFFC084FC),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Similar Titles Section
  Widget _buildSimilarCarouselSection(List<CatalogItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 18, color: Color(0xFFFFCA28)),
            SizedBox(width: 8),
            Text(
              'Похожие фильмы и сериалы',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final sim = items[i];
              final poster = CatalogItem.fixPosterUrl(sim.posterUrl,
                  kpId: sim.kinopoiskId);

              return InkWell(
                onTap: () => context.push(
                  '/movie/${sim.kinopoiskId ?? sim.title}',
                  extra: sim,
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 130,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141424),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              poster,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: const Color(0xFF1E2230),
                                child: const Center(
                                  child: Icon(Icons.movie_outlined,
                                      color: Colors.white24),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                      color: const Color(0xFFFFCA28),
                                      width: 0.8),
                                ),
                                child: Text(
                                  '★ ${sim.rating.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFFCA28),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                        child: Text(
                          sim.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Interactive Comments Section with Clickable Timestamp Support
  Widget _buildCommentsSection() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF9F67FF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Обсуждение & таймкоды (${_comments.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              const Text(
                'Нажимайте на таймкоды для перехода',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Comment Input Box with Quick Timestamp Insert Button
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _commentCtrl,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  maxLines: 3,
                  minLines: 1,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        'Напишите рецензию или укажите таймкод (например 01:23:45)...',
                    hintStyle: TextStyle(fontSize: 12.5, color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Quick timestamp buttons
                    ActionChip(
                      avatar: const Icon(Icons.timer_outlined,
                          size: 14, color: Color(0xFF9F67FF)),
                      label: const Text('Таймкод 00:15:30',
                          style: TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: const Color(0xFF282845),
                      side: const BorderSide(color: Colors.white12),
                      onPressed: () => _insertTimestampHelper('00:15:30'),
                    ),
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(Icons.timer_outlined,
                          size: 14, color: Color(0xFF9F67FF)),
                      label: const Text('Таймкод 01:05:00',
                          style: TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: const Color(0xFF282845),
                      side: const BorderSide(color: Colors.white12),
                      onPressed: () => _insertTimestampHelper('01:05:00'),
                    ),
                    const Spacer(),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 14),
                      label: const Text('Отправить',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _addComment,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // List of comments with interactive timestamp parsing
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _comments.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white10, height: 24),
            itemBuilder: (context, idx) {
              final c = _comments[idx];
              return _buildCommentTile(c);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(SoloWatchComment c) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF7C3AED),
          backgroundImage:
              c.authorAvatar != null ? NetworkImage(c.authorAvatar!) : null,
          child: c.authorAvatar == null
              ? Text(
                  c.authorName.isNotEmpty
                      ? c.authorName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(width: 12),

        // Text Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    c.authorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  if (c.authorTitle != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color:
                                const Color(0xFF9F67FF).withValues(alpha: 0.4),
                            width: 0.8),
                      ),
                      child: Text(
                        c.authorTitle!,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFFD8B4FE),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    c.timeAgo,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white38,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Rich Text with highlighted clickable timestamps
              _buildCommentTextWithTimestamps(c.text),

              const SizedBox(height: 8),
              // Like action
              InkWell(
                onTap: () {
                  setState(() {
                    c.isLiked = !c.isLiked;
                    c.likes += c.isLiked ? 1 : -1;
                  });
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        c.isLiked
                            ? Icons.thumb_up_rounded
                            : Icons.thumb_up_alt_outlined,
                        size: 13,
                        color: c.isLiked
                            ? const Color(0xFF7C3AED)
                            : Colors.white54,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${c.likes}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.isLiked
                              ? const Color(0xFF9F67FF)
                              : Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Parses timestamps like 01:23:45 or 12:34 and turns them into clickable pills
  Widget _buildCommentTextWithTimestamps(String text) {
    final regex = RegExp(r'\b(?:\d{1,2}:)?\d{2}:\d{2}\b');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12.5,
          height: 1.4,
        ),
      );
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12.5,
            height: 1.4,
          ),
        ));
      }

      final ts = match.group(0)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            onTap: () {
              TopNotification.showSuccess(
                context,
                'Переход к тайм-коду $ts ⏱️',
                title: 'Таймкод',
              );
            },
            borderRadius: BorderRadius.circular(4),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF9F67FF).withValues(alpha: 0.6),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      size: 11, color: Color(0xFFC084FC)),
                  const SizedBox(width: 2),
                  Text(
                    ts,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE9D5FF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12.5,
          height: 1.4,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
