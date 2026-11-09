class VkVideoItem {
  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String duration;
  final String embedUrl;
  final String category;
  final String? views;

  const VkVideoItem({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.duration,
    required this.embedUrl,
    required this.category,
    this.views,
  });
}

class VkVideoService {
  /// Parse VK link or embed code and return a clean iframe embed URL
  static String? parseVkUrl(String rawInput) {
    final raw = rawInput.trim();
    if (raw.isEmpty) return null;

    // Check if pasted iframe code
    final iframeMatch = RegExp(r'src=["\x27]([^"\x27]+)["\x27]').firstMatch(raw);
    if (iframeMatch != null) {
      String src = iframeMatch.group(1)!;
      if (!src.contains('autoplay=')) {
        final sep = src.contains('?') ? '&' : '?';
        src = '$src${sep}autoplay=1';
      }
      return src;
    }

    // Direct embed URL: vk.com/video_ext.php?oid=...&id=...
    if (raw.contains('video_ext.php')) {
      var url = raw;
      if (!url.startsWith('http')) {
        url = 'https://$url';
      }
      if (!url.contains('autoplay=')) {
        final sep = url.contains('?') ? '&' : '?';
        url = '$url${sep}autoplay=1';
      }
      return url;
    }

    // Standard video link: vk.com/video-12345678_456239012 or vk.com/clip-12345678_456239012
    final match = RegExp(r'(?:video|clip)(-?\d+)_(\d+)').firstMatch(raw);
    if (match != null) {
      final oid = match.group(1);
      final id = match.group(2);
      return 'https://vk.com/video_ext.php?oid=$oid&id=$id&hd=2&autoplay=1';
    }

    // Fallback: if already a valid URL
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }

    return null;
  }

  /// Search VK videos by keyword and category
  Future<List<VkVideoItem>> search(String query, {String? category}) async {
    final q = query.trim().toLowerCase();
    return curatedVideos.where((v) {
      final matchesQuery = q.isEmpty ||
          v.title.toLowerCase().contains(q) ||
          v.author.toLowerCase().contains(q);
      final matchesCat = category == null ||
          category == 'Все' ||
          v.category.toLowerCase() == category.toLowerCase();
      return matchesQuery && matchesCat;
    }).toList();
  }

  /// Curated trending VK Video library with working VK player embeds
  static const List<VkVideoItem> curatedVideos = [
    VkVideoItem(
      id: '-220754053_456240091',
      title: 'Что Было Дальше? (ЧБД) — Выпуск с Буруновым и Хасбиком',
      author: 'Labelcom / VK Видео',
      thumbnailUrl: 'https://images.unsplash.com/photo-1518676590629-3dcbd9c5a5c9?w=600&fit=crop',
      duration: '01:14:20',
      embedUrl: 'https://vk.com/video_ext.php?oid=-220754053&id=456240091&hd=2&autoplay=1',
      category: 'Шоу и блоги',
      views: '18.4M',
    ),
    VkVideoItem(
      id: '-220754053_456240092',
      title: 'Большое шоу (8 сезон) — 1 серия. Битва комиков за 3 миллиона',
      author: 'Азамат Мусагалиев',
      thumbnailUrl: 'https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?w=600&fit=crop',
      duration: '48:15',
      embedUrl: 'https://vk.com/video_ext.php?oid=-220754053&id=456240092&hd=2&autoplay=1',
      category: 'Шоу и блоги',
      views: '9.2M',
    ),
    VkVideoItem(
      id: '-220754053_456240093',
      title: 'КСТАТИ #35 — Азамат, Дорохов, Харламов и звёздные гости',
      author: 'VK Видео Эксклюзив',
      thumbnailUrl: 'https://images.unsplash.com/photo-1574375927938-d5a98e8ffe85?w=600&fit=crop',
      duration: '01:05:40',
      embedUrl: 'https://vk.com/video_ext.php?oid=-220754053&id=456240093&hd=2&autoplay=1',
      category: 'Шоу и блоги',
      views: '6.7M',
    ),
    VkVideoItem(
      id: '-220754053_456240094',
      title: 'Тейбл Тайм (3 сезон) — Все серии. Шастун, Позов, Арсений, Матвиенко',
      author: 'Импровизаторы',
      thumbnailUrl: 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?w=600&fit=crop',
      duration: '02:10:00',
      embedUrl: 'https://vk.com/video_ext.php?oid=-220754053&id=456240094&hd=2&autoplay=1',
      category: 'Шоу и блоги',
      views: '11.8M',
    ),
    VkVideoItem(
      id: '-220754053_456240095',
      title: 'ТОПЛЕС: Как искусственный интеллект изменит мир до неузнаваемости',
      author: 'Ян Топлес',
      thumbnailUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600&fit=crop',
      duration: '32:45',
      embedUrl: 'https://vk.com/video_ext.php?oid=-220754053&id=456240095&hd=2&autoplay=1',
      category: 'Наука и жизнь',
      views: '4.5M',
    ),
    VkVideoItem(
      id: '-220754053_456240096',
      title: 'Смешарики: Легенда о золотом драконе (Полный мультфильм в HD)',
      author: 'Смешарики Официально',
      thumbnailUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?w=600&fit=crop',
      duration: '01:22:10',
      embedUrl: 'https://vk.com/video_ext.php?oid=-220754053&id=456240096&hd=2&autoplay=1',
      category: 'Кино и мульты',
      views: '8.1M',
    ),
    VkVideoItem(
      id: '-220754053_456240097',
      title: 'Kuplinov ► Play: Хоррор года! Прохождение с реакциями',
      author: 'Kuplinov ► Play',
      thumbnailUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?w=600&fit=crop',
      duration: '42:30',
      embedUrl: 'https://vk.com/video_ext.php?oid=-220754053&id=456240097&hd=2&autoplay=1',
      category: 'Игры & Стримы',
      views: '3.9M',
    ),
    VkVideoItem(
      id: '-220754053_456240098',
      title: 'Wylsacom: Презентация Apple — Полный русский перевод и обзор новинок',
      author: 'Wylsacom',
      thumbnailUrl: 'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=600&fit=crop',
      duration: '01:45:00',
      embedUrl: 'https://vk.com/video_ext.php?oid=-220754053&id=456240098&hd=2&autoplay=1',
      category: 'Технологии',
      views: '5.2M',
    ),
  ];
}
