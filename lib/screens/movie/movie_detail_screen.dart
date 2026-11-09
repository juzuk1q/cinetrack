import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/curated_catalog.dart';
import '../../models/catalog_item.dart';
import '../../models/media_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/stats_provider.dart';
import '../../services/kinopoisk_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/top_notification.dart';

class MovieDetailScreen extends ConsumerStatefulWidget {
  final CatalogItem? initialItem;
  final String? movieId;

  const MovieDetailScreen({
    super.key,
    this.initialItem,
    this.movieId,
  });

  @override
  ConsumerState<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends ConsumerState<MovieDetailScreen> {
  CatalogItem? _item;
  bool _isLoading = false;
  List<String> _filmImages = [];
  List<Map<String, dynamic>> _filmVideos = [];
  bool _isSavedToCollection = false;

  // Reviews and Episode Comments state
  int _socialTab = 0; // 0: Reviews, 1: Episode Comments
  int _activeEpisode = 1;
  final TextEditingController _newCommentCtrl = TextEditingController();
  final TextEditingController _timecodeCtrl = TextEditingController();
  late List<_MovieReview> _reviews;
  late List<_EpisodeComment> _episodeComments;

  @override
  void initState() {
    super.initState();
    _initSocialData();
    if (widget.initialItem != null) {
      _item = widget.initialItem;
      _loadExtendedData();
    } else {
      _isLoading = true;
      _loadFromId();
    }
  }

  Future<void> _loadFromId() async {
    final rawId = widget.movieId;
    if (rawId == null || rawId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final lower = rawId.toLowerCase();
    if (rawId == '258687' || lower.contains('интерстеллар') || lower.contains('interstellar')) {
      setState(() {
        _item = const CatalogItem(
          kinopoiskId: 258687,
          title: 'Интерстеллар',
          nameOriginal: 'Interstellar',
          type: 'movie',
          typeLabel: 'Фильм',
          genres: ['Фантастика', 'Драма', 'Приключения'],
          countries: ['США', 'Великобритания'],
          year: 2014,
          director: 'Кристофер Нолан',
          actors: 'Мэттью Макконахи, Энн Хэтэуэй, Джессика Честейн, Майкл Кейн, Мэтт Дэймон',
          description:
              'Когда засуха, пыльные бури и вымирание растений приводят человечество к продовольственному кризису, коллектив исследователей и учёных отправляется сквозь червоточину в поисках планеты с подходящими условиями для жизни.',
          posterUrl:
              'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/430042eb-ee69-4818-aed0-a312400a26bf/x1000',
          coverUrl:
              'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/430042eb-ee69-4818-aed0-a312400a26bf/x1000',
          rating: 8.7,
          ratingImdb: 8.7,
          filmLength: 169,
          slogan: 'Следующий шаг человечества станет величайшим',
        );
        _isLoading = false;
      });
      _loadExtendedData();
      return;
    }

    if (rawId == '841681' || lower.contains('токийский') || lower.contains('гуль') || lower.contains('tokyo ghoul')) {
      setState(() {
        _item = const CatalogItem(
          kinopoiskId: 841681,
          title: 'Токийский гуль',
          nameOriginal: 'Tokyo Ghoul',
          type: 'anime',
          typeLabel: 'Аниме-сериал',
          genres: ['Аниме', 'Ужасы', 'Боевик', 'Фэнтези', 'Драма'],
          countries: ['Япония'],
          year: 2014,
          director: 'Сюхэй Морита',
          actors: 'Нацуки Ханаэ, Сора Амамия, Синтаро Асанума, Мамору Мияно',
          description:
              'С обычным студентом Кэном Канэки случается беда, парень попадает в больницу. Но на этом неприятности не заканчиваются: ему пересаживают органы гулей – существ, питающихся человеческой плотью. Канэки становится полугулем и вынужден искать баланс между миром людей и монстров.',
          posterUrl:
              'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/e5d98938-605a-4c8a-b0d6-5f93d926aa0c/x1000',
          coverUrl:
              'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/e5d98938-605a-4c8a-b0d6-5f93d926aa0c/x1000',
          rating: 7.1,
          ratingImdb: 7.8,
          filmLength: 24,
          slogan: 'В мире, где правят монстры, легко забыть, что ты человек',
        );
        _isLoading = false;
      });
      _loadExtendedData();
      return;
    }

    if (rawId == '1143242' || lower.contains('джентльмен') || lower.contains('gentlemen')) {
      setState(() {
        _item = const CatalogItem(
          kinopoiskId: 1143242,
          title: 'Джентльмены',
          nameOriginal: 'The Gentlemen',
          type: 'movie',
          typeLabel: 'Фильм',
          genres: ['Криминал', 'Комедия', 'Боевик'],
          countries: ['Великобритания', 'США'],
          year: 2019,
          director: 'Гай Ричи',
          actors: 'Мэттью Макконахи, Чарли Ханнэм, Генри Голдинг, Хью Грант, Колин Фаррелл',
          description:
              'Один ушлый американец ещё со студенческих лет приторговывал наркотиками, а теперь решил продать свой бизнес крупному миллиардеру.',
          posterUrl:
              'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/637271d5-61b4-4e46-ac83-6d07494c7645/x1000',
          coverUrl:
              'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/637271d5-61b4-4e46-ac83-6d07494c7645/x1000',
          rating: 8.6,
          ratingImdb: 7.8,
          filmLength: 113,
          slogan: 'Преступный мир ждёт короля',
        );
        _isLoading = false;
      });
      _loadExtendedData();
      return;
    }

    if (rawId == '535341' || rawId == '1+1' || lower.contains('intouchables')) {
      setState(() {
        _item = const CatalogItem(
          kinopoiskId: 535341,
          title: '1+1',
          nameOriginal: 'Intouchables',
          type: 'movie',
          typeLabel: 'Фильм',
          genres: ['Драма', 'Комедия', 'Биография'],
          countries: ['Франция'],
          year: 2011,
          director: 'Оливье Накаш, Эрик Толедано',
          actors: 'Франсуа Клюзе, Омар Си, Анн Ле Ни, Одри Флеро',
          description:
              'Пострадав в результате несчастного случая, богатый аристократ Филипп нанимает в качестве сиделки человека, который менее всего подходит для этой работы.',
          posterUrl:
              'https://avatars.mds.yandex.net/get-kinopoisk-image/10900341/caf9f155-1a19-42f1-a0f3-9c8773e9083e/x1000',
          coverUrl:
              'https://avatars.mds.yandex.net/get-kinopoisk-image/10900341/caf9f155-1a19-42f1-a0f3-9c8773e9083e/x1000',
          rating: 8.8,
          ratingImdb: 8.5,
          filmLength: 112,
          slogan: 'Иногда нужно заглянуть в чужой мир, чтобы узнать, чего не хватает в твоем',
        );
        _isLoading = false;
      });
      _loadExtendedData();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final id = int.tryParse(rawId);
      if (id != null) {
        final full = await KinopoiskService().getFilmById(id);
        if (full != null && mounted) {
          setState(() {
            _item = full;
            _isLoading = false;
          });
          _loadExtendedData();
          return;
        }
      } else {
        final decodedKeyword = Uri.decodeComponent(rawId);
        final results = await KinopoiskService().search(decodedKeyword);
        if (results.isNotEmpty && mounted) {
          setState(() {
            _item = results.first;
            _isLoading = false;
          });
          _loadExtendedData();
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadExtendedData() async {
    if (_item == null || _item!.kinopoiskId == null) return;
    final kpId = _item!.kinopoiskId!;

    // Fetch full details if synopsis was truncated
    if (_item!.description.contains('временно отсутствует') ||
        _item!.coverUrl == null) {
      try {
        final full = await KinopoiskService().getFilmById(kpId);
        if (full != null && mounted) {
          setState(() => _item = full);
        }
      } catch (_) {}
    }

    // Fetch stills and backstage photos
    try {
      final images = await KinopoiskService().getFilmImages(kpId);
      if (images.isNotEmpty && mounted) {
        setState(() => _filmImages = images);
      }
    } catch (_) {}

    // Fetch trailers
    try {
      final videos = await KinopoiskService().getFilmVideos(kpId);
      if (videos.isNotEmpty && mounted) {
        setState(() => _filmVideos = videos);
      }
    } catch (_) {}
  }

  void _startSoloWatch() {
    if (_item == null) return;
    final uri = Uri(
      path: '/watch',
      queryParameters: {
        'title': _item!.title,
        'year': _item!.year.toString(),
        if (_item!.kinopoiskId != null) 'kpId': _item!.kinopoiskId.toString(),
        'poster': _item!.posterUrl,
        'type': _item!.type,
        'desc': _item!.description,
        'genres': _item!.genres.join(', '),
      },
    );
    context.go(uri.toString());
  }

  void _startPartyWatch() {
    if (_item == null) return;
    final user = ref.read(currentUserProvider);
    final ownerName = user?.email?.split('@').first ?? 'Организатор';
    final ownerId = user?.id ?? 'host';

    final room = ref.read(roomsProvider.notifier).createRoom(
          title: 'Совместный просмотр: ${_item!.title} 🍿',
          movieTitle: _item!.title,
          movieType: _item!.type,
          moviePoster: _item!.posterUrl,
          movieYear: _item!.year,
          kinopoiskId: _item!.kinopoiskId,
          scheduledAt: DateTime.now(),
          ownerName: ownerName,
          ownerId: ownerId,
        );

    TopNotification.showSuccess(
      context,
      'Комната «${_item!.title}» создана! Подключаемся...',
      title: 'Комната создана 🍿',
    );

    context.go('/rooms/${room.id}');
  }

  Future<void> _toggleCollection() async {
    if (_item == null) return;
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
      return;
    }

    final now = DateTime.now();
    final mediaItem = MediaItem(
      id: '',
      userId: user.id,
      title: _item!.title,
      type: _item!.type,
      genres: _item!.genres,
      year: _item!.year,
      director: _item!.director,
      actors: _item!.actors,
      description: _item!.description,
      posterUrl: _item!.posterUrl,
      status: 'want_to_watch',
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref.read(mediaNotifierProvider.notifier).create(mediaItem);
      ref.invalidate(mediaListProvider);
      ref.invalidate(statsDataProvider);

      setState(() => _isSavedToCollection = true);
      if (!mounted) return;
      TopNotification.showSuccess(
        context,
        '«${_item!.title}» сохранён в вашу коллекцию! ⭐',
        title: 'Коллекция',
      );
    } catch (e) {
      if (!mounted) return;
      TopNotification.showError(
        context,
        'Ошибка добавления: $e',
        title: 'Ошибка',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _item == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0C0C16),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF7C3AED)),
              const SizedBox(height: 16),
              const Text(
                'Загрузка информации о фильме...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => context.go('/library'),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Вернуться в каталог'),
              ),
            ],
          ),
        ),
      );
    }

    final item = _item!;
    final user = ref.watch(currentUserProvider);
    final userDisplayName =
        user?.email?.split('@').first ?? 'Зритель';

    final heroImageUrl = item.coverUrl ?? item.posterUrl;
    final ratingKp = item.rating;
    final ratingImdb = item.ratingImdb ?? (item.rating > 0.5 ? item.rating - 0.2 : 8.1);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C16),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient blurred cover backdrop to remove empty dark dead space
          Positioned.fill(
            child: Opacity(
              opacity: 0.18,
              child: Image.network(
                CatalogItem.fixPosterUrl(heroImageUrl, kpId: item.kinopoiskId),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xEE0C0C16),
                      Color(0xF50C0C16),
                      Color(0xFF0C0C16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            children: [
              const AppHeader(activeRoute: '/library'),
              Expanded(
                child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF141424),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26.5),
                          child: Stack(
                            children: [
                      // Responsive Two-Column Layout (Matching the user mockup)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth > 900;

                          if (isWide) {
                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Left Column: Details, Badges, Synopsis, Actions & Carousel
                                  Expanded(
                                    flex: 6,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(36, 36, 28, 36),
                                      child: _buildDetailsColumn(
                                          item, ratingKp, ratingImdb),
                                    ),
                                  ),

                                  // Right Column: Huge Hero Poster Cutout with Soft Blend
                                  Expanded(
                                    flex: 5,
                                    child: _buildHeroPoster(heroImageUrl),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // Mobile / Compact Layout
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 380,
                                  child: _buildHeroPoster(heroImageUrl),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: _buildDetailsColumn(
                                      item, ratingKp, ratingImdb),
                                ),
                              ],
                            );
                          }
                        },
                      ),

                      // Top Navigation Bar inside the Card (Back Button)
                      Positioned(
                        top: 20,
                        left: 24,
                        child: InkWell(
                          onTap: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              context.go('/library');
                            }
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back_rounded,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'В каталог',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              _buildSimilarMoviesSection(item),
              const SizedBox(height: 28),
              _buildSocialSection(item, userDisplayName),
            ],
          ),
        ),
      ),
    ),
  ),
],
),
],
),
    );
  }

  // Large Hero Poster on the Right with Soft Dark Vignette
  Widget _buildHeroPoster(String imageUrl) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          CatalogItem.fixPosterUrl(imageUrl),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF261042), Color(0xFF1B1B36), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Icon(Icons.movie_filter_rounded,
                  size: 72, color: Colors.white.withValues(alpha: 0.15)),
            ),
          ),
        ),

        // Gradient Left Shadow to smoothly melt into the dark UI card
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF141424),
                  Colors.transparent,
                  Colors.transparent,
                ],
                stops: [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // Gradient Bottom Shadow
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color(0xFF141424).withValues(alpha: 0.85),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.35],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Left Details Column (Typography, Badges, Ratings, Buttons & Bottom Photos)
  Widget _buildDetailsColumn(
      CatalogItem item, double ratingKp, double ratingImdb) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 36),

        // Big Movie Title (Stylized bold typography like MONSTERS, INC.)
        Text(
          item.title.toUpperCase(),
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.8,
            height: 1.1,
          ),
        ),

        // Original Name (e.g. Monsters, Inc. / Death Note)
        if (item.nameOriginal != null && item.nameOriginal!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            item.nameOriginal!,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white54,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 14),

        // Studio & Genre Badges Row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Studio / Format Badge (e.g. Disney / Pixar / Аниме-сериал)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF282845),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Text(
                item.displayTypeLabel.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // Genres
            ...item.genres.take(4).map((g) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12, width: 0.8),
                ),
                child: Text(
                  g,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 18),

        // Ratings & Accolades Row (IMDb + Кинопоиск + Rotten Tomatoes + Metacritic + Letterboxd + MPA)
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Star IMDb
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded,
                      size: 14, color: Color(0xFFFFCA28)),
                  const SizedBox(width: 4),
                  Text(
                    'IMDb ${item.effectiveImdb.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Кинопоиск
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6600).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFF6600), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⭐️', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 4),
                  Text(
                    'КП ${ratingKp.toStringAsFixed(1)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Year & Runtime / Awards
            Text(
              '${item.year} год  •  ${item.filmLength != null ? '${item.filmLength} мин' : (item.isSeries ? 'Все серии' : 'Полный метр')}',
              style: const TextStyle(
                color: Color(0xFFC7D2FE),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Synopsis (Description)
        Text(
          item.description,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),

        // Action Buttons Row (Matching mockup: [▶ Watch] [🍿 Совместный] [🔖 В коллекцию] [⋯])
        Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Primary White Pill Button: [ ▶ Watch ]
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 6,
              ),
              icon: const Icon(Icons.play_arrow_rounded,
                  size: 20, color: Colors.black),
              label: const Text(
                'Смотреть онлайн',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              onPressed: _startSoloWatch,
            ),

            // Secondary Button: [ 🍿 Совместный просмотр ]
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.18),
                side: const BorderSide(color: Color(0xFF7C3AED), width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              icon: const Icon(Icons.groups_rounded,
                  size: 18, color: Color(0xFF9F67FF)),
              label: const Text(
                'Смотреть с друзьями 🍿',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              onPressed: _startPartyWatch,
            ),

            // Add to Collection Pill Button
            InkWell(
              onTap: _toggleCollection,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _isSavedToCollection
                      ? const Color(0xFF10B981)
                      : const Color(0xFF222238),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _isSavedToCollection
                        ? const Color(0xFF10B981)
                        : Colors.white24,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isSavedToCollection
                          ? Icons.bookmark_added_rounded
                          : Icons.bookmark_add_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isSavedToCollection ? 'В коллекции' : 'В коллекцию',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Bottom Carousel Header: "Кадры и видео (Videos & Photos) >"
        Row(
          children: [
            Text(
              'Кадры и видео (${_filmImages.length + 1})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Colors.white54),
          ],
        ),
        const SizedBox(height: 12),

        // Horizontal Carousel of Stills and Trailer Card
        SizedBox(
          height: 82,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Trailer Thumbnail Card (Play icon + duration badge)
              InkWell(
                onTap: _startSoloWatch,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF7C3AED), width: 1.2),
                    image: DecorationImage(
                      image: NetworkImage(CatalogItem.fixPosterUrl(item.posterUrl)),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.45),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(Icons.play_circle_fill_rounded,
                            size: 28, color: Colors.white),
                      ),
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _filmVideos.isNotEmpty
                                ? '▶ ${_filmVideos.first['name'] ?? 'Трейлер'}'
                                : '▶ Трейлер',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Kinopoisk Stills and Backstage photos
              if (_filmImages.isNotEmpty)
                ..._filmImages.map((imgUrl) {
                  return Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      CatalogItem.fixPosterUrl(imgUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white10,
                        child: const Icon(Icons.photo_rounded,
                            size: 24, color: Colors.white30),
                      ),
                    ),
                  );
                })
              else
                // Curated fallback stills if API limits
                ...[
                  item.coverUrl ?? item.posterUrl,
                  item.posterUrl,
                ].map((fallbackUrl) {
                  return Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      CatalogItem.fixPosterUrl(fallbackUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.white10,
                        child: const Icon(Icons.photo_rounded,
                            size: 24, color: Colors.white30),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSpecsSection(item),
      ],
    );
  }

  Widget _buildSpecsSection(CatalogItem item) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF9F67FF)),
              const SizedBox(width: 8),
              Text(
                'О ${item.isSeries ? 'сериале' : 'фильме'}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              if (item.countries.isNotEmpty)
                _buildSpecItem('Страна', item.countries.join(', ')),
              _buildSpecItem('Год производства', '${item.year}'),
              if (item.director.isNotEmpty)
                _buildSpecItem('Режиссёр', item.director),
              if (item.actors.isNotEmpty)
                _buildSpecItem('В главных ролях', item.actors),
              if (item.slogan != null && item.slogan!.isNotEmpty)
                _buildSpecItem('Слоган', '«${item.slogan}»'),
              _buildSpecItem('Возраст', item.effectiveMpa),
              _buildSpecItem('Качество', '4K Ultra HD • HDR10 • 5.1 Surround'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return SizedBox(
      width: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white54,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarMoviesSection(CatalogItem currentItem) {
    final similar = CuratedCatalog.items
        .where((ci) =>
            ci.title != currentItem.title &&
            ci.kinopoiskId != currentItem.kinopoiskId)
        .take(6)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFFFFCA28)),
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
          height: 185,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: similar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final sim = similar[i];
              return InkWell(
                onTap: () => context.push(
                  '/movie/${sim.kinopoiskId ?? sim.title}',
                  extra: sim,
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        CatalogItem.fixPosterUrl(sim.posterUrl, kpId: sim.kinopoiskId),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1E2230),
                          child: const Center(
                            child: Icon(Icons.movie_outlined, color: Colors.white24),
                          ),
                        ),
                      ),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                            stops: [0.5, 1.0],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFFCA28), width: 0.8),
                          ),
                          child: Text(
                            '★ ${sim.rating.toStringAsFixed(1)}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFFCA28),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Text(
                          sim.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
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

  void _initSocialData() {
    _reviews = [
      _MovieReview(
        id: 'rev-1',
        authorName: 'Алексей Киноманов',
        authorTitle: 'Кинокритик 👑',
        rating: 9.2,
        type: 'positive',
        title: 'Шедевр современной анимации с глубоким посылом',
        text:
            'Визуальная часть поражает воображение — детализация воды, шерсти и света сделаны на высочайшем уровне. Но главное здесь — это искренний посыл о доверии в расколотом мире.',
        date: 'Вчера, 18:40',
        likes: 24,
      ),
      _MovieReview(
        id: 'rev-2',
        authorName: 'Мария Сериаломан',
        authorTitle: 'Зритель CineTrack 🍿',
        rating: 8.5,
        type: 'positive',
        title: 'Дракон Сису украла всё внимание!',
        text:
            'Прекрасный семейный просмотр. Юмор отличный, динамика держит до самого конца. Очень рекомендую смотреть именно в оригинале или дубляже.',
        date: '3 дня назад',
        likes: 15,
      ),
      _MovieReview(
        id: 'rev-3',
        authorName: 'Дмитрий В.',
        authorTitle: 'Ночной зритель 🌙',
        rating: 7.0,
        type: 'neutral',
        title: 'Красиво, но сюжет достаточно предсказуемый',
        text:
            'Отличный приключенческий фильм на вечер. Графика 10 из 10, музыка превосходная, хотя сюжетные повороты угадываются с первых минут.',
        date: 'Неделю назад',
        likes: 7,
      ),
    ];

    _episodeComments = [
      _EpisodeComment(
        id: 'com-1',
        episode: 1,
        authorName: 'Vladislav_Pro',
        text:
            'Начало просто легендарное! Музыкальное сопровождение нагнетает атмосферу на максимум.',
        timecode: '08:45',
        date: 'Вчера',
        likes: 9,
      ),
      _EpisodeComment(
        id: 'com-2',
        episode: 1,
        authorName: 'AnimeFan99',
        text:
            'Кто заметил отсылку к старым фильмам на этом таймкоде? Гениально сделано!',
        timecode: '21:10',
        date: '2 дня назад',
        likes: 14,
      ),
      _EpisodeComment(
        id: 'com-3',
        episode: 2,
        authorName: 'Daria_K',
        text:
            'Вторая серия ещё мощнее! Не ожидал такого поворота сюжета в конце.',
        timecode: '42:15',
        date: '3 дня назад',
        likes: 11,
      ),
      _EpisodeComment(
        id: 'com-4',
        episode: 3,
        authorName: 'CinemaMaster',
        text:
            'Операторская работа в этой боевой сцене просто запредельная.',
        timecode: '15:20',
        date: '5 дней назад',
        likes: 8,
      ),
    ];
  }

  Widget _buildSocialSection(CatalogItem item, String userDisplayName) {
    final isSeries = item.type == 'series' || item.type == 'anime';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141424),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Tabs: Reviews vs Episode Comments
          Row(
            children: [
              _buildTabPill(
                label: '💬 Отзывы и рецензии (${_reviews.length})',
                isSelected: _socialTab == 0,
                onTap: () => setState(() => _socialTab = 0),
              ),
              const SizedBox(width: 12),
              _buildTabPill(
                label: isSeries
                    ? '📺 Комментарии к сериям'
                    : '🎬 Обсуждение моментов',
                isSelected: _socialTab == 1,
                onTap: () => setState(() => _socialTab = 1),
              ),
              const Spacer(),
              if (_socialTab == 0)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.rate_review_rounded, size: 16),
                  label: const Text('Написать рецензию',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  onPressed: () => _showAddReviewDialog(userDisplayName),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // TAB 0: Reviews Section
          if (_socialTab == 0) ...[
            _buildReviewsList(),
          ]
          // TAB 1: Episode Comments / Moments Section
          else ...[
            _buildEpisodeCommentsView(userDisplayName, isSeries: isSeries),
          ],
        ],
      ),
    );
  }

  Widget _buildTabPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF7C3AED) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF9F67FF) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsList() {
    return Column(
      children: _reviews.map((rev) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B2F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Author Avatar, Name, Title, Rating, Date
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF7C3AED),
                    child: Text(
                      rev.authorName.isNotEmpty
                          ? rev.authorName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              rev.authorName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                rev.authorTitle,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          rev.date,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            size: 14, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 4),
                        Text(
                          '${rev.rating.toStringAsFixed(1)} / 10',
                          style: const TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w800,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                rev.title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),

              // Body text
              Text(
                rev.text,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 14),

              // Action Bar (Thumbs Up / Like)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (rev.isLiked) {
                          rev.likes--;
                          rev.isLiked = false;
                        } else {
                          rev.likes++;
                          rev.isLiked = true;
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: rev.isLiked
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: rev.isLiked
                              ? const Color(0xFF10B981)
                              : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            rev.isLiked
                                ? Icons.thumb_up_rounded
                                : Icons.thumb_up_outlined,
                            size: 14,
                            color: rev.isLiked
                                ? const Color(0xFF10B981)
                                : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Полезно (${rev.likes})',
                            style: TextStyle(
                              color: rev.isLiked
                                  ? const Color(0xFF10B981)
                                  : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEpisodeCommentsView(String userDisplayName, {required bool isSeries}) {
    final episodeComments = isSeries
        ? _episodeComments.where((c) => c.episode == _activeEpisode).toList()
        : _episodeComments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Episode Picker Chips (Only shown for TV series, hidden for films!)
        if (isSeries) ...[
          const Text(
            'Выберите серию для обсуждения:',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(12, (i) {
                final ep = i + 1;
                final isSel = _activeEpisode == ep;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _activeEpisode = ep),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSel
                            ? const Color(0xFF7C3AED)
                            : const Color(0xFF1F1F35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              isSel ? const Color(0xFF9F67FF) : Colors.white12,
                        ),
                      ),
                      child: Text(
                        'Серия $ep',
                        style: TextStyle(
                          color: isSel ? Colors.white : Colors.white70,
                          fontWeight:
                              isSel ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
        ] else ...[
          const Row(
            children: [
              Icon(Icons.movie_filter_rounded, size: 18, color: Color(0xFF9F67FF)),
              SizedBox(width: 8),
              Text(
                'Обсуждение ярких моментов и таймкоды фильма',
                style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        // New Comment Input Card with prominent Timecode
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: const Color(0xFF7C3AED),
                    child: Text(
                      userDisplayName.isNotEmpty
                          ? userDisplayName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isSeries
                        ? 'Оставить комментарий к серии $_activeEpisode:'
                        : 'Оставить комментарий к фильму:',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Colors.white),
                  ),
                  const Spacer(),
                  // Prominent Timecode input
                  SizedBox(
                    width: 140,
                    height: 34,
                    child: TextField(
                      controller: _timecodeCtrl,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: '⏱ 12:40',
                        hintStyle: const TextStyle(
                            fontSize: 11, color: Colors.white38),
                        prefixIcon: const Icon(Icons.timer_rounded,
                            size: 15, color: Color(0xFF9F67FF)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        filled: true,
                        fillColor: const Color(0xFF121220),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 0.8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.white24, width: 0.8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF9F67FF), width: 1.2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Quick Timecode Presets
              Row(
                children: [
                  const Text('Быстрый таймкод: ', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ...['05:30', '14:20', '35:10', '01:10:00'].map((tc) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => setState(() => _timecodeCtrl.text = tc),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            tc,
                            style: const TextStyle(color: Color(0xFFC084FC), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _newCommentCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: isSeries
                      ? 'Поделитесь впечатлением о серии...'
                      : 'Поделитесь впечатлением о моменте фильма...',
                  hintStyle:
                      const TextStyle(fontSize: 12, color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF121220),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Отправить',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () {
                    final text = _newCommentCtrl.text.trim();
                    if (text.isEmpty) return;
                    final tc = _timecodeCtrl.text.trim();
                    setState(() {
                      _episodeComments.insert(
                        0,
                        _EpisodeComment(
                          id: 'com-${DateTime.now().millisecondsSinceEpoch}',
                          episode: isSeries ? _activeEpisode : 1,
                          authorName: userDisplayName,
                          text: text,
                          timecode: tc.isNotEmpty ? tc : null,
                          date: 'Только что',
                        ),
                      );
                      _newCommentCtrl.clear();
                      _timecodeCtrl.clear();
                    });
                    TopNotification.showSuccess(
                      context,
                      'Комментарий успешно добавлен!',
                      title: 'Обсуждение',
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Comments List
        if (episodeComments.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Text(
              isSeries
                  ? 'К этой серии ещё нет комментариев. Будьте первыми!'
                  : 'К этому фильму ещё нет комментариев. Будьте первыми!',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          )
        else
          Column(
            children: episodeComments.map((com) {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B2F),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF6366F1),
                      child: Text(
                        com.authorName.isNotEmpty
                            ? com.authorName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                com.authorName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Colors.white),
                              ),
                              if (com.timecode != null) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    _startSoloWatch();
                                    TopNotification.showInfo(
                                      context,
                                      'Переход к моменту [ ${com.timecode} ]',
                                      title: 'Таймкод',
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED)
                                          .withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: const Color(0xFF9F67FF),
                                          width: 0.9),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.play_circle_fill_rounded,
                                            size: 13,
                                            color: Color(0xFFC084FC)),
                                        const SizedBox(width: 3.5),
                                        Text(
                                          com.timecode!,
                                          style: const TextStyle(
                                              color: Color(0xFFE9D5FF),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                com.date,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            com.text,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (com.isLiked) {
                            com.likes--;
                            com.isLiked = false;
                          } else {
                            com.likes++;
                            com.isLiked = true;
                          }
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            com.isLiked
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 14,
                            color: com.isLiked
                                ? const Color(0xFFEF4444)
                                : Colors.white38,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${com.likes}',
                            style: TextStyle(
                              color: com.isLiked
                                  ? const Color(0xFFEF4444)
                                  : Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  void _showAddReviewDialog(String userDisplayName) {
    double ratingVal = 9.0;
    final titleCtrl = TextEditingController();
    final textCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E34),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: Colors.white12),
              ),
              title: const Row(
                children: [
                  Icon(Icons.rate_review_rounded, color: Color(0xFF9F67FF)),
                  SizedBox(width: 10),
                  Text('Написать рецензию'),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Interactive Star Rating (supports half-stars)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Ваша оценка:',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '★ ${ratingVal.toStringAsFixed(1)} / 10',
                              style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(10, (idx) {
                              final starNum = idx + 1;
                              IconData icon;
                              if (ratingVal >= starNum) {
                                icon = Icons.star_rounded;
                              } else if (ratingVal >= starNum - 0.5) {
                                icon = Icons.star_half_rounded;
                              } else {
                                icon = Icons.star_outline_rounded;
                              }

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) {
                                  // Click left half = half-star, right half = full star
                                  final isLeft = details.localPosition.dx < 16;
                                  setDlgState(() {
                                    ratingVal = isLeft ? starNum - 0.5 : starNum.toDouble();
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                  child: Icon(
                                    icon,
                                    size: 30,
                                    color: const Color(0xFFFFCA28),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      const Text('Заголовок рецензии:',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          hintText: 'Коротко о главном...',
                          hintStyle: const TextStyle(
                              fontSize: 12, color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF141424),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Text
                      const Text('Текст вашей рецензии:',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: textCtrl,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText:
                              'Поделитесь подробными впечатлениями от сюжета, актерской игры и визуала...',
                          hintStyle: const TextStyle(
                              fontSize: 12, color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF141424),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED)),
                  onPressed: () {
                    final t = titleCtrl.text.trim();
                    final b = textCtrl.text.trim();
                    if (t.isEmpty || b.isEmpty) return;

                    setState(() {
                      _reviews.insert(
                        0,
                        _MovieReview(
                          id: 'rev-${DateTime.now().millisecondsSinceEpoch}',
                          authorName: userDisplayName,
                          authorTitle: 'Зритель CineTrack 🍿',
                          rating: ratingVal,
                          type: ratingVal >= 7.0
                              ? 'positive'
                              : (ratingVal >= 5.0 ? 'neutral' : 'negative'),
                          title: t,
                          text: b,
                          date: 'Только что',
                        ),
                      );
                    });
                    Navigator.of(ctx).pop();
                    TopNotification.showSuccess(
                      context,
                      'Рецензия успешно опубликована! ⭐',
                      title: 'Рецензия добавлена',
                    );
                  },
                  child: const Text('Опубликовать',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MovieReview {
  final String id;
  final String authorName;
  final String authorTitle;
  final double rating;
  final String type; // 'positive' | 'neutral' | 'negative'
  final String title;
  final String text;
  final String date;
  int likes;
  bool isLiked = false;

  _MovieReview({
    required this.id,
    required this.authorName,
    required this.authorTitle,
    required this.rating,
    required this.type,
    required this.title,
    required this.text,
    required this.date,
    this.likes = 0,
  });
}

class _EpisodeComment {
  final String id;
  final int episode;
  final String authorName;
  final String text;
  final String? timecode;
  final String date;
  int likes;
  bool isLiked = false;

  _EpisodeComment({
    required this.id,
    required this.episode,
    required this.authorName,
    required this.text,
    this.timecode,
    required this.date,
    this.likes = 0,
  });
}
