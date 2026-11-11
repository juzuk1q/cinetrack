// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../data/curated_catalog.dart';
import '../../models/catalog_item.dart';
import '../../models/series_episode.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kinopoisk_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/top_notification.dart';
import '../../models/episode_comment.dart';
import '../../repositories/review_repository.dart';



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
  String _activeTab = 'collaps'; // 'collaps', 'videocdn', 'yohoho', 'trailer'
  late String _viewId;
  html.IFrameElement? _iframe;
  bool _blockAds = false;

  int _selectedSeason = 1;
  int _selectedEpisode = 1;
  int _viewingSeason = 1;
  List<SeriesSeason> _seasons = [];
  bool _isLoadingSeasons = false;

  final TextEditingController _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final isLikelySeries = widget.type == 'series' ||
        widget.type == 'anime' ||
        widget.title.toLowerCase().contains('сезон') ||
        (widget.genres?.toLowerCase().contains('сериал') ?? false) ||
        (widget.genres?.toLowerCase().contains('аниме') ?? false);

    // Default to 'collaps' as primary working balancer
    _activeTab = 'collaps';
    _viewId = 'cinetrack-solo-player-${DateTime.now().microsecondsSinceEpoch}';
    _initIframe();
    if (isLikelySeries) {
      _loadSeasons();
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _loadSeasons() async {
    final kpId = widget.kinopoiskId;
    if (kpId == null) return;
    setState(() => _isLoadingSeasons = true);
    try {
      final seasons = await ref.read(kinopoiskServiceProvider).getSeasons(kpId);
      if (mounted) {
        setState(() {
          _seasons = seasons;
          _isLoadingSeasons = false;
          if (_seasons.isNotEmpty) {
            _selectedSeason = _seasons.first.number;
            final aired = _seasons.first.airedEpisodes;
            if (aired.isNotEmpty) {
              _selectedEpisode = aired.first.episodeNumber;
            } else if (_seasons.first.episodes.isNotEmpty) {
              _selectedEpisode = _seasons.first.episodes.first.episodeNumber;
            }
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSeasons = false);
    }
  }

  List<SeriesSeason> get _effectiveSeasons {
    if (_seasons.isNotEmpty) return _seasons;
    final isSeries = widget.type == 'series' ||
        widget.type == 'anime' ||
        widget.title.toLowerCase().contains('сезон') ||
        (widget.genres?.toLowerCase().contains('сериал') ?? false);

    if (isSeries) {
      return [
        SeriesSeason(
          number: 1,
          episodes: List.generate(
            12,
            (index) => SeriesEpisode(
              seasonNumber: 1,
              episodeNumber: index + 1,
              nameRu: 'Серия ${index + 1}',
            ),
          ),
        ),
      ];
    }
    return [];
  }

  SeriesSeason? get _currentSeasonData {
    final eff = _effectiveSeasons;
    if (eff.isEmpty) return null;
    return eff.firstWhere(
      (s) => s.number == _selectedSeason,
      orElse: () => eff.first,
    );
  }

  SeriesSeason? get _viewingSeasonData {
    final eff = _effectiveSeasons;
    if (eff.isEmpty) return null;
    return eff.firstWhere(
      (s) => s.number == _viewingSeason,
      orElse: () => _currentSeasonData ?? eff.first,
    );
  }

  bool get _hasNextEpisode {
    final cur = _currentSeasonData;
    if (cur == null || cur.episodes.isEmpty) return false;
    final aired = cur.airedEpisodes.isNotEmpty ? cur.airedEpisodes : cur.episodes;
    final curIdx = aired.indexWhere((e) => e.episodeNumber == _selectedEpisode);
    if (curIdx >= 0 && curIdx < aired.length - 1) return true;
    final eff = _effectiveSeasons;
    final sIdx = eff.indexWhere((s) => s.number == _selectedSeason);
    return sIdx >= 0 && sIdx < eff.length - 1;
  }

  bool get _hasPrevEpisode {
    final cur = _currentSeasonData;
    if (cur == null || cur.episodes.isEmpty) return false;
    final aired = cur.airedEpisodes.isNotEmpty ? cur.airedEpisodes : cur.episodes;
    final curIdx = aired.indexWhere((e) => e.episodeNumber == _selectedEpisode);
    if (curIdx > 0) return true;
    final eff = _effectiveSeasons;
    final sIdx = eff.indexWhere((s) => s.number == _selectedSeason);
    return sIdx > 0;
  }

  void _nextEpisode() {
    final cur = _currentSeasonData;
    if (cur == null || cur.episodes.isEmpty) return;
    final aired = cur.airedEpisodes.isNotEmpty ? cur.airedEpisodes : cur.episodes;
    final curIdx = aired.indexWhere((e) => e.episodeNumber == _selectedEpisode);
    if (curIdx >= 0 && curIdx < aired.length - 1) {
      _selectEpisode(_selectedSeason, aired[curIdx + 1].episodeNumber);
    } else {
      final eff = _effectiveSeasons;
      final sIdx = eff.indexWhere((s) => s.number == _selectedSeason);
      if (sIdx >= 0 && sIdx < eff.length - 1) {
        final nextS = eff[sIdx + 1];
        final nextAired = nextS.airedEpisodes.isNotEmpty ? nextS.airedEpisodes : nextS.episodes;
        if (nextAired.isNotEmpty) {
          _selectEpisode(nextS.number, nextAired.first.episodeNumber);
        }
      }
    }
  }

  void _prevEpisode() {
    final cur = _currentSeasonData;
    if (cur == null || cur.episodes.isEmpty) return;
    final aired = cur.airedEpisodes.isNotEmpty ? cur.airedEpisodes : cur.episodes;
    final curIdx = aired.indexWhere((e) => e.episodeNumber == _selectedEpisode);
    if (curIdx > 0) {
      _selectEpisode(_selectedSeason, aired[curIdx - 1].episodeNumber);
    } else {
      final eff = _effectiveSeasons;
      final sIdx = eff.indexWhere((s) => s.number == _selectedSeason);
      if (sIdx > 0) {
        final prevS = eff[sIdx - 1];
        final prevAired = prevS.airedEpisodes.isNotEmpty ? prevS.airedEpisodes : prevS.episodes;
        if (prevAired.isNotEmpty) {
          _selectEpisode(prevS.number, prevAired.last.episodeNumber);
        }
      }
    }
  }

  void _selectEpisode(int seasonNum, int episodeNum) {
    if (_selectedSeason == seasonNum && _selectedEpisode == episodeNum) return;

    // Check if target episode is available / aired
    final eff = _effectiveSeasons;
    final targetSeason = eff.firstWhere((s) => s.number == seasonNum, orElse: () => eff.first);
    final targetEp = targetSeason.episodes.firstWhere((e) => e.episodeNumber == episodeNum, orElse: () => targetSeason.episodes.first);
    if (!targetEp.isAired) {
      TopNotification.showWarning(
        context,
        'Серия $episodeNum ещё не вышла! Дата премьеры: ${targetEp.formattedReleaseDate ?? targetEp.releaseDate ?? 'скоро'} ⏳',
        title: 'Серия не доступна',
      );
      return;
    }

    setState(() {
      _selectedSeason = seasonNum;
      _selectedEpisode = episodeNum;
    });
    _iframe?.src = _getCurrentUrl();
    TopNotification.showSuccess(
      context,
      'Сезон $seasonNum, Серия $episodeNum ▶',
      title: 'Выбор серии',
    );
  }



  String _getCurrentUrl() {
    final kpId = widget.kinopoiskId ?? 258687;

    switch (_activeTab) {
      case 'videocdn':
      case 'rezka':
        return 'https://api.delivembd.ws/embed/kp/$kpId?season=$_selectedSeason&episode=$_selectedEpisode';
      case 'kinobox':
        return 'https://kinobox.tv/embed/kp/$kpId?season=$_selectedSeason&episode=$_selectedEpisode';
      case 'yohoho':
      case 'alloha':
        return 'https://4h0y.gitlab.io/#$kpId';
      case 'collaps':
      case 'backup':
      default:
        return 'https://player.shortener2.link/balancer-api/iframe?token=eyJhbGciOiJIUzI1NiJ9.eyJ3ZWJTaXRlIjoiMTkwIiwiaXNzIjoiYXBpLXdlYm1hc3RlciIsInN1YiI6IjI1OCIsImlhdCI6MTc1MzIwOTE0NiwianRpIjoiNjhmZGRhNjUtMmRhYi00ZDNlLWI1YzAtOGZiYjM4MjQyNzcwIiwic2NvcGUiOiJETEUifQ.aV02rM2AtHrgNsKzL9ft9jElwWv7VJsm0UAEbz57MN0&kp=$kpId&season=$_selectedSeason&episode=$_selectedEpisode';
    }
  }

  void _initIframe() {
    final url = _getCurrentUrl();
    _iframe = html.IFrameElement()
      ..src = url
      ..referrerPolicy = 'strict-origin-when-cross-origin'
      ..setAttribute('referrerpolicy', 'strict-origin-when-cross-origin')
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#0A0A14'
      ..allow =
          'autoplay; fullscreen; encrypted-media; picture-in-picture; web-share; clipboard-write';

    if (_blockAds) {
      _iframe!.setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-forms allow-presentation',
      );
    }

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _iframe!,
    );
  }

  void _toggleBlockAds() {
    setState(() {
      _blockAds = !_blockAds;
    });
    if (_iframe != null) {
      if (_blockAds) {
        _iframe!.setAttribute(
          'sandbox',
          'allow-scripts allow-same-origin allow-forms allow-presentation',
        );
      } else {
        _iframe!.removeAttribute('sandbox');
      }
      _iframe!.src = _getCurrentUrl();
    }
    TopNotification.showSuccess(
      context,
      _blockAds
          ? 'Анти-реклама включена: всплывающие окна заблокированы 🛡️'
          : 'Анти-реклама отключена: полный доступ ко всем функциям плеера ⚠️',
      title: 'Защита плеера',
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

  Future<void> _addComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null) {
      TopNotification.showWarning(
        context,
        'Для добавления комментария необходимо войти в аккаунт',
        title: 'Авторизация',
      );
      return;
    }

    final profile = ref.read(userProfileProvider).value;
    final authorName = profile?.displayName.isNotEmpty == true
        ? profile!.displayName
        : (user.email?.split('@').first ?? 'Киноман');

    final kpId = widget.kinopoiskId ?? 0;
    final tcMatch = RegExp(r'(\d{1,2}:\d{2}(?::\d{2})?)').firstMatch(text);
    final timecode = tcMatch?.group(1);

    try {
      await ref.read(reviewRepositoryProvider).addEpisodeComment(
        kinopoiskId: kpId,
        episode: _selectedEpisode,
        season: _selectedSeason,
        timecode: timecode,
        authorName: authorName,
        text: text,
      );
      _commentCtrl.clear();
      ref.invalidate(episodeCommentsProvider((
        kinopoiskId: kpId,
        episode: _selectedEpisode,
        season: _selectedSeason,
      )));
      if (mounted) {
        TopNotification.showSuccess(
          context,
          'Комментарий опубликован! ✨',
          title: 'Обсуждение',
        );
      }
    } catch (e) {
      if (mounted) {
        TopNotification.showError(
          context,
          'Ошибка добавления комментария: $e',
          title: 'Ошибка',
        );
      }
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
        widget.title.toLowerCase().contains('сезон') ||
        (widget.genres?.toLowerCase().contains('сериал') ?? false) ||
        (widget.genres?.toLowerCase().contains('аниме') ?? false);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0C0C16) : const Color(0xFFF8F9FA);
    final cardBg = isDark ? const Color(0xFF141424) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtextColor = isDark ? Colors.white54 : const Color(0xFF6B7280);

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
      backgroundColor: bgColor,
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
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: textColor),
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
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Смотреть онлайн $typeLabel в высоком качестве HD 1080p',
                                style: TextStyle(
                                  color: subtextColor,
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
                          label: Text(
                              MediaQuery.of(context).size.width < 550
                                  ? 'С друзьями 🍿'
                                  : 'Смотреть с друзьями 🍿',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: _createRoomAndInvite,
                        ),
                      ],
                    ),
                  ),
                ),

                // Player & Sidebar Area
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      MediaQuery.of(context).size.width < 700 ? 10 : 20,
                      12,
                      MediaQuery.of(context).size.width < 700 ? 10 : 20,
                      28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isSeries ? 1380 : 1080,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 960;

                            final playerColumn = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPlayerTabs(isDark, isSeries),
                                const SizedBox(height: 10),
                                _buildGeoHint(isDark),
                                const SizedBox(height: 12),
                                _buildCinemaPlayer(),
                                if (isSeries) ...[
                                  const SizedBox(height: 10),
                                  _buildQuickEpisodeNav(isDark),
                                ],
                              ],
                            );

                            final episodesSidebar = isSeries
                                ? _buildEpisodesAndSeasonsSidebar(isDark)
                                : const SizedBox.shrink();

                            if (isWide && isSeries) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: playerColumn,
                                      ),
                                      const SizedBox(width: 20),
                                      SizedBox(
                                        width: 350,
                                        child: episodesSidebar,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _buildMovieDetailsBlock(isDark),
                                  const SizedBox(height: 28),
                                  if (franchiseTimeline.isNotEmpty) ...[
                                    _buildFranchiseTimelineSection(
                                        franchiseTimeline, isDark),
                                    const SizedBox(height: 28),
                                  ],
                                  if (similar.isNotEmpty) ...[
                                    _buildSimilarCarouselSection(
                                        similar, isDark),
                                    const SizedBox(height: 28),
                                  ],
                                  _buildCommentsSection(isDark),
                                  const SizedBox(height: 40),
                                ],
                              );
                            } else {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  playerColumn,
                                  if (isSeries) ...[
                                    const SizedBox(height: 16),
                                    episodesSidebar,
                                  ],
                                  const SizedBox(height: 24),
                                  _buildMovieDetailsBlock(isDark),
                                  const SizedBox(height: 28),
                                  if (franchiseTimeline.isNotEmpty) ...[
                                    _buildFranchiseTimelineSection(
                                        franchiseTimeline, isDark),
                                    const SizedBox(height: 28),
                                  ],
                                  if (similar.isNotEmpty) ...[
                                    _buildSimilarCarouselSection(
                                        similar, isDark),
                                    const SizedBox(height: 28),
                                  ],
                                  _buildCommentsSection(isDark),
                                  const SizedBox(height: 40),
                                ],
                              );
                            }
                          },
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

  Widget _buildPlayerTabs(bool isDark, bool isSeries) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141424) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Player Sources
            _buildCompactTab(
              label: 'Основной',
              isActive: _activeTab == 'collaps' || _activeTab == 'backup',
              onTap: () => _switchTab('collaps'),
              isDark: isDark,
            ),
            const SizedBox(width: 6),
            _buildCompactTab(
              label: 'Резерв 1',
              isActive: _activeTab == 'videocdn',
              onTap: () => _switchTab('videocdn'),
              isDark: isDark,
            ),
            const SizedBox(width: 6),
            _buildCompactTab(
              label: 'Резерв 2',
              isActive: _activeTab == 'kinobox',
              onTap: () => _switchTab('kinobox'),
              isDark: isDark,
            ),
            const SizedBox(width: 6),
            _buildCompactTab(
              label: 'Резерв 3',
              isActive: _activeTab == 'yohoho' || _activeTab == 'alloha',
              onTap: () => _switchTab('yohoho'),
              isDark: isDark,
            ),
            const SizedBox(width: 10),

            // Anti-Ad Sandbox Toggle Pill
            InkWell(
              onTap: _toggleBlockAds,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _blockAds
                      ? const Color(0xFF10B981)
                          .withValues(alpha: isDark ? 0.2 : 0.12)
                      : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _blockAds
                        ? const Color(0xFF10B981).withValues(alpha: 0.5)
                        : (isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _blockAds ? Icons.shield_rounded : Icons.shield_outlined,
                      size: 13,
                      color: _blockAds
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white54 : const Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _blockAds ? 'Анти-реклама: Вкл' : 'Анти-реклама: Выкл',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: _blockAds
                            ? (isDark
                                ? const Color(0xFF6EE7B7)
                                : const Color(0xFF047857))
                            : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Right Badge: Season & Episode Counter (or Movie Duration)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSeries
                    ? const Color(0xFF7C3AED)
                        .withValues(alpha: isDark ? 0.25 : 0.12)
                    : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSeries
                      ? const Color(0xFF9F67FF).withValues(alpha: 0.5)
                      : (isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSeries ? Icons.video_library_rounded : Icons.hd_rounded,
                    size: 13,
                    color: isSeries
                        ? const Color(0xFFC084FC)
                        : const Color(0xFFFFCA28),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isSeries
                        ? 'Сезон $_selectedSeason • Серия $_selectedEpisode'
                        : 'Full HD • 1080p Ultra',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSeries
                          ? (isDark
                              ? const Color(0xFFE9D5FF)
                              : const Color(0xFF7C3AED))
                          : (isDark ? Colors.white : const Color(0xFF111827)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeoHint(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color:
              const Color(0xFF9F67FF).withValues(alpha: isDark ? 0.35 : 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 15, color: Color(0xFFC084FC)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '💡 Если видео не воспроизводится или пишет «недоступно в вашей стране» — переключите плеер на Резерв 1 / Резерв 2.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFFE9D5FF) : const Color(0xFF6B21A8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCinemaPlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
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
    );
  }

  Widget _buildQuickEpisodeNav(bool isDark) {
    final cur = _currentSeasonData;
    final totalInSeason = cur?.episodes.length ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141424) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _hasPrevEpisode ? _prevEpisode : null,
            icon: const Icon(Icons.skip_previous_rounded, size: 16),
            label: const Text('Предыдущая', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor:
                  isDark ? Colors.white70 : const Color(0xFF374151),
              disabledForegroundColor:
                  isDark ? Colors.white24 : const Color(0xFFD1D5DB),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED)
                  .withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF9F67FF).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'Сезон $_selectedSeason • Серия $_selectedEpisode${totalInSeason > 0 ? ' из $totalInSeason' : ''}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color:
                    isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7C3AED),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _hasNextEpisode ? _nextEpisode : null,
            icon: const Icon(Icons.skip_next_rounded, size: 16),
            label: const Text('Следующая серия ▶',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesAndSeasonsSidebar(bool isDark) {
    final effectiveSeasons = _effectiveSeasons;
    final curSeason = _viewingSeasonData ?? _currentSeasonData;
    final allEpisodes = curSeason?.episodes ?? [];

    final cardBg = isDark ? const Color(0xFF141424) : Colors.white;
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);

    return Container(
      height: 560,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.video_library_rounded,
                    color: Color(0xFF9F67FF),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Выбор серии',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                if (_isLoadingSeasons)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF9F67FF),
                    ),
                  )
                else if (curSeason != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      curSeason.hasUpcoming
                          ? '${curSeason.airedCount} из ${curSeason.totalCount} вышло'
                          : '${curSeason.totalCount} сер.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark ? Colors.white70 : const Color(0xFF4B5563),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Horizontal seasons selector tabs
          if (effectiveSeasons.length > 1) ...[
            SizedBox(
              height: 36,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                scrollDirection: Axis.horizontal,
                itemCount: effectiveSeasons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final s = effectiveSeasons[idx];
                  final isSelected = s.number == _viewingSeason;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _viewingSeason = s.number;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF7C3AED)
                            : (isDark
                                ? const Color(0xFF1E1E34)
                                : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF9F67FF)
                              : (isDark
                                  ? Colors.white12
                                  : const Color(0xFFE5E7EB)),
                          width: isSelected ? 1.2 : 0.8,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          s.hasUpcoming
                              ? 'Сезон ${s.number} (${s.airedCount}/${s.totalCount})'
                              : 'Сезон ${s.number}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF374151)),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          Divider(
            height: 1,
            color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
          ),

          // Scrollable episodes list
          Expanded(
            child: allEpisodes.isEmpty
                ? Center(
                    child: Text(
                      'Серии не найдены',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: allEpisodes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 5),
                    itemBuilder: (context, idx) {
                      final ep = allEpisodes[idx];
                      final isPlaying = ep.episodeNumber == _selectedEpisode &&
                          ep.seasonNumber == _selectedSeason;
                      final isAired = ep.isAired;

                      return Opacity(
                        opacity: isAired ? 1.0 : 0.65,
                        child: InkWell(
                          onTap: () =>
                              _selectEpisode(ep.seasonNumber, ep.episodeNumber),
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? const Color(0xFF7C3AED).withValues(
                                      alpha: isDark ? 0.22 : 0.12)
                                  : (isDark
                                      ? const Color(0xFF1B1B30)
                                      : const Color(0xFFF9FAFB)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isPlaying
                                    ? const Color(0xFF9F67FF)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.06)
                                        : const Color(0xFFE5E7EB)),
                                width: isPlaying ? 1.5 : 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: isPlaying
                                        ? const Color(0xFF7C3AED)
                                        : (isDark
                                            ? Colors.white10
                                            : const Color(0xFFE5E7EB)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: isPlaying
                                        ? const Icon(Icons.play_arrow_rounded,
                                            size: 15, color: Colors.white)
                                        : (!isAired
                                            ? Icon(Icons.schedule_rounded,
                                                size: 13,
                                                color: isDark
                                                    ? Colors.white38
                                                    : const Color(0xFF9CA3AF))
                                            : Text(
                                                '${ep.episodeNumber}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDark
                                                      ? Colors.white70
                                                      : const Color(0xFF374151),
                                                ),
                                              )),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ep.displayTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: isPlaying
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: isPlaying
                                              ? const Color(0xFFC084FC)
                                              : (!isAired
                                                  ? (isDark ? Colors.white54 : const Color(0xFF6B7280))
                                                  : textColor),
                                        ),
                                      ),
                                      if (ep.releaseDate != null &&
                                          ep.releaseDate!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          ep.formattedReleaseDate ?? ep.releaseDate!,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            color: isDark
                                                ? Colors.white38
                                                : const Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                if (isPlaying)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Играет',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  )
                                else if (!isAired)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.lock_clock_rounded, size: 10, color: Color(0xFFF59E0B)),
                                        SizedBox(width: 3),
                                        Text(
                                          'Скоро',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFF59E0B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 15,
                                    color: isDark
                                        ? Colors.white24
                                        : const Color(0xFF9CA3AF),
                                  ),
                              ],
                            ),
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

  Widget _buildMovieDetailsBlock(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141424) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: Color(0xFF9F67FF), size: 20),
              const SizedBox(width: 8),
              Text(
                'О фильме / Сериале',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              if (widget.genres != null && widget.genres!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.genres!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            widget.description ??
                'Приятного просмотра! Вы можете выбрать плеер или серию справа, либо создать синхронную комнату с друзьями.',
            style: TextStyle(
              color: isDark ? Colors.white70 : const Color(0xFF4B5563),
              fontSize: 13,
              height: 1.5,
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
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF7C3AED)
              : (isDark ? const Color(0xFF1E1E34) : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFF9F67FF) : Colors.transparent,
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  // Franchise Chronology Timeline Widget ("сериал, фильм, фильм - вы тут, сериал...")
  Widget _buildFranchiseTimelineSection(List<FranchiseStep> steps, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141424) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              Text(
                'Хронология франшизы и порядок просмотра',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF111827),
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
                      size: 16,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : const Color(0xFF9CA3AF)),
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
                          ? const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.25 : 0.12)
                          : (isDark ? const Color(0xFF1B1B32) : const Color(0xFFF9FAFB)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCur
                            ? const Color(0xFF9F67FF)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : const Color(0xFFE5E7EB)),
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
                                    : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                step.typeLabel,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isCur ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${step.year}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? Colors.white54 : const Color(0xFF6B7280),
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
                            color: isCur
                                ? (isDark ? Colors.white : const Color(0xFF7C3AED))
                                : (isDark ? Colors.white70 : const Color(0xFF111827)),
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
                                  color: Color(0xFF10B981),
                                ),
                              ),
                            ],
                          )
                        else
                          const Text(
                            'Перейти →',
                            style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF7C3AED),
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
  Widget _buildSimilarCarouselSection(List<CatalogItem> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 18, color: Color(0xFFFFCA28)),
            const SizedBox(width: 8),
            Text(
              'Похожие фильмы и сериалы',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
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
                    color: isDark ? const Color(0xFF141424) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                    ),
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
                                color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF3F4F6),
                                child: Icon(Icons.movie_outlined,
                                    color: isDark ? Colors.white24 : const Color(0xFF9CA3AF)),
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111827),
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
  Widget _buildCommentsSection(bool isDark) {
    final kpId = widget.kinopoiskId ?? 0;
    final commentsAsync = ref.watch(episodeCommentsProvider((
      kinopoiskId: kpId,
      episode: _selectedEpisode,
      season: _selectedSeason,
    )));
    final comments = commentsAsync.value ?? [];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141424) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF9F67FF), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Обсуждение & таймкоды (${comments.length})',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              Text(
                'Нажимайте на таймкоды для перехода',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Comment Input Box with Quick Timestamp Insert Button
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _commentCtrl,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        'Оставить комментарий к серии... (можно с таймкодом)',
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '💡 Чтобы добавить таймкод, просто напишите его в тексте: 12:45 или 01:20:10',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                      ),
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

          if (comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Пока нет комментариев к этой серии. Будьте первым!',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : const Color(0xFF6B7280),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              separatorBuilder: (_, __) => Divider(
                color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                height: 24,
              ),
              itemBuilder: (context, idx) {
                final c = comments[idx];
                return _buildCommentTile(c, isDark);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(EpisodeComment c, bool isDark) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(userProfileProvider).value;
    final canDelete = (user != null && c.userId == user.id) ||
        (profile != null && (profile.isAdmin || profile.isModerator));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF7C3AED),
          child: Text(
            c.authorName.isNotEmpty ? c.authorName[0].toUpperCase() : 'U',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    c.timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                    ),
                  ),
                  const Spacer(),
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 16, color: Colors.redAccent),
                      tooltip: 'Удалить комментарий',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor:
                                isDark ? const Color(0xFF1E1E34) : Colors.white,
                            title: const Text('Удаление комментария'),
                            content: const Text(
                                'Вы уверены, что хотите удалить этот комментарий?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Отмена'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Удалить',
                                    style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          try {
                            final kpId = widget.kinopoiskId ?? 0;
                            await ref
                                .read(reviewRepositoryProvider)
                                .deleteEpisodeComment(c.id);
                            ref.invalidate(episodeCommentsProvider((
                              kinopoiskId: kpId,
                              episode: _selectedEpisode,
                              season: _selectedSeason,
                            )));
                            if (mounted) {
                              TopNotification.showSuccess(
                                context,
                                'Комментарий удален',
                                title: 'Успешно',
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              TopNotification.showError(
                                context,
                                'Ошибка удаления: $e',
                                title: 'Ошибка',
                              );
                            }
                          }
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Rich Text with highlighted clickable timestamps
              _buildCommentTextWithTimestamps(c.text, isDark),

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
                            : (isDark ? Colors.white54 : const Color(0xFF9CA3AF)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${c.likes}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.isLiked
                              ? const Color(0xFF9F67FF)
                              : (isDark ? Colors.white54 : const Color(0xFF9CA3AF)),
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
  Widget _buildCommentTextWithTimestamps(String text, bool isDark) {
    final regex = RegExp(r'\b(?:\d{1,2}:)?\d{2}:\d{2}\b');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF374151),
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
          style: TextStyle(
            color: isDark ? Colors.white70 : const Color(0xFF374151),
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
                color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.35 : 0.15),
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
                      size: 11, color: Color(0xFF7C3AED)),
                  const SizedBox(width: 2),
                  Text(
                    ts,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFFE9D5FF) : const Color(0xFF7C3AED),
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
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF374151),
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
