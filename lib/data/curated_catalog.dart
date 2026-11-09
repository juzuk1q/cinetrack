import '../models/catalog_item.dart';

class CuratedCatalog {
  CuratedCatalog._();

  static const List<CatalogItem> items = [
    // ФИЛЬМЫ
    CatalogItem(
      title: 'Интерстеллар',
      type: 'movie',
      genres: ['Фантастика', 'Драма', 'Приключения'],
      year: 2014,
      director: 'Кристофер Нолан',
      actors: 'Мэттью Макконахи, Энн Хэтэуэй, Джессика Честейн',
      description:
          'Когда засуха, пыльные бури и вымирание растений приводят человечество к продовольственному кризису, коллектив исследователей отправляется сквозь червоточину в поисках нового дома.',
      posterUrl:
          'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=600&auto=format&fit=crop&q=80',
      rating: 8.7,
    ),
    CatalogItem(
      title: 'Начало',
      type: 'movie',
      genres: ['Фантастика', 'Боевик', 'Триллер'],
      year: 2010,
      director: 'Кристофер Нолан',
      actors: 'Леонардо ДиКаприо, Джозеф Гордон-Левитт, Эллиот Пейдж',
      description:
          'Кобб — искусный вор, лучший из лучших в опасном искусстве извлечения: он крадет ценные секреты из глубин подсознания во время сна.',
      posterUrl:
          'https://images.unsplash.com/photo-1478760329108-5c3ed9d495a0?w=600&auto=format&fit=crop&q=80',
      rating: 8.8,
    ),
    CatalogItem(
      title: 'Оппенгеймер',
      type: 'movie',
      genres: ['Биография', 'Драма', 'Исторический'],
      year: 2023,
      director: 'Кристофер Нолан',
      actors: 'Киллиан Мёрфи, Эмили Блант, Мэтт Дэймон, Роберт Дауни мл.',
      description:
          'История жизни американского физика-теоретика Роберта Оппенгеймера, руководителя Манхэттенского проекта в годы Второй мировой войны.',
      posterUrl:
          'https://images.unsplash.com/photo-1440404653325-ab127d49abc1?w=600&auto=format&fit=crop&q=80',
      rating: 8.5,
    ),
    CatalogItem(
      title: 'Побег из Шоушенка',
      type: 'movie',
      genres: ['Драма', 'Криминал'],
      year: 1994,
      director: 'Фрэнк Дарабонт',
      actors: 'Тим Роббинс, Морган Фриман, Боб Гантон',
      description:
          'Бухгалтер Энди Дюфрейн обвинён в убийстве собственной жены и её любовника. Оказавшись в тюрьме Шоушенк, он сталкивается с жестокостью, но не теряет надежду.',
      posterUrl:
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&auto=format&fit=crop&q=80',
      rating: 9.3,
    ),
    CatalogItem(
      title: 'Тёмный рыцарь',
      type: 'movie',
      genres: ['Боевик', 'Криминал', 'Драма'],
      year: 2008,
      director: 'Кристофер Нолан',
      actors: 'Кристиан Бэйл, Хит Леджер, Аарон Экхарт',
      description:
          'Бэтмен поднимает ставки в войне с криминалом с помощью лейтенанта Джима Гордона и прокурора Харви Дента, пока город не погружается в хаос Джокера.',
      posterUrl:
          'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
      rating: 9.0,
    ),
    CatalogItem(
      title: 'Зелёная миля',
      type: 'movie',
      genres: ['Драма', 'Фэнтези', 'Криминал'],
      year: 1999,
      director: 'Фрэнк Дарабонт',
      actors: 'Том Хэнкс, Дэвид Морс, Майкл Кларк Дункан',
      description:
          'Пол Эджкомб — начальник блока смертников в тюрьме «Холодная гора». Однажды туда попадает гигант Джон Коффи, обладающий необъяснимой магической силой.',
      posterUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      rating: 9.1,
    ),
    CatalogItem(
      title: 'Гарри Поттер и философский камень',
      type: 'movie',
      genres: ['Фэнтези', 'Приключения', 'Семейный'],
      year: 2001,
      director: 'Крис Коламбус',
      actors: 'Дэниэл Рэдклифф, Руперт Гринт, Эмма Уотсон',
      description:
          'Жизнь десятилетнего Гарри Поттера меняется, когда он узнаёт, что является волшебником, и отправляется учиться в школу магии Хогвартс.',
      posterUrl:
          'https://images.unsplash.com/photo-1547756536-cde3673fa2e5?w=600&auto=format&fit=crop&q=80',
      rating: 8.2,
    ),
    CatalogItem(
      title: 'Властелин колец: Братство Кольца',
      type: 'movie',
      genres: ['Фэнтези', 'Приключения', 'Боевик'],
      year: 2001,
      director: 'Питер Джексон',
      actors: 'Элайджа Вуд, Иэн Маккеллен, Вигго Мортенсен',
      description:
          'Хоббит Фродо Бэггинс получает Единое Кольцо Власти и в компании верных друзей отправляется в Мордор, чтобы уничтожить его в Огненной Горе.',
      posterUrl:
          'https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600&auto=format&fit=crop&q=80',
      rating: 8.8,
    ),
    CatalogItem(
      title: 'Аватар',
      type: 'movie',
      genres: ['Фантастика', 'Боевик', 'Приключения'],
      year: 2009,
      director: 'Джеймс Кэмерон',
      actors: 'Сэм Уортингтон, Зои Салдана, Сигурни Уивер',
      description:
          'Бывший морпех Джейк Салли оказывается на далекой планете Пандора, где перед ним встает выбор между долгом и защитой нового мира.',
      posterUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      rating: 8.0,
    ),
    CatalogItem(
      title: 'Брат',
      type: 'movie',
      genres: ['Боевик', 'Криминал', 'Драма'],
      year: 1997,
      director: 'Алексей Балабанов',
      actors: 'Сергей Бодров мл., Виктор Сухоруков, Светлана Письмиченко',
      description:
          'Демобилизовавшись из армии, Данила Багров едет в Санкт-Петербург к старшему брату, который оказывается наемным убийцей.',
      posterUrl:
          'https://images.unsplash.com/photo-1485846234645-a62644f84728?w=600&auto=format&fit=crop&q=80',
      rating: 8.3,
    ),
    CatalogItem(
      title: 'Бойцовский клуб',
      type: 'movie',
      genres: ['Драма', 'Триллер', 'Криминал'],
      year: 1999,
      director: 'Дэвид Финчер',
      actors: 'Эдвард Нортон, Брэд Питт, Хелена Бонем Картер',
      description:
          'Терзаемый бессонницей клерк знакомится с харизматичным торговцем мылом Тайлером Дёрденом с бунтарской философией саморазрушения.',
      posterUrl:
          'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=600&auto=format&fit=crop&q=80',
      rating: 8.7,
    ),
    CatalogItem(
      title: 'Титаник',
      type: 'movie',
      genres: ['Мелодрама', 'Драма', 'Исторический'],
      year: 1997,
      director: 'Джеймс Кэмерон',
      actors: 'Леонардо ДиКаприо, Кейт Уинслет, Билли Зейн',
      description:
          'История любви юноши из низшего класса Джека и аристократки Розы на борту легендарного трансатлантического лайнера «Титаник».',
      posterUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&auto=format&fit=crop&q=80',
      rating: 8.4,
    ),
    CatalogItem(
      title: 'Матрица',
      type: 'movie',
      genres: ['Фантастика', 'Боевик'],
      year: 1999,
      director: 'Лана Вачовски, Лилли Вачовски',
      actors: 'Киану Ривз, Лоренс Фишбёрн, Кэрри-Энн Мосс',
      description:
          'Хакер Нео узнаёт шокирующую правду: привычный мир вокруг — лишь иллюзия, цифровая симуляция, контролируемая искусственным интеллектом.',
      posterUrl:
          'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=600&auto=format&fit=crop&q=80',
      rating: 8.5,
    ),

    // СЕРИАЛЫ
    CatalogItem(
      title: 'Во все тяжкие',
      type: 'series',
      genres: ['Криминал', 'Драма', 'Триллер'],
      year: 2008,
      director: 'Винс Гиллиган',
      actors: 'Брайан Крэнстон, Аарон Пол, Анна Ганн',
      description:
          'Школьный учитель химии Уолтер Уайт узнаёт о неизлечимой болезни и решает заняться производством метамфетамина ради финансового будущего семьи.',
      posterUrl:
          'https://images.unsplash.com/photo-1514306191717-452ec28c7814?w=600&auto=format&fit=crop&q=80',
      rating: 9.5,
    ),
    CatalogItem(
      title: 'Очень странные дела',
      type: 'series',
      genres: ['Фантастика', 'Ужасы', 'Драма'],
      year: 2016,
      director: 'Братья Даффер',
      actors: 'Милли Бобби Браун, Финн Вулфхард, Вайнона Райдер',
      description:
          '1980-е годы, тихий провинциальный американский городок. Загадочное исчезновение подростка раскрывает правительственные тайны и потусторонний мир «Изнанки».',
      posterUrl:
          'https://images.unsplash.com/photo-1509281373149-e957c6296406?w=600&auto=format&fit=crop&q=80',
      rating: 8.7,
    ),
    CatalogItem(
      title: 'Чернобыль',
      type: 'series',
      genres: ['Драма', 'Исторический'],
      year: 2019,
      director: 'Йохан Ренк',
      actors: 'Джаред Харрис, Стеллан Скарсгард, Эмили Уотсон',
      description:
          'Хроника катастрофы на Чернобыльской АЭС в апреле 1986 года, мужество ликвидаторов и цена человеческих ошибок.',
      posterUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      rating: 9.4,
    ),
    CatalogItem(
      title: 'Одни из нас (The Last of Us)',
      type: 'series',
      genres: ['Фантастика', 'Драма', 'Боевик'],
      year: 2023,
      director: 'Крэйг Мэйзин, Нил Дракманн',
      actors: 'Педро Паскаль, Белла Рамзи, Гэбриел Луна',
      description:
          'Закалённый выживальщик Джоэл соглашается провести 14-летнюю сироту Элли через постапокалиптические США, кишащие опасными заражёнными.',
      posterUrl:
          'https://images.unsplash.com/photo-1533613220915-609f661a6fe1?w=600&auto=format&fit=crop&q=80',
      rating: 8.8,
    ),
    CatalogItem(
      title: 'Игра престолов',
      type: 'series',
      genres: ['Фэнтези', 'Драма', 'Приключения'],
      year: 2011,
      director: 'Дэвид Бениофф, Д.Б. Уайсс',
      actors: 'Питер Динклэйдж, Лина Хиди, Эмилия Кларк, Кит Харингтон',
      description:
          'К концу подходит время благоденствия, и лето, длившееся почти десятилетие, угасает. Вокруг Железного трона Семи Королевств зреет заговор.',
      posterUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      rating: 9.2,
    ),
    CatalogItem(
      title: 'Рик и Морти',
      type: 'series',
      genres: ['Анимация', 'Комедия', 'Фантастика'],
      year: 2013,
      director: 'Дэн Хармон, Джастин Ройланд',
      actors: 'Джастин Ройланд, Крис Парнелл, Спенсер Грэммер',
      description:
          'Безумный дедушка-учёный Рик Санчез вместе со своим пугливым внуком Морти путешествует по параллельным вселенным и измерениям.',
      posterUrl:
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&auto=format&fit=crop&q=80',
      rating: 9.1,
    ),

    // МУЛЬТФИЛЬМЫ И АНИМЕ
    CatalogItem(
      kinopoiskId: 841681,
      title: 'Токийский гуль',
      nameOriginal: 'Tokyo Ghoul',
      type: 'cartoon',
      typeLabel: 'Аниме-сериал',
      genres: ['Аниме', 'Ужасы', 'Боевик', 'Фэнтези', 'Драма'],
      year: 2014,
      director: 'Сюхэй Морита',
      actors: 'Нацуки Ханаэ, Сора Амамия, Синтаро Асанума',
      description:
          'С обычным студентом Кэном Канэки случается беда, парень попадает в больницу. Но на этом неприятности не заканчиваются: ему пересаживают органы гулей – существ, поедающих плоть людей. После злосчастной операции Канэки становится одним из чудовищ, пытается стать своим, но для людей он теперь изгой, обреченный на уничтожение.',
      posterUrl:
          'https://kinopoiskapiunofficial.tech/images/posters/kp/841681.jpg',
      coverUrl:
          'https://avatars.mds.yandex.net/get-kinopoisk-image/1900788/e5d98938-605a-4c8a-b0d6-5f93d926aa0c/orig',
      rating: 7.1,
      ratingImdb: 7.8,
    ),
    CatalogItem(
      title: 'Унесённые призраками',
      type: 'cartoon',
      genres: ['Аниме', 'Фэнтези', 'Приключения'],
      year: 2001,
      director: 'Хаяо Миядзаки',
      actors: 'Руми Хиираги, Мию Ирино, Мари Нацуки',
      description:
          'Десятилетняя Тихиро переезжает с родителями в новый дом и случайно оказывается в таинственном волшебном мире духов и могущественной ведьмы Юбабы.',
      posterUrl:
          'https://images.unsplash.com/photo-1578632767115-351597cf2477?w=600&auto=format&fit=crop&q=80',
      rating: 8.6,
    ),
    CatalogItem(
      title: 'Тайна Коко',
      type: 'cartoon',
      genres: ['Анимация', 'Семейный', 'Музыка'],
      year: 2017,
      director: 'Ли Анкрич, Эдриан Молина',
      actors: 'Энтони Гонсалес, Гаэль Гарсиа Берналь, Бенджамин Брэтт',
      description:
          '12-летний Мигель мечтает стать музыкантом вопреки семейному запрету и в День мёртвых отправляется в красочный Загробный мир.',
      posterUrl:
          'https://images.unsplash.com/photo-1514533450685-4493e01d1fdc?w=600&auto=format&fit=crop&q=80',
      rating: 8.4,
    ),
    CatalogItem(
      title: 'ВАЛЛ-И',
      type: 'cartoon',
      genres: ['Анимация', 'Фантастика', 'Семейный'],
      year: 2008,
      director: 'Эндрю Стэнтон',
      actors: 'Бен Бёртт, Элисса Найт, Джефф Гарлин',
      description:
          'Робот ВАЛЛ-И из года в год прилежно трудится на опустевшей Земле, очищая нашу планету от гор мусора. Пока не встречает ЕВУ.',
      posterUrl:
          'https://images.unsplash.com/photo-1485827404703-89b55fcc595e?w=600&auto=format&fit=crop&q=80',
      rating: 8.4,
    ),
    CatalogItem(
      title: 'Человек-паук: Через вселенные',
      type: 'cartoon',
      genres: ['Анимация', 'Боевик', 'Фантастика'],
      year: 2018,
      director: 'Боб Персичетти, Питер Рэмзи, Родни Ротман',
      actors: 'Шамеик Мур, Джейк Джонсон, Хейли Стайнфелд',
      description:
          'Бруклинский подросток Майлз Моралес случайно получает паучьи способности и узнаёт о существовании мультивселенной с другими пауками.',
      posterUrl:
          'https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=600&auto=format&fit=crop&q=80',
      rating: 8.4,
    ),
    CatalogItem(
      title: 'Шрэк',
      type: 'cartoon',
      genres: ['Анимация', 'Комедия', 'Фэнтези', 'Семейный'],
      year: 2001,
      director: 'Эндрю Адамсон, Вики Дженсон',
      actors: 'Майк Майерс, Эдди Мёрфи, Кэмерон Диаз',
      description:
          'Огр Шрэк живёт в уединении на болоте, пока злобный лорд Фаркуад не сгоняет туда сказочных существ. Шрэк отправляется спасти принцессу Фиону.',
      posterUrl:
          'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&auto=format&fit=crop&q=80',
      rating: 8.2,
    ),
    CatalogItem(
      title: 'Король Лев',
      type: 'cartoon',
      genres: ['Анимация', 'Драма', 'Приключения', 'Семейный'],
      year: 1994,
      director: 'Роджер Аллерс, Роб Минкофф',
      actors: 'Мэттью Бродерик, Джереми Айронс, Джеймс Эрл Джонс',
      description:
          'У величественного Короля-Льва Муфасы рождается наследник Симба. Завистливый дядя Шрам мечтает о троне и устраивает коварную ловушку.',
      posterUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      rating: 8.8,
    ),
    CatalogItem(
      title: 'Ходячий замок',
      type: 'cartoon',
      genres: ['Аниме', 'Фэнтези', 'Мелодрама'],
      year: 2004,
      director: 'Хаяо Миядзаки',
      actors: 'Тиэко Байсё, Такуя Кимура, Акихиро Мива',
      description:
          'Злая ведьма заточила 18-летнюю Софи в тело старухи. Девушка бежит из города и находит приют в удивительном шагающем замке волшебника Хаула.',
      posterUrl:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600&auto=format&fit=crop&q=80',
      rating: 8.2,
    ),
  ];
}
