import 'dart:convert';
import 'package:http/http.dart' as http;

class YouTubeVideoItem {
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String duration;
  final String? viewCount;

  const YouTubeVideoItem({
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    this.viewCount,
  });

  String get embedUrl =>
      'https://www.youtube.com/embed/$videoId?enablejsapi=1&autoplay=1&rel=0&playsinline=1';

  factory YouTubeVideoItem.fromJson(Map<String, dynamic> json) {
    final vId = (json['videoId'] as String?) ?? '';
    final title = (json['title'] as String?) ?? 'Без названия';
    final author = (json['author'] as String?) ?? 'Канал';

    // Format lengthSeconds into mm:ss or hh:mm:ss
    final lengthSec = json['lengthSeconds'] as int? ?? 0;
    String dur = '';
    if (lengthSec > 0) {
      final h = lengthSec ~/ 3600;
      final m = (lengthSec % 3600) ~/ 60;
      final s = lengthSec % 60;
      if (h > 0) {
        dur = '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      } else {
        dur = '$m:${s.toString().padLeft(2, '0')}';
      }
    } else {
      dur = 'HD';
    }

    String thumb = 'https://i.ytimg.com/vi/$vId/hqdefault.jpg';
    if (json['videoThumbnails'] is List && (json['videoThumbnails'] as List).isNotEmpty) {
      final thumbs = json['videoThumbnails'] as List;
      final best = thumbs.last;
      if (best is Map && best['url'] != null) {
        thumb = best['url'] as String;
      }
    }

    final viewsNum = json['viewCount'] as num?;
    String? views;
    if (viewsNum != null) {
      if (viewsNum >= 1000000) {
        views = '${(viewsNum / 1000000).toStringAsFixed(1)}M просмотров';
      } else if (viewsNum >= 1000) {
        views = '${(viewsNum / 1000).toStringAsFixed(0)}K просмотров';
      } else {
        views = '$viewsNum просмотров';
      }
    }

    return YouTubeVideoItem(
      videoId: vId,
      title: title,
      author: author,
      thumbnailUrl: thumb,
      duration: dur,
      viewCount: views,
    );
  }
}

class YouTubeService {
  static const List<String> _invidiousInstances = [
    'https://yt.chocolatemoo53.com',
    'https://inv.nadeko.net',
    'https://invidious.jing.rocks',
  ];

  static final Map<String, List<YouTubeVideoItem>> _cache = {};

  /// Extract YouTube Video ID from any URL format
  static String? extractVideoId(String input) {
    final raw = input.trim();
    if (raw.length == 11 && !raw.contains('/') && !raw.contains('?')) {
      return raw;
    }

    final regExp = RegExp(
      r'(?:youtu\.be\/|youtube\.com\/(?:embed\/|v\/|watch\?v=|watch\?.+&v=|shorts\/))([\w-]{11})',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(raw);
    return match?.group(1);
  }

  /// Search YouTube videos
  Future<List<YouTubeVideoItem>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return getTrending();

    final cacheKey = 'search_${q.toLowerCase()}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    for (final instance in _invidiousInstances) {
      try {
        final uri = Uri.parse('$instance/api/v1/search?q=${Uri.encodeQueryComponent(q)}&type=video');
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
          final items = data
              .where((i) => i is Map && i['type'] == 'video' && i['videoId'] != null)
              .map((i) => YouTubeVideoItem.fromJson(i as Map<String, dynamic>))
              .toList();

          if (items.isNotEmpty) {
            _cache[cacheKey] = items;
            return items;
          }
        }
      } catch (e) {
        // Try next instance
      }
    }

    // Fallback search in curated items
    return curatedPopular.where((item) {
      return item.title.toLowerCase().contains(q.toLowerCase()) ||
          item.author.toLowerCase().contains(q.toLowerCase());
    }).toList();
  }

  /// Fetch trending YouTube videos
  Future<List<YouTubeVideoItem>> getTrending({String region = 'RU'}) async {
    final cacheKey = 'trending_$region';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    for (final instance in _invidiousInstances) {
      try {
        final uri = Uri.parse('$instance/api/v1/trending?region=$region&type=music');
        final res = await http.get(uri).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
          final items = data
              .where((i) => i is Map && (i['type'] == 'video' || i['videoId'] != null))
              .map((i) => YouTubeVideoItem.fromJson(i as Map<String, dynamic>))
              .toList();

          if (items.isNotEmpty) {
            _cache[cacheKey] = items;
            return items;
          }
        }
      } catch (e) {
        // Try next instance
      }
    }

    return curatedPopular;
  }

  /// Curated trending & popular videos for instant zero-lag rendering
  static const List<YouTubeVideoItem> curatedPopular = [
    YouTubeVideoItem(
      videoId: 'DjqEnGYWpQQ',
      title: 'Minecraft Live 2026: Главные анонсы, новые мобы и биомы',
      author: 'Minecraft Official',
      thumbnailUrl: 'https://i.ytimg.com/vi/DjqEnGYWpQQ/hqdefault.jpg',
      duration: '12:49',
      viewCount: '2.4M просмотров',
    ),
    YouTubeVideoItem(
      videoId: 'Way9Dexny3w',
      title: 'Дюна: Часть 2 — Финальный русский трейлер (Дубляж)',
      author: 'Red Head Sound',
      thumbnailUrl: 'https://i.ytimg.com/vi/Way9Dexny3w/hqdefault.jpg',
      duration: '02:54',
      viewCount: '4.8M просмотров',
    ),
    YouTubeVideoItem(
      videoId: 'r7zJ8srWWgk',
      title: 'Головоломка 2 — Официальный трейлер в 4K',
      author: 'Pixar Animation',
      thumbnailUrl: 'https://i.ytimg.com/vi/r7zJ8srWWgk/hqdefault.jpg',
      duration: '02:26',
      viewCount: '15.2M просмотров',
    ),
    YouTubeVideoItem(
      videoId: 'd9MyW72ELq0',
      title: 'Аватар: Легенда об Аанге — Лучшие моменты битв сериала',
      author: 'Avatar The Last Airbender',
      thumbnailUrl: 'https://i.ytimg.com/vi/d9MyW72ELq0/hqdefault.jpg',
      duration: '18:14',
      viewCount: '9.1M просмотров',
    ),
    YouTubeVideoItem(
      videoId: 'jfKfPfyJRdk',
      title: 'lofi hip hop radio 📚 - beats to relax/study to',
      author: 'Lofi Girl',
      thumbnailUrl: 'https://i.ytimg.com/vi/jfKfPfyJRdk/hqdefault.jpg',
      duration: 'LIVE',
      viewCount: '48.9K зрителей',
    ),
    YouTubeVideoItem(
      videoId: 'b9EkMc79ZSU',
      title: 'Интерстеллар — Главная тема саундтрека (Hans Zimmer OST)',
      author: 'Hans Zimmer',
      thumbnailUrl: 'https://i.ytimg.com/vi/b9EkMc79ZSU/hqdefault.jpg',
      duration: '04:55',
      viewCount: '87M просмотров',
    ),
    YouTubeVideoItem(
      videoId: 'qEVUtrk8_B4',
      title: 'Дэдпул и Росомаха — Полный разбор всех пасхалок и камео',
      author: 'КиноПоиск',
      thumbnailUrl: 'https://i.ytimg.com/vi/qEVUtrk8_B4/hqdefault.jpg',
      duration: '15:20',
      viewCount: '1.7M просмотров',
    ),
    YouTubeVideoItem(
      videoId: 'dQw4w9WgXcQ',
      title: 'Rick Astley - Never Gonna Give You Up (Official Music Video)',
      author: 'Rick Astley',
      thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      duration: '03:32',
      viewCount: '1.5B просмотров',
    ),
  ];
}
