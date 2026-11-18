import 'package:flutter/material.dart';

enum BalancerType {
  hls,
  mp4,
  iframe,
}

class BalancerSource {
  final String id;
  final String name;
  final String badge;
  final BalancerType type;
  final String url;
  final bool isDirectStream;
  final bool hasSyncSupport;
  final IconData icon;
  final Color accentColor;
  final String description;

  const BalancerSource({
    required this.id,
    required this.name,
    required this.badge,
    required this.type,
    required this.url,
    required this.isDirectStream,
    required this.hasSyncSupport,
    required this.icon,
    required this.accentColor,
    required this.description,
  });
}

class VideoBalancerService {
  VideoBalancerService._();

  /// Check if the given URL points to an HLS (.m3u8) stream
  static bool isHlsUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    final clean = url.trim().toLowerCase();
    return clean.contains('.m3u8') || clean.contains('/hls/') || clean.contains('format=m3u8');
  }

  /// Get the list of all available balanced video sources for a given movie/show.
  /// Sources are ordered by priority (Direct HLS -> Kinobox Multi -> Collaps HD -> VideoCDN -> Alloha -> Trailer).
  static List<BalancerSource> getSources({
    required int kpId,
    int? season,
    int? episode,
    String? customDirectUrl,
  }) {
    final s = season ?? 1;
    final e = episode ?? 1;
    final isSeries = season != null && episode != null;

    final seriesQueryQ = isSeries ? '?season=$s&episode=$e' : '';

    final sources = <BalancerSource>[];

    // 1. Direct HLS / Native Stream (Zero Ads, Full Sync Control)
    if (customDirectUrl != null && customDirectUrl.isNotEmpty) {
      final isHls = isHlsUrl(customDirectUrl);
      sources.add(
        BalancerSource(
          id: 'direct_stream',
          name: isHls ? 'Прямой HLS (Zeta/CDN)' : 'Прямой поток (MP4)',
          badge: '0 рекламы ⭐',
          type: isHls ? BalancerType.hls : BalancerType.mp4,
          url: customDirectUrl,
          isDirectStream: true,
          hasSyncSupport: true,
          icon: Icons.flash_on_rounded,
          accentColor: const Color(0xFF10B981), // Emerald
          description: 'Нативный плеер без сторонней рекламы с идеальной синхронизацией',
        ),
      );
    }

    // 2. Primary Smart Video Balancer (Delivembd / Collaps network, 1080p, all translations)
    sources.add(
      BalancerSource(
        id: 'primary_balancer',
        name: 'Видеобалансер HD',
        badge: 'Основной • 1080p',
        type: BalancerType.iframe,
        url: 'https://api.delivembd.ws/embed/kp/$kpId$seriesQueryQ',
        isDirectStream: false,
        hasSyncSupport: true,
        icon: Icons.auto_awesome_rounded,
        accentColor: const Color(0xFF7C3AED), // Violet
        description: 'Универсальный видеобалансер с автоматическим выбором озвучки и качества',
      ),
    );

    // 3. Backup Mirror Balancer
    sources.add(
      BalancerSource(
        id: 'backup_mirror',
        name: 'Резервное зеркало',
        badge: 'Резерв',
        type: BalancerType.iframe,
        url: 'https://api.namy.ws/embed/kp/$kpId$seriesQueryQ',
        isDirectStream: false,
        hasSyncSupport: false,
        icon: Icons.shield_rounded,
        accentColor: const Color(0xFF3B82F6), // Blue
        description: 'Запасной сервер на случай ограничений провайдерами',
      ),
    );

    // 6. Kinopoisk Official Trailer (Always safe fallback)
    sources.add(
      BalancerSource(
        id: 'trailer',
        name: 'Официальный трейлер',
        badge: 'HD Трейлер',
        type: BalancerType.iframe,
        url: 'https://widgets.kinopoisk.ru/discovery/trailer/$kpId?no_top_panel=true',
        isDirectStream: false,
        hasSyncSupport: false,
        icon: Icons.movie_filter_rounded,
        accentColor: const Color(0xFF8B5CF6), // Purple
        description: 'Официальный трейлер в высоком качестве с Кинопоиска',
      ),
    );

    return sources;
  }
}
