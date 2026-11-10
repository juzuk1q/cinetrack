// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/curated_catalog.dart';
import '../../models/catalog_item.dart';
import '../../models/media_item.dart';
import '../../models/watch_room.dart';
import '../../providers/auth_provider.dart';
import '../../providers/media_provider.dart';
import '../../providers/room_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/top_notification.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const int _kInitialVirtualHeroPage = 5000;
  late final PageController _heroPageCtrl;
  int _currentHeroIndex = 0;
  Timer? _heroTimer;
  final Set<int> _savedHeroKpIds = {};

  @override
  void initState() {
    super.initState();
    final initialPage =
        _kInitialVirtualHeroPage - (_kInitialVirtualHeroPage % heroSlides.length);
    _heroPageCtrl = PageController(initialPage: initialPage);
    _heroTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || !_heroPageCtrl.hasClients) return;
      _heroPageCtrl.nextPage(
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroPageCtrl.dispose();
    super.dispose();
  }

  // 5 Top Curated Slides for the Dynamic Hero Banner (Interstellar, Tokyo Ghoul, Raya, The Gentlemen, 1+1)
  static final List<CatalogItem> heroSlides = [
    const CatalogItem(
      kinopoiskId: 258687,
      title: 'Интерстеллар',
      nameOriginal: 'Interstellar',
      type: 'movie',
      typeLabel: 'Paramount / Sci-Fi',
      genres: ['Фантастика', 'Драма', 'Приключения'],
      year: 2014,
      director: 'Кристофер Нолан',
      actors: 'Мэттью Макконахи, Энн Хэтэуэй, Джессика Честейн',
      description:
          'Когда засуха, пыльные бури и вымирание растений приводят человечество к продовольственному кризису, коллектив ученых отправляется сквозь червоточину в поисках нового дома.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/430042eb-ee69-4818-aed0-a312400a26bf/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/430042eb-ee69-4818-aed0-a312400a26bf/x1000',
      rating: 8.7,
      ratingImdb: 8.7,
      filmLength: 169,
      slogan: 'Следующий шаг человечества станет величайшим',
    ),
    const CatalogItem(
      kinopoiskId: 841681,
      title: 'Токийский гуль',
      nameOriginal: 'Tokyo Ghoul',
      type: 'anime',
      typeLabel: 'Pierrot / Anime',
      genres: ['Аниме', 'Ужасы', 'Боевик', 'Фэнтези'],
      year: 2014,
      director: 'Сюхэй Морита',
      actors: 'Нацуки Ханаэ, Сора Амамия, Синтаро Асанума',
      description:
          'Студент Кэн Канэки после нападения чудовища попадает в больницу, где ему пересаживают органы гуля. Теперь он изгой в мире людей и обречен бороться за свою человечность.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/e5d98938-605a-4c8a-b0d6-5f93d926aa0c/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/e5d98938-605a-4c8a-b0d6-5f93d926aa0c/x1000',
      rating: 7.1,
      ratingImdb: 7.8,
      filmLength: 24,
      slogan: 'В мире монстров легко стать одним из них',
    ),
    const CatalogItem(
      kinopoiskId: 1015471,
      title: 'Райя и последний дракон',
      nameOriginal: 'Raya and the Last Dragon',
      type: 'cartoon',
      typeLabel: 'Disney Animation',
      genres: ['Мультфильм', 'Фэнтези', 'Боевик', 'Приключения'],
      year: 2021,
      director: 'Дон Холл, Карлос Лопес Эстрада',
      actors: 'Келли Мари Трэн, Аквафина, Джемма Чан, Дэниэл Дэ Ким',
      description:
          'Отважная воительница Райя отправляется на поиски последнего дракона Сису, чтобы объединить разрозненные народы Кумандры и победить древних демонов Друунов.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/84478174-8b68-450f-bc4d-5c683ee30248/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/84478174-8b68-450f-bc4d-5c683ee30248/x1000',
      rating: 8.2,
      ratingImdb: 8.3,
      filmLength: 107,
    ),
    const CatalogItem(
      kinopoiskId: 1143242,
      title: 'Джентльмены',
      nameOriginal: 'The Gentlemen',
      type: 'movie',
      typeLabel: 'Miramax / Guy Ritchie',
      genres: ['Криминал', 'Комедия', 'Боевик'],
      year: 2019,
      director: 'Гай Ричи',
      actors: 'Мэттью Макконахи, Чарли Ханнэм, Генри Голдинг, Хью Грант',
      description:
          'Талантливый выпускник Оксфорда придумал нелегальную схему обогащения. Но когда он решает продать бизнес, на его пути встают другие джентльмены криминального мира.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/637271d5-61b4-4e46-ac83-6d07494c7645/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/637271d5-61b4-4e46-ac83-6d07494c7645/x1000',
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
      typeLabel: 'Gaumont / Masterpiece',
      genres: ['Драма', 'Комедия', 'Биография'],
      year: 2011,
      director: 'Оливье Накаш, Эрик Толедано',
      actors: 'Франсуа Клюзе, Омар Си, Анн Ле Ни, Одри Флеро',
      description:
          'Богатый аристократ Филипп, прикованный к инвалидному креслу, нанимает в сиделки бывшего заключенного Дрисса, возвращающего ему вкус к жизни.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10900341/caf9f155-1a19-42f1-a0f3-9c8773e9083e/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10900341/caf9f155-1a19-42f1-a0f3-9c8773e9083e/x1000',
      rating: 8.9,
      ratingImdb: 8.5,
      filmLength: 112,
      slogan: 'Иногда нужно заглянуть в чужой мир, чтобы узнать, чего не хватает в твоем',
    ),
  ];

  // Curated Popular Movies (Russian tags & reliable Yandex CDN posters)
  static final List<Map<String, dynamic>> featuredMovies = [
    {
      'isWide': true,
      'title': 'Интерстеллар',
      'originalTitle': 'Interstellar',
      'meta': '16+ • 2 ч 49 мин • Фантастика, Драма',
      'year': 2014,
      'rating': 8.7,
      'mpa': '16+',
      'genres': 'Фантастика, Драма, Приключения',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/430042eb-ee69-4818-aed0-a312400a26bf/x1000',
      'kpId': 258687,
    },
    {
      'isWide': false,
      'title': 'Джентльмены',
      'originalTitle': 'The Gentlemen',
      'meta': '18+ • 1 ч 53 мин • Боевик, Криминал',
      'year': 2019,
      'rating': 8.7,
      'mpa': '18+',
      'genres': 'Боевик, Криминал, Комедия',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/637271d5-61b4-4e46-ac83-6d07494c7645/x1000',
      'kpId': 1143242,
    },
    {
      'isWide': false,
      'title': '1+1',
      'originalTitle': 'Intouchables',
      'meta': '16+ • 1 ч 52 мин • Драма, Комедия',
      'year': 2011,
      'rating': 8.9,
      'mpa': '16+',
      'genres': 'Драма, Комедия, Биография',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10900341/caf9f155-1a19-42f1-a0f3-9c8773e9083e/x1000',
      'kpId': 535341,
    },
    {
      'isWide': false,
      'title': 'Остров проклятых',
      'originalTitle': 'Shutter Island',
      'meta': '18+ • 2 ч 18 мин • Детектив, Триллер',
      'year': 2009,
      'rating': 8.6,
      'mpa': '18+',
      'genres': 'Детектив, Триллер, Драма',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4303601/617303b7-cfa7-4273-bd1d-63974bf68927/x1000',
      'kpId': 397667,
    },
    {
      'isWide': false,
      'title': 'Побег из Шоушенка',
      'originalTitle': 'The Shawshank Redemption',
      'meta': '16+ • 2 ч 22 мин • Драма',
      'year': 1994,
      'rating': 9.1,
      'mpa': '16+',
      'genres': 'Драма, Криминал',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/0b76b2a2-d1c7-4f04-a284-80ff7bb709a4/x1000',
      'kpId': 326,
    },
    {
      'isWide': false,
      'title': 'Бойцовский клуб',
      'originalTitle': 'Fight Club',
      'meta': '18+ • 2 ч 19 мин • Триллер, Драма',
      'year': 1999,
      'rating': 8.7,
      'mpa': '18+',
      'genres': 'Триллер, Драма, Криминал',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/16490236/495fb59a-bff1-4626-baba-bb392fede945/x1000',
      'kpId': 361,
    },
    {
      'isWide': false,
      'title': 'Оппенгеймер',
      'originalTitle': 'Oppenheimer',
      'meta': '18+ • 3 ч 00 мин • Биография, Драма',
      'year': 2023,
      'rating': 8.5,
      'mpa': '18+',
      'genres': 'Биография, Драма, История',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4486454/c5292109-642c-4ab0-894a-cc304e1bcec4/x1000',
      'kpId': 4664634,
    },
    {
      'isWide': false,
      'title': 'Матрица',
      'originalTitle': 'The Matrix',
      'meta': '16+ • 2 ч 16 мин • Фантастика, Боевик',
      'year': 1999,
      'rating': 8.5,
      'mpa': '16+',
      'genres': 'Фантастика, Боевик',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4774061/cf1970bc-3f08-4e0e-a095-2fb57c3aa7c6/x1000',
      'kpId': 301,
    },
    {
      'isWide': false,
      'title': 'Тёмный рыцарь',
      'originalTitle': 'The Dark Knight',
      'meta': '16+ • 2 ч 32 мин • Боевик, Триллер',
      'year': 2008,
      'rating': 8.5,
      'mpa': '16+',
      'genres': 'Боевик, Триллер, Драма',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/0fa5bf50-d5ad-446f-a599-b26d070c8b99/x1000',
      'kpId': 111543,
    },
    {
      'isWide': false,
      'title': 'Гладиатор',
      'originalTitle': 'Gladiator',
      'meta': '18+ • 2 ч 35 мин • Драма, Приключения',
      'year': 2000,
      'rating': 8.6,
      'mpa': '18+',
      'genres': 'Драма, Приключения, Боевик',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10812607/ad4932b4-c220-48a5-9a37-40fc72da5ffa/x1000',
      'kpId': 474,
    },
    {
      'isWide': false,
      'title': 'Леон',
      'originalTitle': 'Léon',
      'meta': '18+ • 1 ч 50 мин • Боевик, Драма',
      'year': 1994,
      'rating': 8.7,
      'mpa': '18+',
      'genres': 'Боевик, Драма, Криминал',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/6201401/8662d92a-5881-4600-a7ae-549e6fd53b03/x1000',
      'kpId': 389,
    },
    {
      'isWide': false,
      'title': 'Криминальное чтиво',
      'originalTitle': 'Pulp Fiction',
      'meta': '18+ • 2 ч 34 мин • Криминал, Комедия',
      'year': 1994,
      'rating': 8.6,
      'mpa': '18+',
      'genres': 'Криминал, Комедия, Драма',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4716873/0a07a903-9025-4aff-bf7c-46bbb175888c/x1000',
      'kpId': 342,
    },
    {
      'isWide': false,
      'title': 'Зеленая миля',
      'originalTitle': 'The Green Mile',
      'meta': '16+ • 3 ч 09 мин • Драма, Фэнтези',
      'year': 1999,
      'rating': 9.1,
      'mpa': '16+',
      'genres': 'Драма, Фэнтези, Криминал',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/4057c4b8-8208-4a04-b169-26b0661453e3/x1000',
      'kpId': 435,
    },
    {
      'isWide': false,
      'title': 'Дюна: Часть вторая',
      'originalTitle': 'Dune: Part Two',
      'meta': '16+ • 2 ч 46 мин • Фантастика, Приключения',
      'year': 2024,
      'rating': 8.5,
      'mpa': '16+',
      'genres': 'Фантастика, Боевик, Приключения',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/6201401/90d57813-387c-44c4-81c1-ecddb3c417a5/x1000',
      'kpId': 1318972,
    },
  ];

  // Curated Popular Series & Anime (reliable Yandex CDN posters)
  static final List<Map<String, dynamic>> featuredSeries = [
    {
      'title': 'Токийский гуль',
      'originalTitle': 'Tokyo Ghoul',
      'meta': '18+ • 4 Сезона • Аниме, Ужасы',
      'year': 2014,
      'rating': 7.1,
      'mpa': '18+',
      'genres': 'Аниме, Ужасы, Боевик, Фэнтези',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/e5d98938-605a-4c8a-b0d6-5f93d926aa0c/x1000',
      'kpId': 841681,
    },
    {
      'title': 'Аркейн',
      'originalTitle': 'Arcane: League of Legends',
      'meta': '16+ • 2 Сезона • Анимация, Фэнтези',
      'year': 2021,
      'rating': 8.8,
      'mpa': '16+',
      'genres': 'Анимация, Фэнтези',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4303601/60334800-4b52-4467-b50a-e866657c9172/orig',
      'kpId': 1318854,
    },
    {
      'title': 'Тетрадь смерти',
      'originalTitle': 'Death Note',
      'meta': '16+ • 37 Серий • Аниме, Триллер',
      'year': 2006,
      'rating': 8.6,
      'mpa': '16+',
      'genres': 'Аниме, Триллер',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1946459/0368a21d-64dd-4340-b097-205dc9512ba4/x1000',
      'kpId': 406148,
    },
    {
      'title': 'Атака титанов',
      'originalTitle': 'Attack on Titan',
      'meta': '18+ • 4 Сезона • Аниме, Боевик',
      'year': 2013,
      'rating': 8.7,
      'mpa': '18+',
      'genres': 'Аниме, Боевик, Драма',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/6201401/e42e60bc-0772-4a3a-a24f-4218febf9386/x1000',
      'kpId': 749374,
    },
    {
      'title': 'Во все тяжкие',
      'originalTitle': 'Breaking Bad',
      'meta': '18+ • 5 Сезонов • Криминал, Драма',
      'year': 2008,
      'rating': 9.5,
      'mpa': '18+',
      'genres': 'Криминал, Драма',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/fb35416f-3b0d-4b96-bc65-cf6923f9e329/x1000',
      'kpId': 404900,
    },
    {
      'title': 'Очень странные дела',
      'originalTitle': 'Stranger Things',
      'meta': '16+ • 4 Сезона • Фантастика, Ужасы',
      'year': 2016,
      'rating': 8.4,
      'mpa': '16+',
      'genres': 'Фантастика, Ужасы',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10703859/1e653cad-c84f-4617-b61e-949b3228ef36/x1000',
      'kpId': 915196,
    },
    {
      'title': 'Игра престолов',
      'originalTitle': 'Game of Thrones',
      'meta': '18+ • 8 Сезонов • Фэнтези, Драма',
      'year': 2011,
      'rating': 9.0,
      'mpa': '18+',
      'genres': 'Фэнтези, Драма, Приключения',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/dd78edfd-6a1f-486c-9a86-6acbca940418/x1000',
      'kpId': 464963,
    },
    {
      'title': 'Шерлок',
      'originalTitle': 'Sherlock',
      'meta': '16+ • 4 Сезона • Детектив, Триллер',
      'year': 2010,
      'rating': 8.9,
      'mpa': '16+',
      'genres': 'Детектив, Триллер, Драма',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1629390/f28c1ea2-47b0-49d5-b11c-9608744f0233/x1000',
      'kpId': 502838,
    },
    {
      'title': 'Клинок, рассекающий демонов',
      'originalTitle': 'Kimetsu no Yaiba',
      'meta': '16+ • 4 Сезона • Аниме, Фэнтези',
      'year': 2019,
      'rating': 8.3,
      'mpa': '16+',
      'genres': 'Аниме, Фэнтези, Боевик',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10671298/32621935-61a6-4479-ae42-829f5642e6b0/x1000',
      'kpId': 1220920,
    },
    {
      'title': 'Настоящий детектив',
      'originalTitle': 'True Detective',
      'meta': '18+ • 4 Сезона • Детектив, Триллер',
      'year': 2014,
      'rating': 8.7,
      'mpa': '18+',
      'genres': 'Детектив, Криминал, Драма',
      'posterUrl':
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10835644/73941f07-7652-4943-83e1-7849aa398974/x1000',
      'kpId': 681831,
    },
  ];

  static CatalogItem _toCatalogItem(Map<String, dynamic> m) {
    final title = m['title'] as String;
    final kpId = m['kpId'] as int?;

    // Match against rich CuratedCatalog if present
    final curated = CuratedCatalog.items.where((c) {
      if (kpId != null && c.kinopoiskId != null && c.kinopoiskId == kpId) {
        return true;
      }
      final t = c.title.toLowerCase().trim();
      final targetT = title.toLowerCase().trim();
      return t == targetT || targetT.contains(t) || t.contains(targetT);
    }).firstOrNull;
    if (curated != null) {
      return curated;
    }

    final posterUrl = m['posterUrl'] as String;
    final year = (m['year'] as num?)?.toInt() ?? 2024;
    final rating = (m['rating'] as num?)?.toDouble() ?? 8.5;
    final genresStr = (m['genres'] as String?) ?? 'Кино';
    final genresList = genresStr.split(',').map((s) => s.trim()).toList();
    final isSeries = m['meta']?.toString().contains('Сезон') == true ||
        m['meta']?.toString().contains('Сери') == true;

    return CatalogItem(
      kinopoiskId: kpId,
      title: title,
      nameOriginal: m['originalTitle'] as String?,
      type: isSeries ? 'series' : 'movie',
      typeLabel: isSeries ? 'Сериал' : 'Фильм',
      genres: genresList,
      year: year,
      director: genresList.firstOrNull ?? 'Режиссер',
      actors: '',
      description: 'Популярное произведение мирового кинематографа.',
      posterUrl: posterUrl,
      coverUrl: posterUrl,
      rating: rating,
    );
  }

  Future<void> _toggleSlideCollection(CatalogItem item) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      context.go('/login');
      return;
    }

    final now = DateTime.now();
    final mediaItem = MediaItem(
      id: '',
      userId: user.id,
      title: item.title,
      type: item.type,
      genres: item.genres,
      year: item.year,
      director: item.director,
      actors: item.actors,
      description: item.description,
      posterUrl: item.posterUrl,
      status: 'want_to_watch',
      createdAt: now,
      updatedAt: now,
    );

    try {
      await ref.read(mediaNotifierProvider.notifier).create(mediaItem);
      ref.invalidate(mediaListProvider);
      ref.invalidate(statsDataProvider);

      if (item.kinopoiskId != null) {
        setState(() => _savedHeroKpIds.add(item.kinopoiskId!));
      }
      if (!mounted) return;
      TopNotification.showSuccess(
        context,
        '«${item.title}» добавлен в вашу коллекцию! ⭐',
        title: 'Коллекция',
      );
    } catch (_) {}
  }

  void _startSlideSoloWatch(CatalogItem item) {
    final uri = Uri(
      path: '/watch',
      queryParameters: {
        'title': item.title,
        'year': item.year.toString(),
        if (item.kinopoiskId != null) 'kpId': item.kinopoiskId.toString(),
        'poster': item.posterUrl,
        'type': item.type,
        'desc': item.description,
        'genres': item.genres.join(', '),
      },
    );
    context.go(uri.toString());
  }

  void _startSlidePartyWatch(CatalogItem item) {
    final user = ref.read(currentUserProvider);
    final ownerName = user?.email?.split('@').first ?? 'Организатор';
    final ownerId = user?.id ?? 'host';

    final room = ref.read(roomsProvider.notifier).createRoom(
          title: 'Совместный сеанс: ${item.title} 🍿',
          movieTitle: item.title,
          movieType: item.type,
          moviePoster: item.posterUrl,
          movieYear: item.year,
          kinopoiskId: item.kinopoiskId,
          scheduledAt: DateTime.now(),
          ownerName: ownerName,
          ownerId: ownerId,
        );

    TopNotification.showSuccess(
      context,
      'Комната создана! Подключаемся...',
      title: 'Комната совместного просмотра 🍿',
    );
    context.go('/rooms/${room.id}');
  }

  void _openTrailerModal(BuildContext context, CatalogItem item) {
    final kpId = item.kinopoiskId ?? 258687;
    final viewId = 'cinetrack-hero-trailer-$kpId-${DateTime.now().millisecondsSinceEpoch}';
    final trailerUrl = 'https://api.delivembd.ws/embed/trailer-kp/$kpId';

    final iframe = html.IFrameElement()
      ..src = trailerUrl
      ..referrerPolicy = 'strict-origin-when-cross-origin'
      ..setAttribute('referrerpolicy', 'strict-origin-when-cross-origin')
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#0A0A14'
      ..allow = 'autoplay; fullscreen; encrypted-media; picture-in-picture; web-share';

    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) => iframe,
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          width: 960,
          height: 560,
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                blurRadius: 36,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                color: const Color(0xFF16162A),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_fill_rounded,
                        color: Color(0xFF9F67FF), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Официальный трейлер: ${item.title} (${item.year})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          fontSize: 14.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                      tooltip: 'Закрыть',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: HtmlElementView(viewType: viewId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rooms = ref.watch(roomsProvider);
    final liveRooms = rooms.where((r) => r.status == 'watching').toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF1F5F9),
      body: CustomScrollView(
        slivers: [
          // 1. Top Modern Streaming Nav Bar with Live Interactive Search
          const SliverToBoxAdapter(
            child: AppHeader(activeRoute: '/home'),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 36),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Cinematic Hero Banner
                _buildCinematicHeroBanner(context),
                const SizedBox(height: 30),

                // 2. Movies Section
                _buildSectionTitle(
                  title: 'Фильмы',
                  subtitle: 'Популярные блокбастеры и новинки проката',
                  icon: Icons.local_movies_rounded,
                  accentColor: const Color(0xFF7C3AED),
                  actionLabel: 'Каталог фильмов >',
                  onAction: () => context.go('/library'),
                ),
                const SizedBox(height: 14),
                _buildMoviesHorizontalRow(context, featuredMovies),
                const SizedBox(height: 32),

                // 3. TV Shows & Anime Section
                _buildSectionTitle(
                  title: 'Сериалы и Аниме',
                  subtitle: 'Эпизодические шоу, дорамы и популярные аниме-тайтлы',
                  icon: Icons.video_collection_rounded,
                  accentColor: const Color(0xFF6366F1),
                  actionLabel: 'Каталог сериалов >',
                  onAction: () => context.go('/library'),
                ),
                const SizedBox(height: 14),
                _buildSeriesHorizontalRow(context, featuredSeries),
                const SizedBox(height: 32),

                // 4. Active Watch Rooms (At the very bottom)
                _buildSectionTitle(
                  title: 'Комнаты совместного просмотра',
                  subtitle: 'Подключайтесь к синхронному показу с живым чатом',
                  icon: Icons.live_tv_rounded,
                  accentColor: const Color(0xFF10B981),
                  badgeText: '${liveRooms.length} активных',
                  actionLabel: 'Все комнаты (${rooms.length})',
                  onAction: () => context.go('/rooms'),
                ),
                const SizedBox(height: 14),
                if (liveRooms.isEmpty)
                  _buildEmptyRoomCard(context)
                else
                  _buildLiveRoomsCarousel(context, liveRooms),
                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Cinematic Hero Banner (Dynamic Carousel with Auto-Rotation & Trailer Playback)
  Widget _buildCinematicHeroBanner(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.08),
            blurRadius: isDark ? 32 : 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Sliding Pages (Infinite Carousel)
          PageView.builder(
            controller: _heroPageCtrl,
            onPageChanged: (idx) {
              setState(() => _currentHeroIndex = idx % heroSlides.length);
            },
            itemBuilder: (context, idx) {
              final slide = heroSlides[idx % heroSlides.length];
              return _buildHeroSlide(context, slide, isDark);
            },
          ),

          // 2. Left Chevron Button
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: InkWell(
                onTap: () {
                  if (!_heroPageCtrl.hasClients) return;
                  _heroPageCtrl.previousPage(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeInOutCubic,
                  );
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // 3. Right Chevron Button
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: InkWell(
                onTap: () {
                  if (!_heroPageCtrl.hasClients) return;
                  _heroPageCtrl.nextPage(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeInOutCubic,
                  );
                },
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),

          // 4. Dot Indicators at Bottom
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(heroSlides.length, (idx) {
                final isActive = idx == _currentHeroIndex;
                return InkWell(
                  onTap: () {
                    if (!_heroPageCtrl.hasClients) return;
                    final currentPage =
                        _heroPageCtrl.page?.round() ?? _kInitialVirtualHeroPage;
                    final currentModulo = currentPage % heroSlides.length;
                    final diff = idx - currentModulo;
                    _heroPageCtrl.animateToPage(
                      currentPage + diff,
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeInOutCubic,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 30 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF7C3AED)
                          : (isDark ? Colors.white24 : Colors.black26),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSlide(BuildContext context, CatalogItem slide, bool isDark) {
    final isSaved = slide.kinopoiskId != null && _savedHeroKpIds.contains(slide.kinopoiskId);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Backdrop cover
        Image.network(
          CatalogItem.fixPosterUrl(slide.coverUrl ?? slide.posterUrl, kpId: slide.kinopoiskId),
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? const [Color(0xFF261042), Color(0xFF14203B), Color(0xFF0F172A)]
                    : const [Color(0xFFEDE9FE), Color(0xFFE0E7FF), Color(0xFFF1F5F9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),

        // Gradient Left overlay: in Dark it is deep dark, in Light it is pristine white glass!
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: isDark
                    ? const [
                        Color(0xFF0F0F1A),
                        Color(0xF00F0F1A),
                        Color(0x880F0F1A),
                        Color(0x330F0F1A),
                      ]
                    : const [
                        Color(0xFFFFFFFF),
                        Color(0xF5FFFFFF),
                        Color(0xCCFFFFFF),
                        Color(0x22FFFFFF),
                      ],
                stops: const [0.0, 0.45, 0.75, 1.0],
              ),
            ),
          ),
        ),
        // Gradient Bottom overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isDark
                    ? [
                        const Color(0xFF0F0F1A).withValues(alpha: 0.95),
                        Colors.transparent,
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.transparent,
                      ],
                stops: const [0.0, 0.4],
              ),
            ),
          ),
        ),

        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(54, 32, 54, 36),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 880;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left Details Column
                  Expanded(
                    flex: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Studio / Origin Tag & Trend Badge
                        Row(
                          children: [
                            if (slide.typeLabel != null && slide.typeLabel!.isNotEmpty) ...[
                              Text(
                                slide.typeLabel!,
                                style: const TextStyle(
                                  color: Color(0xFF0284C7),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED).withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF7C3AED), width: 0.8),
                              ),
                              child: const Text(
                                '★ В ТРЕНДЕ',
                                style: TextStyle(
                                  color: Color(0xFF7C3AED),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Title
                        Text(
                          slide.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                            letterSpacing: 1.1,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (slide.slogan != null && slide.slogan!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '«${slide.slogan}»',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Genre Pills
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: slide.genres.take(4).map((g) => _buildHeroGenreChip(g, isDark)).toList(),
                        ),
                        const SizedBox(height: 12),

                        // Ratings & Accolades
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              '98% совпадение',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text('•', style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFFD1D5DB))),
                            Text(
                              '${slide.year}',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text('•', style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFFD1D5DB))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white12 : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(4),
                                border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Text(
                                slide.effectiveMpa,
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text('•', style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFFD1D5DB))),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 15, color: Color(0xFFFFCA28)),
                                const SizedBox(width: 3),
                                Text(
                                  '${slide.rating.toStringAsFixed(1)} (КП)',
                                  style: TextStyle(
                                    color: isDark ? Colors.white : const Color(0xFF111827),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (slide.ratingImdb != null) ...[
                              Text('•', style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFFD1D5DB))),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${slide.ratingImdb!.toStringAsFixed(1)} (IMDb)',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF111827),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Description
                        Text(
                          slide.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF374151),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons: [ ▶ Смотреть онлайн ] [ 🍿 С друзьями ] [ 🎬 Трейлер ] [ 🔖 В избранное ] [ ℹ️ О фильме ]
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // 1. Solo Watch
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                elevation: 4,
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                              label: const Text(
                                'Смотреть онлайн',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              onPressed: () => _startSlideSoloWatch(slide),
                            ),

                            // 2. Co-watch Party
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? const Color(0xFF6D28D9) : const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                elevation: 3,
                              ),
                              icon: const Icon(Icons.groups_rounded, size: 17),
                              label: const Text(
                                'Смотреть с друзьями 🍿',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              onPressed: () => _startSlidePartyWatch(slide),
                            ),

                            // 3. Play Trailer Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.2 : 0.12),
                                foregroundColor: const Color(0xFFD97706),
                                side: BorderSide(color: isDark ? const Color(0xFFFFCA28) : const Color(0xFFF59E0B), width: 1.2),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              icon: const Icon(Icons.movie_filter_rounded, size: 17, color: Color(0xFFD97706)),
                              label: const Text(
                                'Трейлер ▶',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                              ),
                              onPressed: () => _openTrailerModal(context, slide),
                            ),

                            // 4. Bookmark
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isSaved
                                    ? const Color(0xFF10B981)
                                    : (isDark ? Colors.white12 : const Color(0xFFF3F4F6)),
                                foregroundColor: isSaved ? Colors.white : (isDark ? Colors.white : const Color(0xFF1F2937)),
                                side: BorderSide(
                                  color: isSaved
                                      ? Colors.transparent
                                      : (isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                elevation: 0,
                              ),
                              icon: Icon(
                                isSaved ? Icons.bookmark_added_rounded : Icons.bookmark_add_rounded,
                                size: 17,
                                color: isSaved ? Colors.white : (isDark ? Colors.white : const Color(0xFF1F2937)),
                              ),
                              label: Text(
                                isSaved ? 'В коллекции' : 'В коллекцию',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSaved ? Colors.white : (isDark ? Colors.white : const Color(0xFF1F2937)),
                                ),
                              ),
                              onPressed: () => _toggleSlideCollection(slide),
                            ),

                            // 5. Details
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              icon: Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                              ),
                              label: Text(
                                'О фильме',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                ),
                              ),
                              onPressed: () => context.push(
                                '/movie/${slide.kinopoiskId ?? slide.title}',
                                extra: slide,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Right 3D Floating Poster Card with Trailer Overlay (fills the empty space)
                  if (isWide) ...[
                    const SizedBox(width: 32),
                    Expanded(
                      flex: 4,
                      child: Center(
                        child: InkWell(
                          onTap: () => _openTrailerModal(context, slide),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 220,
                            height: 310,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.6), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                                  blurRadius: 28,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  blurRadius: 20,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  CatalogItem.fixPosterUrl(slide.posterUrl, kpId: slide.kinopoiskId),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: const Color(0xFF1E2230),
                                    child: const Center(
                                      child: Icon(Icons.movie_rounded, color: Colors.white24, size: 48),
                                    ),
                                  ),
                                ),
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Color(0x99000000),
                                        Color(0xEE0B0B14),
                                      ],
                                      stops: [0.4, 0.75, 1.0],
                                    ),
                                  ),
                                ),

                                // Top Rating Badge
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFFCA28), width: 0.8),
                                    ),
                                    child: Text(
                                      '★ ${slide.rating.toStringAsFixed(1)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFFCA28),
                                      ),
                                    ),
                                  ),
                                ),

                                // Big Center Play Trailer Button
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED).withValues(alpha: 0.85),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF7C3AED).withValues(alpha: 0.6),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                                  ),
                                ),

                                // Bottom Trailer Label
                                Positioned(
                                  bottom: 12,
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.75),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.movie_filter_rounded, size: 14, color: Color(0xFFFFCA28)),
                                        SizedBox(width: 6),
                                        Text(
                                          'Смотреть трейлер',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeroGenreChip(String label, [bool isDark = true]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.5)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF334155),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Section Header
  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    String? badgeText,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accentColor, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  if (badgeText != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  // 4. Movies Horizontal Row (Replicating the exact cards from mockup)
  Widget _buildMoviesHorizontalRow(BuildContext context, List<Map<String, dynamic>> items) {
    return SizedBox(
      height: 175,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final m = items[i];
          final isWide = m['isWide'] as bool? ?? false;
          final title = m['title'] as String;
          final meta = m['meta'] as String;
          final posterUrl = m['posterUrl'] as String;
          final kpId = m['kpId'] as int?;
          final rating = (m['rating'] as num?)?.toDouble() ?? 7.5;

          if (isWide) {
            // First featured wide card: Interstellar
            return InkWell(
              onTap: () => context.push(
                '/movie/${kpId ?? title}',
                extra: _toCatalogItem(m),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 270,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        CatalogItem.fixPosterUrl(posterUrl, kpId: kpId),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1E2230),
                          child: const Center(
                            child: Icon(Icons.movie_outlined, color: Colors.white24, size: 36),
                          ),
                        ),
                      ),
                    ),
                    // Gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                            stops: [0.3, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // White Circular Play Button
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black45, blurRadius: 10),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 22),
                      ),
                    ),

                    // Title & Meta info
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 70,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Vertical Poster Card (The Gentlemen, 1+1, Shutter Island, etc.)
            return InkWell(
              onTap: () => context.push(
                '/movie/${kpId ?? title}',
                extra: _toCatalogItem(m),
              ),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 122,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        CatalogItem.fixPosterUrl(posterUrl, kpId: kpId),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1E2230),
                          child: const Center(
                            child: Icon(Icons.movie_outlined, color: Colors.white24, size: 30),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                            stops: [0.5, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Top Rating Badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFFCA28), width: 0.8),
                        ),
                        child: Text(
                          '★ ${rating.toStringAsFixed(1)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFFCA28),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Title
                    Positioned(
                      bottom: 10,
                      left: 10,
                      right: 10,
                      child: Text(
                        title,
                        maxLines: 2,
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
          }
        },
      ),
    );
  }

  // 5. Series & Anime Horizontal Row
  Widget _buildSeriesHorizontalRow(BuildContext context, List<Map<String, dynamic>> items) {
    return SizedBox(
      height: 175,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final s = items[i];
          final title = s['title'] as String;
          final posterUrl = s['posterUrl'] as String;
          final kpId = s['kpId'] as int?;
          final rating = (s['rating'] as num?)?.toDouble() ?? 8.5;
          final meta = s['meta'] as String;

          return InkWell(
            onTap: () => context.push(
              '/movie/${kpId ?? title}',
              extra: _toCatalogItem(s),
            ),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 122,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.network(
                      CatalogItem.fixPosterUrl(posterUrl, kpId: kpId),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1E2230),
                        child: const Center(
                          child: Icon(Icons.tv_outlined, color: Colors.white24, size: 30),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                          stops: [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Format Chip
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('СЕРИАЛ',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ),

                  // Top Rating Badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFFFCA28), width: 0.8),
                      ),
                      child: Text(
                        '★ ${rating.toStringAsFixed(1)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFFFCA28),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Title & Episodes
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9.5, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Active watch party rooms carousel
  Widget _buildLiveRoomsCarousel(BuildContext context, List<WatchRoom> rooms) {
    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: rooms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final room = rooms[i];
          return Container(
            width: 360,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16162A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              children: [
                if (room.moviePoster != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      room.moviePoster!,
                      width: 62,
                      height: 104,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 62,
                        height: 104,
                        color: Colors.white10,
                        child: const Icon(Icons.movie_rounded, size: 24),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_rounded, size: 9, color: Color(0xFF9F67FF)),
                            const SizedBox(width: 4),
                            Text(
                              room.ownerName,
                              style: const TextStyle(
                                color: Color(0xFF9F67FF),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        room.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      Text(
                        'Видео: ${room.movieTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 34,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, size: 16),
                          label: const Text(
                            'Войти в комнату',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () => context.go('/rooms/${room.id}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyRoomCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16162A) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.tv_off_rounded, size: 36, color: Colors.white24),
            const SizedBox(height: 10),
            const Text(
              'Сейчас никто не смотрит фильмы',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Создать первую комнату'),
              onPressed: () => context.go('/rooms'),
            ),
          ],
        ),
      ),
    );
  }
}
