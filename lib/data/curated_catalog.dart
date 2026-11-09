import '../models/catalog_item.dart';

class CuratedCatalog {
  CuratedCatalog._();

  static const List<CatalogItem> items = [
    // ФИЛЬМЫ
    CatalogItem(
      kinopoiskId: 258687,
      title: 'Интерстеллар',
      nameOriginal: 'Interstellar',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Фантастика', 'Драма', 'Приключения'],
      year: 2014,
      director: 'Кристофер Нолан',
      actors: 'Мэттью Макконахи, Энн Хэтэуэй, Джессика Честейн',
      description:
          'Когда засуха, пыльные бури и вымирание растений приводят человечество к продовольственному кризису, коллектив исследователей отправляется сквозь червоточину в поисках нового дома.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/430042eb-ee69-4818-aed0-a312400a26bf/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/430042eb-ee69-4818-aed0-a312400a26bf/x1000',
      rating: 8.7,
      ratingImdb: 8.7,
      filmLength: 169,
      slogan: 'Следующий шаг человечества станет величайшим',
    ),
    CatalogItem(
      kinopoiskId: 1143242,
      title: 'Джентльмены',
      nameOriginal: 'The Gentlemen',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Боевик', 'Криминал', 'Комедия'],
      year: 2019,
      director: 'Гай Ричи',
      actors: 'Мэттью Макконахи, Чарли Ханнэм, Генри Голдинг, Хью Грант',
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
    ),
    CatalogItem(
      kinopoiskId: 535341,
      title: '1+1',
      nameOriginal: 'Intouchables',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Драма', 'Комедия', 'Биография'],
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
    ),
    CatalogItem(
      kinopoiskId: 397667,
      title: 'Остров проклятых',
      nameOriginal: 'Shutter Island',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Детектив', 'Триллер', 'Драма'],
      year: 2009,
      director: 'Мартин Скорсезе',
      actors: 'Леонардо ДиКаприо, Марк Руффало, Бен Кингсли',
      description:
          'Два судебных пристава отправляются на остров в Массачусетсе, чтобы расследовать исчезновение пациентки из клиники для умалишенных преступников.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4303601/617303b7-cfa7-4273-bd1d-63974bf68927/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4303601/617303b7-cfa7-4273-bd1d-63974bf68927/x1000',
      rating: 8.6,
      ratingImdb: 8.2,
      filmLength: 138,
      slogan: 'Некоторые места никогда не отпускают',
    ),
    CatalogItem(
      kinopoiskId: 326,
      title: 'Побег из Шоушенка',
      nameOriginal: 'The Shawshank Redemption',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Драма', 'Криминал'],
      year: 1994,
      director: 'Фрэнк Дарабонт',
      actors: 'Тим Роббинс, Морган Фриман, Боб Гантон',
      description:
          'Бухгалтер Энди Дюфрейн обвинён в убийстве собственной жены и её любовника. Оказавшись в тюрьме Шоушенк, он сталкивается с жестокостью, но не теряет надежду.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/0b76b2a2-d1c7-4f04-a284-80ff7bb709a4/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/0b76b2a2-d1c7-4f04-a284-80ff7bb709a4/x1000',
      rating: 9.1,
      ratingImdb: 9.3,
      filmLength: 142,
      slogan: 'Страх держит взаперти. Надежда освобождает',
    ),
    CatalogItem(
      kinopoiskId: 361,
      title: 'Бойцовский клуб',
      nameOriginal: 'Fight Club',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Триллер', 'Драма', 'Криминал'],
      year: 1999,
      director: 'Дэвид Финчер',
      actors: 'Эдвард Нортон, Брэд Питт, Хелена Бонем Картер',
      description:
          'Сотрудник страховой компании страдает бессонницей и пытается вырваться из скучной жизни. Он встречает торговца мылом Тайлера Дёрдена с извращенной философией.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/16490236/495fb59a-bff1-4626-baba-bb392fede945/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/16490236/495fb59a-bff1-4626-baba-bb392fede945/x1000',
      rating: 8.7,
      ratingImdb: 8.8,
      filmLength: 139,
      slogan: 'Интриги. Хаос. Мыло.',
    ),
    CatalogItem(
      kinopoiskId: 447301,
      title: 'Начало',
      nameOriginal: 'Inception',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Фантастика', 'Боевик', 'Триллер'],
      year: 2010,
      director: 'Кристофер Нолан',
      actors: 'Леонардо ДиКаприо, Джозеф Гордон-Левитт, Эллиот Пейдж',
      description:
          'Кобб — искусный вор, лучший из лучших в опасном искусстве извлечения: он крадет ценные секреты из глубин подсознания во время сна.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1629390/8ab9a119-dd74-44f0-baec-0629797483d7/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1629390/8ab9a119-dd74-44f0-baec-0629797483d7/x1000',
      rating: 8.8,
      ratingImdb: 8.8,
      filmLength: 148,
    ),
    CatalogItem(
      kinopoiskId: 4664634,
      title: 'Оппенгеймер',
      nameOriginal: 'Oppenheimer',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Биография', 'Драма', 'История'],
      year: 2023,
      director: 'Кристофер Нолан',
      actors: 'Киллиан Мёрфи, Эмили Блант, Мэтт Дэймон, Роберт Дауни мл.',
      description:
          'История жизни американского физика-теоретика Роберта Оппенгеймера, руководителя Манхэттенского проекта в годы Второй мировой войны.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4486454/c5292109-642c-4ab0-894a-cc304e1bcec4/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4486454/c5292109-642c-4ab0-894a-cc304e1bcec4/x1000',
      rating: 8.5,
      ratingImdb: 8.9,
      filmLength: 180,
    ),
    CatalogItem(
      kinopoiskId: 111543,
      title: 'Тёмный рыцарь',
      nameOriginal: 'The Dark Knight',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Боевик', 'Криминал', 'Драма'],
      year: 2008,
      director: 'Кристофер Нолан',
      actors: 'Кристиан Бэйл, Хит Леджер, Аарон Экхарт',
      description:
          'Бэтмен поднимает ставки в войне с криминалом. С помощью лейтенанта Джима Гордона и прокурора Харви Дента он намерен очистить улицы от преступности, пока не появляется Джокер.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/0fa5bf50-d5ad-446f-a599-b26d070c8b99/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/0fa5bf50-d5ad-446f-a599-b26d070c8b99/x1000',
      rating: 8.8,
      ratingImdb: 9.0,
      filmLength: 152,
    ),
    CatalogItem(
      kinopoiskId: 474,
      title: 'Зелёная миля',
      nameOriginal: 'The Green Mile',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Драма', 'Фэнтези', 'Криминал'],
      year: 1999,
      director: 'Фрэнк Дарабонт',
      actors: 'Том Хэнкс, Дэвид Морс, Майкл Кларк Дункан',
      description:
          'Пол Эджкомб — начальник блока смертников в тюрьме «Холодная гора». Однажды туда попадает гигант Джон Коффи, обладающий необъяснимой целительной силой.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10812607/ad4932b4-c220-48a5-9a37-40fc72da5ffa/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10812607/ad4932b4-c220-48a5-9a37-40fc72da5ffa/x1000',
      rating: 9.1,
      ratingImdb: 8.6,
      filmLength: 189,
    ),
    CatalogItem(
      kinopoiskId: 301,
      title: 'Матрица',
      nameOriginal: 'The Matrix',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Фантастика', 'Боевик'],
      year: 1999,
      director: 'Лана Вачовски, Лилли Вачовски',
      actors: 'Киану Ривз, Лоренс Фишбёрн, Кэрри-Энн Мосс',
      description:
          'Хакер Нео узнаёт шокирующую правду: привычный мир вокруг — лишь иллюзия, цифровая симуляция, контролируемая восставшим искусственным интеллектом.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4774061/cf1970bc-3f08-4e0e-a095-2fb57c3aa7c6/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4774061/cf1970bc-3f08-4e0e-a095-2fb57c3aa7c6/x1000',
      rating: 8.5,
      ratingImdb: 8.7,
      filmLength: 136,
    ),
    CatalogItem(
      kinopoiskId: 342,
      title: 'Криминальное чтиво',
      nameOriginal: 'Pulp Fiction',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Криминал', 'Драма'],
      year: 1994,
      director: 'Квентин Тарантино',
      actors: 'Джон Траволта, Сэмюэл Л. Джексон, Брюс Уиллис, Ума Турман',
      description:
          'Двое бандитов Винсент Вега и Джулс Винфилд проводят время в философских беседах между разборками и поручениями криминального босса Марселласа Уоллеса.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4716873/0a07a903-9025-4aff-bf7c-46bbb175888c/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4716873/0a07a903-9025-4aff-bf7c-46bbb175888c/x1000',
      rating: 8.6,
      ratingImdb: 8.9,
      filmLength: 154,
    ),
    CatalogItem(
      kinopoiskId: 389,
      title: 'Леон',
      nameOriginal: 'Léon',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Боевик', 'Триллер', 'Драма'],
      year: 1994,
      director: 'Люк Бессон',
      actors: 'Жан Рено, Натали Портман, Гари Олдман',
      description:
          'Профессиональный убийца Леон неожиданно берет под опеку соседскую девочку Матильду, чью семью безжалостно расстреляли коррумпированные полицейские.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/6201401/8662d92a-5881-4600-a7ae-549e6fd53b03/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/6201401/8662d92a-5881-4600-a7ae-549e6fd53b03/x1000',
      rating: 8.7,
      ratingImdb: 8.5,
      filmLength: 110,
    ),
    CatalogItem(
      kinopoiskId: 476,
      title: 'Гладиатор',
      nameOriginal: 'Gladiator',
      type: 'movie',
      typeLabel: 'Фильм',
      genres: ['Боевик', 'История', 'Драма'],
      year: 2000,
      director: 'Ридли Скотт',
      actors: 'Рассел Кроу, Хоакин Феникс, Конни Нильсен',
      description:
          'Преданный генералом Максимус чудом избегает гибели, попадает в рабство и становится непревзойдённым гладиатором в римском Колизее.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/73cf2ed0-fd52-47a2-9e26-74104360786a/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/73cf2ed0-fd52-47a2-9e26-74104360786a/x1000',
      rating: 8.6,
      ratingImdb: 8.5,
      filmLength: 155,
    ),

    // СЕРИАЛЫ
    CatalogItem(
      kinopoiskId: 404900,
      title: 'Во все тяжкие',
      nameOriginal: 'Breaking Bad',
      type: 'series',
      typeLabel: 'Сериал',
      genres: ['Криминал', 'Драма', 'Триллер'],
      year: 2008,
      director: 'Винс Гиллиган',
      actors: 'Брайан Крэнстон, Аарон Пол, Анна Ганн',
      description:
          'Школьный учитель химии Уолтер Уайт узнаёт о смертельном диагнозе и решает производить метамфетамин ради будущего семьи.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/fb35416f-3b0d-4b96-bc65-cf6923f9e329/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/fb35416f-3b0d-4b96-bc65-cf6923f9e329/x1000',
      rating: 8.9,
      ratingImdb: 9.5,
      filmLength: 47,
    ),
    CatalogItem(
      kinopoiskId: 915196,
      title: 'Очень странные дела',
      nameOriginal: 'Stranger Things',
      type: 'series',
      typeLabel: 'Сериал',
      genres: ['Фантастика', 'Ужасы', 'Драма'],
      year: 2016,
      director: 'Братья Даффер',
      actors: 'Милли Бобби Браун, Финн Вулфхард, Вайнона Райдер',
      description:
          '1980-е годы, провинциальный городок Хоукинс. Загадочное исчезновение мальчика раскрывает правительственные тайны и потусторонний мир.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10703859/1e653cad-c84f-4617-b61e-949b3228ef36/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10703859/1e653cad-c84f-4617-b61e-949b3228ef36/x1000',
      rating: 8.4,
      ratingImdb: 8.7,
      filmLength: 51,
    ),
    CatalogItem(
      kinopoiskId: 464963,
      title: 'Игра престолов',
      nameOriginal: 'Game of Thrones',
      type: 'series',
      typeLabel: 'Сериал',
      genres: ['Фэнтези', 'Драма', 'Приключения'],
      year: 2011,
      director: 'Дэвид Бениофф, Д.Б. Уайсс',
      actors: 'Питер Динклэйдж, Лина Хиди, Эмилия Кларк, Кит Харингтон',
      description:
          'Лето, длившееся почти десятилетие, угасает. Вокруг Железного трона Семи Королевств зреет грандиозный заговор, пока с Севера надвигается тьма.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/dd78edfd-6a1f-486c-9a86-6acbca940418/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/dd78edfd-6a1f-486c-9a86-6acbca940418/x1000',
      rating: 9.0,
      ratingImdb: 9.2,
      filmLength: 55,
    ),
    CatalogItem(
      kinopoiskId: 1227803,
      title: 'Чернобыль',
      nameOriginal: 'Chernobyl',
      type: 'series',
      typeLabel: 'Сериал',
      genres: ['Драма', 'История'],
      year: 2019,
      director: 'Йохан Ренк',
      actors: 'Джаред Харрис, Стеллан Скарсгард, Эмили Уотсон',
      description:
          'Хроника катастрофы на Чернобыльской АЭС в апреле 1986 года, беспримерное мужество ликвидаторов и страшная цена замалчивания правды.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/a7dfa600-9426-4074-b861-125055b08e2f/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/a7dfa600-9426-4074-b861-125055b08e2f/x1000',
      rating: 8.8,
      ratingImdb: 9.4,
      filmLength: 60,
    ),

    // АНИМЕ
    CatalogItem(
      kinopoiskId: 841681,
      title: 'Токийский гуль',
      nameOriginal: 'Tokyo Ghoul',
      type: 'anime',
      typeLabel: 'Аниме-сериал',
      genres: ['Аниме', 'Ужасы', 'Боевик', 'Фэнтези', 'Драма'],
      year: 2014,
      director: 'Сюхэй Морита',
      actors: 'Нацуки Ханаэ, Сора Амамия, Синтаро Асанума',
      description:
          'Студент Кэн Канэки после несчастного случая попадает в больницу, где ему пересаживают органы гулей. Теперь он чудовище для людей и изгой среди монстров.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/e5d98938-605a-4c8a-b0d6-5f93d926aa0c/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/e5d98938-605a-4c8a-b0d6-5f93d926aa0c/x1000',
      rating: 7.1,
      ratingImdb: 7.8,
      filmLength: 24,
    ),
    CatalogItem(
      kinopoiskId: 749374,
      title: 'Атака титанов',
      nameOriginal: 'Attack on Titan',
      type: 'anime',
      typeLabel: 'Аниме-сериал',
      genres: ['Аниме', 'Боевик', 'Фэнтези', 'Драма'],
      year: 2013,
      director: 'Тэцуро Араки',
      actors: 'Юки Кадзи, Юи Исикава, Марина Иноуэ',
      description:
          'Остатки человечества укрываются за тремя гигантскими стенами от кровожадных титанов. Эрен Йегер клянётся истребить каждого титана до единого.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/dd0060dc-d18e-4754-8e47-e6f6630f9d92/orig',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/dd0060dc-d18e-4754-8e47-e6f6630f9d92/orig',
      rating: 8.7,
      ratingImdb: 9.1,
      filmLength: 24,
    ),
    CatalogItem(
      kinopoiskId: 1220920,
      title: 'Клинок, рассекающий демонов',
      nameOriginal: 'Kimetsu no Yaiba',
      type: 'anime',
      typeLabel: 'Аниме-сериал',
      genres: ['Аниме', 'Боевик', 'Фэнтези'],
      year: 2019,
      director: 'Харуо Сотодзаки',
      actors: 'Нацуки Ханаэ, Акари Кито, Хиро Симоно',
      description:
          'Юноша Тандзиро Камадо становится истребителем демонов, чтобы найти способ исцелить свою младшую сестру Нэдзуко, обращенную в демона.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10671298/32621935-61a6-4479-ae42-829f5642e6b0/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/10671298/32621935-61a6-4479-ae42-829f5642e6b0/x1000',
      rating: 8.3,
      ratingImdb: 8.6,
      filmLength: 25,
    ),
    CatalogItem(
      kinopoiskId: 406148,
      title: 'Тетрадь смерти',
      nameOriginal: 'Death Note',
      type: 'anime',
      typeLabel: 'Аниме-сериал',
      genres: ['Аниме', 'Триллер', 'Детектив', 'Фэнтези'],
      year: 2006,
      director: 'Тэцуро Араки',
      actors: 'Мамору Мияно, Каппэй Ямагути, Сидо Накамура',
      description:
          'Старшеклассник Лайт Ягами находит тетрадь бога смерти: любой человек, чьё имя будет в неё записано, умирает. Лайт решает очистить мир от преступности.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/90d4e92a-fa1e-450f-a42e-dbba89ae39a0/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/90d4e92a-fa1e-450f-a42e-dbba89ae39a0/x1000',
      rating: 8.6,
      ratingImdb: 8.9,
      filmLength: 23,
    ),
    CatalogItem(
      kinopoiskId: 370,
      title: 'Унесённые призраками',
      nameOriginal: 'Sen to Chihiro no kamikakushi',
      type: 'anime',
      typeLabel: 'Аниме',
      genres: ['Аниме', 'Фэнтези', 'Приключения'],
      year: 2001,
      director: 'Хаяо Миядзаки',
      actors: 'Руми Хиираги, Мию Ирино, Мари Нацуки',
      description:
          'Десятилетняя Тихиро переезжает в новый дом и случайно оказывается в таинственном волшебном мире духов и могущественной ведьмы Юбабы.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1946459/547beee1-61cf-4148-9366-071a0ddcf315/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1946459/547beee1-61cf-4148-9366-071a0ddcf315/x1000',
      rating: 8.5,
      ratingImdb: 8.6,
      filmLength: 125,
    ),
    CatalogItem(
      kinopoiskId: 49670,
      title: 'Ходячий замок',
      nameOriginal: 'Hauru no ugoku shiro',
      type: 'anime',
      typeLabel: 'Аниме',
      genres: ['Аниме', 'Фэнтези', 'Мелодрама'],
      year: 2004,
      director: 'Хаяо Миядзаки',
      actors: 'Тиэко Байсё, Такуя Кимура, Акихиро Мива',
      description:
          'Злая ведьма заточила 18-летнюю Софи в тело старухи. Девушка находит приют в удивительном шагающем замке волшебника Хаула.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/d5b5123d-ef04-4b5d-9c3f-c1f93019808a/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1777765/d5b5123d-ef04-4b5d-9c3f-c1f93019808a/x1000',
      rating: 8.3,
      ratingImdb: 8.2,
      filmLength: 119,
    ),

    // МУЛЬТФИЛЬМЫ
    CatalogItem(
      kinopoiskId: 1015471,
      title: 'Райя и последний дракон',
      nameOriginal: 'Raya and the Last Dragon',
      type: 'cartoon',
      typeLabel: 'Мультфильм',
      genres: ['Мультфильм', 'Фэнтези', 'Боевик', 'Приключения'],
      year: 2021,
      director: 'Дон Холл, Карлос Лопес Эстрада',
      actors: 'Келли Мари Трэн, Аквафина, Джемма Чан',
      description:
          'Отважная воительница Райя отправляется на поиски последнего дракона Сису, чтобы объединить разрозненные народы и победить древних монстров.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/84478174-8b68-450f-bc4d-5c683ee30248/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1600647/84478174-8b68-450f-bc4d-5c683ee30248/x1000',
      rating: 8.2,
      ratingImdb: 7.3,
      filmLength: 107,
    ),
    CatalogItem(
      kinopoiskId: 775276,
      title: 'Тайна Коко',
      nameOriginal: 'Coco',
      type: 'cartoon',
      typeLabel: 'Мультфильм',
      genres: ['Мультфильм', 'Фэнтези', 'Семейный', 'Музыка'],
      year: 2017,
      director: 'Ли Анкрич, Эдриан Молина',
      actors: 'Энтони Гонсалес, Гаэль Гарсиа Берналь, Бенджамин Брэтт',
      description:
          '12-летний Мигель мечтает стать музыкантом вопреки семейному запрету и в День мёртвых отправляется в красочный Загробный мир.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4716873/893bba73-3105-4944-8d18-a38f929f2759/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/4716873/893bba73-3105-4944-8d18-a38f929f2759/x1000',
      rating: 8.7,
      ratingImdb: 8.4,
      filmLength: 105,
    ),
    CatalogItem(
      kinopoiskId: 279102,
      title: 'ВАЛЛ-И',
      nameOriginal: 'WALL-E',
      type: 'cartoon',
      typeLabel: 'Мультфильм',
      genres: ['Мультфильм', 'Фантастика', 'Приключения'],
      year: 2008,
      director: 'Эндрю Стэнтон',
      actors: 'Бен Бёртт, Элисса Найт, Джефф Гарлин',
      description:
          'Робот ВАЛЛ-И из года в год прилежно трудится на опустевшей Земле, очищая нашу планету от гор мусора, пока не встречает робота ЕВУ.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/355fb507-6a16-43f1-b844-39f50e8a8e3d/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/355fb507-6a16-43f1-b844-39f50e8a8e3d/x1000',
      rating: 8.4,
      ratingImdb: 8.4,
      filmLength: 98,
    ),
    CatalogItem(
      kinopoiskId: 920265,
      title: 'Человек-паук: Через вселенные',
      nameOriginal: 'Spider-Man: Into the Spider-Verse',
      type: 'cartoon',
      typeLabel: 'Мультфильм',
      genres: ['Мультфильм', 'Боевик', 'Фантастика', 'Приключения'],
      year: 2018,
      director: 'Боб Персичетти, Питер Рэмзи, Родни Ротман',
      actors: 'Шамеик Мур, Джейк Джонсон, Хейли Стайнфелд',
      description:
          'Бруклинский подросток Майлз Моралес случайно получает паучьи способности и узнаёт о существовании мультивселенной с другими пауками.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/e171b3e4-8a4f-4d24-81ae-233bbd41d374/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1599028/e171b3e4-8a4f-4d24-81ae-233bbd41d374/x1000',
      rating: 8.2,
      ratingImdb: 8.4,
      filmLength: 117,
    ),
    CatalogItem(
      kinopoiskId: 430,
      title: 'Шрэк',
      nameOriginal: 'Shrek',
      type: 'cartoon',
      typeLabel: 'Мультфильм',
      genres: ['Мультфильм', 'Фэнтези', 'Комедия', 'Приключения'],
      year: 2001,
      director: 'Эндрю Адамсон, Вики Дженсон',
      actors: 'Майк Майерс, Эдди Мёрфи, Кэмерон Диаз',
      description:
          'Огр Шрэк живёт в уединении на болоте, пока злобный лорд Фаркуад не сгоняет туда сказочных существ. Шрэк отправляется спасать принцессу Фиону.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1946459/a2f7c0a5-f3ff-411a-bc02-16781ea3c246/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1946459/a2f7c0a5-f3ff-411a-bc02-16781ea3c246/x1000',
      rating: 8.2,
      ratingImdb: 7.9,
      filmLength: 90,
    ),
    CatalogItem(
      kinopoiskId: 2360,
      title: 'Король Лев',
      nameOriginal: 'The Lion King',
      type: 'cartoon',
      typeLabel: 'Мультфильм',
      genres: ['Мультфильм', 'Драма', 'Приключения', 'Семейный'],
      year: 1994,
      director: 'Роджер Аллерс, Роб Минкофф',
      actors: 'Мэттью Бродерик, Джереми Айронс, Джеймс Эрл Джонс',
      description:
          'У величественного Короля-Льва Муфасы рождается наследник Симба. Завистливый дядя Шрам устраивает ловушку, чтобы завладеть троном.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1629390/49d44865-c35f-4d43-85e6-ec083b4b0eb0/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1629390/49d44865-c35f-4d43-85e6-ec083b4b0eb0/x1000',
      rating: 8.8,
      ratingImdb: 8.5,
      filmLength: 88,
    ),
    CatalogItem(
      kinopoiskId: 685246,
      title: 'Рик и Морти',
      nameOriginal: 'Rick and Morty',
      type: 'cartoon',
      typeLabel: 'Мультсериал',
      genres: ['Мультфильм', 'Комедия', 'Фантастика'],
      year: 2013,
      director: 'Дэн Хармон, Джастин Ройланд',
      actors: 'Джастин Ройланд, Крис Парнелл, Спенсер Грэммер',
      description:
          'Безумный гениальный дедушка-учёный Рик Санчез вместе со своим пугливым внуком Морти путешествует по параллельным вселенным и измерениям.',
      posterUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1898899/972b7f43-9677-4dce-a6cf-c89b4f738096/x1000',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1898899/972b7f43-9677-4dce-a6cf-c89b4f738096/x1000',
      rating: 9.0,
      ratingImdb: 9.1,
      filmLength: 23,
    ),
  ];
}
