import 'dart:async';

class LocalSelectedFile {
  final String name;
  final String blobUrl;
  const LocalSelectedFile({required this.name, required this.blobUrl});
}

abstract class PlatformVideoController {
  void play();
  void pause();
  void seek(double positionInSeconds);
  double get currentTime;
  double get duration;
  bool get isPaused;
}

class PlatformHelper {
  static void cleanBrowserUrl() {}

  static String getOrigin() => 'https://cinetrack.app';

  static String getUserAgent() => '';

  static bool get isFullscreen => false;

  static void requestFullscreen() {}

  static void exitFullscreen() {}

  static Stream<dynamic>? get onFullscreenChange => null;

  static void registerIFrameView(
    String viewId,
    String url, {
    String? backgroundColor,
    bool allowAutoplay = true,
  }) {}

  static void setIframesPointerEvents(bool enabled) {}

  static Future<String?> pickAndCropImageBase64({
    required double targetAspectRatio,
    required int targetWidth,
    required int targetHeight,
    double quality = 0.85,
  }) async => null;

  static void pickVideoFile(void Function(LocalSelectedFile file) onSelected) {}

  static StreamSubscription? listenWindowMessage(void Function(dynamic data) onMessage) => null;
}

class IFrameController {
  void init({
    required String viewId,
    required String url,
    bool blockAds = false,
  }) {}

  void updateUrl(String url) {}

  void setBlockAds(bool blockAds, String url) {}
}
