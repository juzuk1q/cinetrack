import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/catalog_item.dart';
import '../providers/auth_provider.dart';
import '../providers/room_provider.dart';

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

  static final List<CatalogItem> _searchCatalog = [
    const CatalogItem(
      kinopoiskId: 258687,
      title: 'Интерстеллар',
      nameOriginal: 'Interstellar',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Фантастика', 'Драма', 'Приключения'],
      countries: ['США', 'Великобритания'],
      year: 2014,
      director: 'Кристофер Нолан',
      actors: 'Мэттью Макконахи, Энн Хэтэуэй, Джессика Честейн, Майкл Кейн',
      description:
          'Когда засуха и пыльные бури приводят человечество к продовольственному кризису, коллектив ученых отправляется сквозь червоточину в поисках нового дома.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1601250/20399d86-a579-4a00-b6e5-4a69ec40fe50/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1601250/20399d86-a579-4a00-b6e5-4a69ec40fe50/orig',
      rating: 8.7,
      ratingImdb: 8.7,
      filmLength: 169,
      slogan: 'Следующий шаг человечества станет величайшим',
    ),
    const CatalogItem(
      kinopoiskId: 1143242,
      title: 'Джентльмены',
      nameOriginal: 'The Gentlemen',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Криминал', 'Комедия', 'Боевик'],
      countries: ['Великобритания', 'США'],
      year: 2019,
      director: 'Гай Ричи',
      actors: 'Мэттью Макконахи, Чарли Ханнэм, Генри Голдинг, Хью Грант',
      description:
          'Один ушлый американец ещё со студенческих лет приторговывал наркотиками, а теперь решил продать свой бизнес крупному миллиардеру.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/637f8486-bd54-4241-94a8-18e5477e823f/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/637f8486-bd54-4241-94a8-18e5477e823f/orig',
      rating: 8.6,
      ratingImdb: 7.8,
      filmLength: 113,
      slogan: 'Преступный мир ждёт короля',
    ),
    const CatalogItem(
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
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1946459/bf93b465-1189-4155-9dd1-cb9fb5cb1bb5/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1946459/bf93b465-1189-4155-9dd1-cb9fb5cb1bb5/orig',
      rating: 8.8,
      ratingImdb: 8.5,
      filmLength: 112,
      slogan: 'Иногда нужно заглянуть в чужой мир, чтобы узнать, чего не хватает в твоем',
    ),
    const CatalogItem(
      kinopoiskId: 397667,
      title: 'Остров проклятых',
      nameOriginal: 'Shutter Island',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Детектив', 'Триллер', 'Драма'],
      countries: ['США'],
      year: 2009,
      director: 'Мартин Скорсезе',
      actors: 'Леонардо ДиКаприо, Марк Руффало, Бен Кингсли',
      description:
          'Два судебных пристава отправляются на остров в Массачусетсе, чтобы расследовать исчезновение пациентки из клиники для умалишенных преступников.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4303601/bb861b53-488f-4ba3-ab4d-0db066a3b2b4/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4303601/bb861b53-488f-4ba3-ab4d-0db066a3b2b4/orig',
      rating: 8.6,
      ratingImdb: 8.2,
      filmLength: 138,
      slogan: 'Некоторые места никогда не отпускают',
    ),
    const CatalogItem(
      kinopoiskId: 326,
      title: 'Побег из Шоушенка',
      nameOriginal: 'The Shawshank Redemption',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Драма', 'Криминал'],
      countries: ['США'],
      year: 1994,
      director: 'Фрэнк Дарабонт',
      actors: 'Тим Роббинс, Морган Фриман, Боб Гантон',
      description:
          'Бухгалтер Энди Дюфрейн обвинён в убийстве собственной жены и её любовника. Оказавшись в тюрьме Шоушенк, он сталкивается с жестокостью, но не теряет надежду.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/b29ae1b3-40d6-44ec-9d62-10e3dcf8c078/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/b29ae1b3-40d6-44ec-9d62-10e3dcf8c078/orig',
      rating: 9.1,
      ratingImdb: 9.3,
      filmLength: 142,
      slogan: 'Страх держит взаперти. Надежда освобождает',
    ),
    const CatalogItem(
      kinopoiskId: 361,
      title: 'Бойцовский клуб',
      nameOriginal: 'Fight Club',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Триллер', 'Драма', 'Криминал'],
      countries: ['США', 'Германия'],
      year: 1999,
      director: 'Дэвид Финчер',
      actors: 'Эдвард Нортон, Брэд Питт, Хелена Бонем Картер',
      description:
          'Сотрудник страховой компании страдает бессонницей и пытается вырваться из скучной жизни. Он встречает торговца мылом Тайлера Дёрдена с извращенной философией.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1946459/1191a27e-8973-4560-93bc-3fa12217e145/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1946459/1191a27e-8973-4560-93bc-3fa12217e145/orig',
      rating: 8.7,
      ratingImdb: 8.8,
      filmLength: 139,
      slogan: 'Интриги. Хаос. Мыло',
    ),
    const CatalogItem(
      kinopoiskId: 447301,
      title: 'Начало',
      nameOriginal: 'Inception',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Фантастика', 'Боевик', 'Триллер'],
      countries: ['США', 'Великобритания'],
      year: 2010,
      director: 'Кристофер Нолан',
      actors: 'Леонардо ДиКаприо, Джозеф Гордон-Левитт, Эллиот Пейдж',
      description:
          'Кобб — талантливый вор, лучший из лучших в опасном искусстве извлечения: он крадет ценные секреты из глубин подсознания во время сна.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1629390/8ab9a111-00e3-4777-98ec-96ca665a2295/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1629390/8ab9a111-00e3-4777-98ec-96ca665a2295/orig',
      rating: 8.8,
      ratingImdb: 8.8,
      filmLength: 148,
      slogan: 'Твой разум — место преступления',
    ),
    const CatalogItem(
      kinopoiskId: 1047883,
      title: 'Райя и последний дракон',
      nameOriginal: 'Raya and the Last Dragon',
      type: 'cartoon',
      typeLabel: 'Мультфильм',
      genres: ['Мультфильм', 'Фэнтези', 'Боевик', 'Приключения'],
      countries: ['США'],
      year: 2021,
      director: 'Дон Холл, Карлос Лопес Эстрада',
      actors: 'Келли Мари Трэн, Аквафина, Джемма Чан, Дэниэл Дэ Ким',
      description:
          'Отважная воительница Райя отправляется на поиски последнего дракона Сису, чтобы объединить разрозненные народы Кумандры и победить древних демонов.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/c4530fcb-82be-4767-9d7e-bb2fe9a4ceef/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/c4530fcb-82be-4767-9d7e-bb2fe9a4ceef/orig',
      rating: 8.2,
      ratingImdb: 8.3,
      filmLength: 107,
    ),
    const CatalogItem(
      kinopoiskId: 1318854,
      title: 'Аркейн',
      nameOriginal: 'Arcane: League of Legends',
      type: 'series',
      typeLabel: 'Анимация',
      genres: ['Анимация', 'Фэнтези', 'Боевик', 'Фантастика'],
      countries: ['США', 'Франция'],
      year: 2021,
      director: 'Паскаль Шаррю, Арно Делорд',
      actors: 'Хейли Стайнфелд, Кевин Алехандро, Кэти Льюнг',
      description:
          'История двух сестер Вай и Джинкс, оказавшихся по разные стороны баррикад в конфликте между богатым Пилтовером и захудалым Зауном.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4303601/60334800-4b52-4467-b50a-e866657c9172/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4303601/60334800-4b52-4467-b50a-e866657c9172/orig',
      rating: 8.8,
      ratingImdb: 9.0,
      filmLength: 42,
    ),
    const CatalogItem(
      kinopoiskId: 404900,
      title: 'Во все тяжкие',
      nameOriginal: 'Breaking Bad',
      type: 'series',
      typeLabel: 'Сериал',
      genres: ['Криминал', 'Драма', 'Триллер'],
      countries: ['США'],
      year: 2008,
      director: 'Винс Гиллиган',
      actors: 'Брайан Крэнстон, Аарон Пол, Анна Ганн',
      description:
          'Школьный учитель химии Уолтер Уайт узнаёт, что болен раком легких, и начинает производить метамфетамин ради будущего семьи.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/ea7ec857-4b10-4cc8-8d23-ab3a3ad0246d/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/ea7ec857-4b10-4cc8-8d23-ab3a3ad0246d/orig',
      rating: 9.5,
      ratingImdb: 9.5,
      filmLength: 47,
    ),
    const CatalogItem(
      kinopoiskId: 395646,
      title: 'Тетрадь смерти',
      nameOriginal: 'Death Note',
      type: 'anime',
      typeLabel: 'Аниме-сериал',
      genres: ['Аниме', 'Триллер', 'Детектив', 'Фэнтези'],
      countries: ['Япония'],
      year: 2006,
      director: 'Тэцуро Араки',
      actors: 'Мамору Мияно, Каппэй Ямагути, Сидо Накамура',
      description:
          'Лучший школьник Японии Лайт Ягами находит тетрадь бога смерти Рюка, позволяющую убить любого человека, зная его имя и лицо.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/d67e6e30-b9ee-471d-a3df-767ff35467e2/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/d67e6e30-b9ee-471d-a3df-767ff35467e2/orig',
      rating: 8.6,
      ratingImdb: 9.0,
      filmLength: 22,
    ),
    const CatalogItem(
      kinopoiskId: 841681,
      title: 'Токийский гуль',
      nameOriginal: 'Tokyo Ghoul',
      type: 'anime',
      typeLabel: 'Аниме-сериал',
      genres: ['Аниме', 'Ужасы', 'Боевик', 'Фэнтези', 'Драма'],
      countries: ['Япония'],
      year: 2014,
      director: 'Сюхэй Морита',
      actors: 'Нацуки Ханаэ, Сора Амамия, Синтаро Асанума',
      description:
          'Студент Кэн Канэки после нападения гуля попадает в больницу, где ему пересаживают органы монстра. Теперь он наполовину гуль и вынужден выживать среди чудовищ.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/e5d98938-605a-4c8a-b0d6-5f93d926aa0c/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/e5d98938-605a-4c8a-b0d6-5f93d926aa0c/x1000',
      rating: 7.1,
      ratingImdb: 7.8,
      filmLength: 24,
      slogan: 'В мире, полном монстров, легко стать одним из них',
    ),
    const CatalogItem(
      kinopoiskId: 749374,
      title: 'Атака титанов',
      nameOriginal: 'Attack on Titan',
      type: 'anime',
      typeLabel: 'Аниме-сериал',
      genres: ['Аниме', 'Боевик', 'Драма', 'Фэнтези'],
      countries: ['Япония'],
      year: 2013,
      director: 'Тэцуро Араки, Масаси Коидзука',
      actors: 'Юки Кадзи, Юи Исикава, Марина Иноуэ',
      description:
          'Остатки человечества укрылись за тремя гигантскими стенами от свирепых титанов-людоедов. Эрен Йегер клянется отомстить за гибель матери.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/dd0060dc-d18e-4754-8e47-e6f6630f9d92/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/dd0060dc-d18e-4754-8e47-e6f6630f9d92/orig',
      rating: 8.7,
      ratingImdb: 9.1,
      filmLength: 24,
    ),
    const CatalogItem(
      kinopoiskId: 4664634,
      title: 'Оппенгеймер',
      nameOriginal: 'Oppenheimer',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Биография', 'Драма', 'История'],
      countries: ['США', 'Великобритания'],
      year: 2023,
      director: 'Кристофер Нолан',
      actors: 'Киллиан Мёрфи, Эмили Блант, Мэтт Дэймон, Роберт Дауни мл.',
      description:
          'История жизни американского физика-теоретика Роберта Оппенгеймера, руководителя Манхэттенского проекта по созданию атомной бомбы.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4774061/99b61d4b-ae3a-4e67-930d-2b47f45c26ef/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4774061/99b61d4b-ae3a-4e67-930d-2b47f45c26ef/orig',
      rating: 8.5,
      ratingImdb: 8.9,
      filmLength: 180,
    ),
  ];

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
    _hideSearchOverlay();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val.trim();
    });
    if (_searchQuery.isNotEmpty) {
      _blurTimer?.cancel();
      _showSearchOverlay();
    } else {
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
    _hideSearchOverlay();
    final overlayState = Overlay.of(context, rootOverlay: true);
    _overlayEntry = OverlayEntry(
      builder: (ctx) => Positioned(
        width: 440,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(-40, 48),
          child: Material(
            color: Colors.transparent,
            child: _buildSearchDropdown(),
          ),
        ),
      ),
    );
    overlayState.insert(_overlayEntry!);
  }

  void _hideSearchOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSearchDropdown() {
    final q = _searchQuery.toLowerCase();
    final results = _searchCatalog.where((item) {
      return item.title.toLowerCase().contains(q) ||
          (item.nameOriginal?.toLowerCase().contains(q) ?? false) ||
          item.genres.any((g) => g.toLowerCase().contains(q)) ||
          item.year.toString().contains(q);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16162A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1E1E34),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 16, color: Color(0xFF9F67FF)),
                const SizedBox(width: 8),
                Text(
                  'Результаты поиска: «$_searchQuery»',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${results.length} найдено',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'Ничего не найдено по запросу «$_searchQuery»',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: results.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Colors.white10),
                itemBuilder: (context, i) {
                  final movie = results[i];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      hoverColor: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                      onTap: () => _onMovieSelected(movie),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                CatalogItem.fixPosterUrl(movie.posterUrl, kpId: movie.kinopoiskId),
                                width: 38,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 38,
                                  height: 52,
                                  color: const Color(0xFF7C3AED),
                                  child: const Icon(Icons.movie_rounded,
                                      size: 20, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movie.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${movie.year} • ${movie.genres.take(2).join(', ')}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '★ ${movie.rating.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Material(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
            child: InkWell(
              onTap: () {
                _blurTimer?.cancel();
                _hideSearchOverlay();
                _searchFocus.unfocus();
                context.go('/library?q=${Uri.encodeComponent(_searchQuery)}');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: const Text(
                  'Искать по всему каталогу в библиотеке →',
                  style: TextStyle(
                    color: Color(0xFFC084FC),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onSubmitted(String q) {
    _blurTimer?.cancel();
    _hideSearchOverlay();
    _searchFocus.unfocus();
    if (q.trim().isEmpty) return;
    final query = q.trim().toLowerCase();
    final match = _searchCatalog.where((item) =>
        item.title.toLowerCase().contains(query) ||
        (item.nameOriginal?.toLowerCase().contains(query) ?? false)).firstOrNull;
    if (match != null) {
      _onMovieSelected(match);
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

    final currentRoute = widget.activeRoute ?? '';

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A).withValues(alpha: 0.98),
        border: const Border(bottom: BorderSide(color: Colors.white12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Logo & Brand
          InkWell(
            onTap: () => context.go('/home'),
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
                const SizedBox(width: 10),
                const Text(
                  'CineTrack',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 28),

          // Main Navigation Links
          Row(
            children: [
              _buildNavLink(
                label: 'Главная',
                isSelected: currentRoute == '/home' || currentRoute == '/',
                onTap: () => context.go('/home'),
              ),
              const SizedBox(width: 18),
              _buildNavLink(
                label: 'Фильмы',
                isSelected: currentRoute == '/library',
                onTap: () => context.go('/library'),
              ),
              const SizedBox(width: 18),
              _buildNavLink(
                label: 'Комнаты 🍿',
                badgeCount: liveRoomsCount > 0 ? liveRoomsCount : null,
                isSelected: currentRoute.startsWith('/rooms'),
                onTap: () => context.go('/rooms'),
              ),
              const SizedBox(width: 18),
              _buildNavLink(
                label: 'Моя коллекция',
                isSelected: currentRoute.startsWith('/profile'),
                onTap: () => context.go('/profile'),
              ),
            ],
          ),
          const Spacer(),

          // Search Field with Live Dropdown Anchor (Enlarged)
          CompositedTransformTarget(
            link: _layerLink,
            child: SizedBox(
              width: 360,
              height: 42,
              child: TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                onChanged: _onSearchChanged,
                onSubmitted: _onSubmitted,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFF1B1B2F),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  hintText: 'Поиск фильмов, сериалов, аниме...',
                  hintStyle:
                      const TextStyle(fontSize: 12, color: Colors.white38),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: Colors.white54),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded,
                              size: 16, color: Colors.white54),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearchChanged('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // User Profile Pill (Avatar + Display Name)
          InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B2F),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isAdmin
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                      : Colors.white12,
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
                      style: const TextStyle(
                        color: Colors.white,
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
          ),
        ],
      ),
    );
  }

  Widget _buildNavLink({
    required String label,
    required bool isSelected,
    int? badgeCount,
    bool isSpecialAdmin = false,
    required VoidCallback onTap,
  }) {
    Color textColor = isSelected ? Colors.white : Colors.white60;
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
