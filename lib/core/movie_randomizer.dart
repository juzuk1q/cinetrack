import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/curated_catalog.dart';
import '../models/catalog_item.dart';
import '../widgets/top_notification.dart';

class MovieRandomizer {
  MovieRandomizer._();

  static final Random _rng = Random();
  static final List<String> _recentItemKeys = [];
  static int _lastTitleIndex = -1;
  static int _lastPhraseIndex = -1;

  static const List<String> _titles = [
    'Кинорулетка 🎲',
    'Судьба решила! 🔮',
    'Выбор вечера ✨',
    'Случайный шедевр 🎬',
    'Карты сошлись 🍿',
    'Киноинтуиция 🎯',
    'Неожиданная находка 🚀',
    'Что посмотреть? 💡',
    'Время кино! 🎞️',
    'Счастливый билет 🎟️',
    'Рекомендация CineTrack 🌟',
    'Сегодня смотрим это! 🔥',
  ];

  static const List<String Function(String title, int year)> _phrases = [
    _phrase1,
    _phrase2,
    _phrase3,
    _phrase4,
    _phrase5,
    _phrase6,
    _phrase7,
    _phrase8,
    _phrase9,
    _phrase10,
    _phrase11,
    _phrase12,
  ];

  static String _phrase1(String t, int y) =>
      'Сегодня ваш выбор — «$t» ($y)! Приятного просмотра 🍿';
  static String _phrase2(String t, int y) =>
      'Рулетка остановилась на «$t» ($y). Готовьте попкорн! 🎬';
  static String _phrase3(String t, int y) =>
      'Звёзды сошлись: сегодня на экране «$t» ($y) ✨';
  static String _phrase4(String t, int y) =>
      'Интуиция подсказывает: «$t» ($y) сделает этот вечер 🎯';
  static String _phrase5(String t, int y) =>
      'Случайный выбор судьбы — «$t» ($y). Отличный вариант! 🌟';
  static String _phrase6(String t, int y) =>
      'Как насчёт «$t» ($y)? Самое время включить! 🔥';
  static String _phrase7(String t, int y) =>
      'Кинобоги одобрили: смотрим «$t» ($y) прямо сейчас 🚀';
  static String _phrase8(String t, int y) =>
      'Отличная находка: шедевр «$t» ($y) уже ждёт вас 🎞️';
  static String _phrase9(String t, int y) =>
      'Идеально подходит для сегодняшнего сеанса: «$t» ($y) ☕';
  static String _phrase10(String t, int y) =>
      'Выпал фильм «$t» ($y) — обещает быть захватывающим! 💫';
  static String _phrase11(String t, int y) =>
      'Держите билет в первый ряд: «$t» ($y) 🎟️';
  static String _phrase12(String t, int y) =>
      'Алгоритм выбрал для вас идеальную картину: «$t» ($y) ⚡';

  /// Picks a random movie, ensures varied notifications and avoiding immediate duplicates,
  /// displays an engaging notification and navigates to the movie details.
  static void pickAndOpen(
    BuildContext context, {
    List<CatalogItem>? candidates,
    bool usePush = true,
  }) {
    // Combine provided candidates with curated items
    final pool = <CatalogItem>[];
    if (candidates != null && candidates.isNotEmpty) {
      pool.addAll(candidates);
    }
    // Also merge curated items to ensure a rich selection
    for (final item in CuratedCatalog.items) {
      final key = item.kinopoiskId?.toString() ?? item.title;
      if (!pool.any((p) => (p.kinopoiskId?.toString() ?? p.title) == key)) {
        pool.add(item);
      }
    }

    if (pool.isEmpty) return;

    // Filter out recently viewed items to prevent repetition
    var freshPool = pool.where((item) {
      final key = item.kinopoiskId?.toString() ?? item.title;
      return !_recentItemKeys.contains(key);
    }).toList();

    // If all items were exhausted, clear recent history
    if (freshPool.isEmpty) {
      _recentItemKeys.clear();
      freshPool = pool;
    }

    final chosen = freshPool[_rng.nextInt(freshPool.length)];
    final chosenKey = chosen.kinopoiskId?.toString() ?? chosen.title;
    _recentItemKeys.add(chosenKey);
    if (_recentItemKeys.length > 10) {
      _recentItemKeys.removeAt(0);
    }

    // Pick varied title and phrase (ensuring they don't repeat the previous ones)
    int titleIdx;
    do {
      titleIdx = _rng.nextInt(_titles.length);
    } while (titleIdx == _lastTitleIndex && _titles.length > 1);
    _lastTitleIndex = titleIdx;

    int phraseIdx;
    do {
      phraseIdx = _rng.nextInt(_phrases.length);
    } while (phraseIdx == _lastPhraseIndex && _phrases.length > 1);
    _lastPhraseIndex = phraseIdx;

    final title = _titles[titleIdx];
    final message = _phrases[phraseIdx](chosen.title, chosen.year);

    TopNotification.showSuccess(
      context,
      message,
      title: title,
    );

    final targetPath = '/movie/${chosen.kinopoiskId ?? chosen.title}';
    if (usePush) {
      context.push(targetPath, extra: chosen);
    } else {
      context.go(targetPath, extra: chosen);
    }
  }
}
