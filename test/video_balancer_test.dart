import 'package:cinetrack/services/video_balancer_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VideoBalancerService Tests', () {
    test('isHlsUrl correctly identifies .m3u8 and HLS streams', () {
      expect(VideoBalancerService.isHlsUrl('https://example.com/playlist.m3u8'), isTrue);
      expect(VideoBalancerService.isHlsUrl('https://example.com/stream/hls/master.m3u8?token=123'), isTrue);
      expect(VideoBalancerService.isHlsUrl('https://example.com/video.mp4'), isFalse);
      expect(VideoBalancerService.isHlsUrl(''), isFalse);
      expect(VideoBalancerService.isHlsUrl(null), isFalse);
    });

    test('getSources returns primary balancer and backup mirror with single unified player flow', () {
      final sources = VideoBalancerService.getSources(kpId: 301);

      expect(sources.isNotEmpty, isTrue);
      final ids = sources.map((s) => s.id).toList();

      expect(ids, contains('primary_balancer'));
      expect(ids, contains('backup_mirror'));
      expect(ids, contains('trailer'));

      final primary = sources.firstWhere((s) => s.id == 'primary_balancer');
      expect(primary.url, contains('delivembd.ws/embed/kp/301'));
      expect(primary.type, BalancerType.iframe);
      expect(primary.hasSyncSupport, isTrue);

      final mirror = sources.firstWhere((s) => s.id == 'backup_mirror');
      expect(mirror.url, contains('namy.ws/embed/kp/301'));
      expect(mirror.type, BalancerType.iframe);
    });

    test('getSources includes direct HLS source when customDirectUrl is provided', () {
      const hlsUrl = 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';
      final sources = VideoBalancerService.getSources(
        kpId: 301,
        customDirectUrl: hlsUrl,
      );

      final direct = sources.firstWhere((s) => s.id == 'direct_stream');
      expect(direct.isDirectStream, isTrue);
      expect(direct.type, BalancerType.hls);
      expect(direct.badge, contains('0 рекламы'));
      expect(direct.url, hlsUrl);
    });

    test('getSources properly formats season and episode queries for series', () {
      final sources = VideoBalancerService.getSources(
        kpId: 1220920,
        season: 2,
        episode: 5,
      );

      final primary = sources.firstWhere((s) => s.id == 'primary_balancer');
      expect(primary.url, contains('season=2&episode=5'));

      final mirror = sources.firstWhere((s) => s.id == 'backup_mirror');
      expect(mirror.url, contains('season=2&episode=5'));
    });
  });
}
