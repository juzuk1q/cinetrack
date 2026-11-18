class AppConstants {
  AppConstants._();

  static const List<String> genres = [
    'Боевик',
    'Комедия',
    'Драма',
    'Фантастика',
    'Фэнтези',
    'Ужасы',
    'Триллер',
    'Мелодрама',
    'Аниме',
    'Документальный',
    'Приключения',
    'Криминал',
    'Анимация',
    'Семейный',
    'Исторический',
    'Биография',
    'Мюзикл',
    'Спорт',
    'Вестерн',
    'Мистика',
  ];

  static const Map<String, String> mediaTypes = {
    'movie': 'Фильм',
    'series': 'Сериал',
    'cartoon': 'Мультфильм',
  };

  static const Map<String, String> statuses = {
    'want_to_watch': 'Хочу посмотреть',
    'watching': 'Смотрю',
    'watched': 'Просмотрено',
  };

  static const Map<String, String> statusIcons = {
    'want_to_watch': '📋',
    'watching': '▶️',
    'watched': '✅',
  };

  static const int currentYear = 2026;
  static const int minYear = 1888;
}
