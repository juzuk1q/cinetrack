// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart';

class LocalSelectedFile {
  final String name;
  final String blobUrl;
  const LocalSelectedFile({required this.name, required this.blobUrl});
}

class PlatformHelper {
  static void cleanBrowserUrl() {
    try {
      final currentHref = html.window.location.href;
      if (currentHref.contains('access_token') ||
          currentHref.contains('error=') ||
          currentHref.contains('code=')) {
        final origin = html.window.location.origin;
        final cleanPath = html.window.location.pathname ?? '';
        html.window.history.replaceState(null, 'CineTrack', '$origin$cleanPath');
      }
    } catch (e) {
      debugPrint('cleanBrowserUrl error: $e');
    }
  }

  static String getOrigin() {
    try {
      return html.window.location.origin;
    } catch (_) {
      return 'https://cinetrack.app';
    }
  }

  static String getUserAgent() {
    try {
      return html.window.navigator.userAgent.toLowerCase();
    } catch (_) {
      return '';
    }
  }

  static bool get isFullscreen {
    try {
      return html.document.fullscreenElement != null;
    } catch (_) {
      return false;
    }
  }

  static void requestFullscreen() {
    try {
      html.document.documentElement?.requestFullscreen();
    } catch (e) {
      debugPrint('requestFullscreen error: $e');
    }
  }

  static void exitFullscreen() {
    try {
      html.document.exitFullscreen();
    } catch (e) {
      debugPrint('exitFullscreen error: $e');
    }
  }

  static Stream<dynamic>? get onFullscreenChange {
    try {
      return html.document.onFullscreenChange;
    } catch (_) {
      return null;
    }
  }

  static void registerIFrameView(
    String viewId,
    String url, {
    String? backgroundColor,
    bool allowAutoplay = true,
  }) {
    try {
      final iframe = html.IFrameElement()
        ..src = url
        ..referrerPolicy = 'strict-origin-when-cross-origin'
        ..setAttribute('referrerpolicy', 'strict-origin-when-cross-origin')
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = backgroundColor ?? '#0A0A14'
        ..allow =
            'autoplay; fullscreen; encrypted-media; picture-in-picture; web-share; clipboard-write';

      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int id) => iframe,
      );
    } catch (e) {
      debugPrint('registerIFrameView error: $e');
    }
  }

  static void setIframesPointerEvents(bool enabled) {
    try {
      void visit(html.Element node) {
        if (node is html.IFrameElement) {
          node.style.pointerEvents = enabled ? 'auto' : 'none';
        }
        for (final child in node.children) {
          visit(child);
        }
      }

      final body = html.document.body;
      if (body != null) visit(body);
      final docEl = html.document.documentElement;
      if (docEl != null) visit(docEl);
    } catch (e) {
      debugPrint('setIframesPointerEvents error: $e');
    }
  }

  static Future<String?> pickAndCropImageBase64({
    required double targetAspectRatio,
    required int targetWidth,
    required int targetHeight,
    double quality = 0.85,
  }) async {
    final completer = Completer<String?>();
    final uploadInput = html.FileUploadInputElement()
      ..accept = 'image/*'
      ..multiple = false;

    uploadInput.click();

    uploadInput.onChange.listen((event) {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsDataUrl(file);
      reader.onLoadEnd.listen((_) {
        final rawDataUrl = reader.result;
        if (rawDataUrl is! String) {
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final img = html.ImageElement()..src = rawDataUrl;
        img.onLoad.listen((_) {
          try {
            final naturalWidth = img.naturalWidth;
            final naturalHeight = img.naturalHeight;
            if (naturalWidth == 0 || naturalHeight == 0) {
              if (!completer.isCompleted) completer.complete(rawDataUrl);
              return;
            }

            final currentRatio = naturalWidth / naturalHeight;
            num sx = 0, sy = 0, sw = naturalWidth, sh = naturalHeight;

            if (currentRatio > targetAspectRatio) {
              sw = (naturalHeight * targetAspectRatio).round();
              sx = ((naturalWidth - sw) / 2).round();
            } else {
              sh = (naturalWidth / targetAspectRatio).round();
              sy = ((naturalHeight - sh) / 2).round();
            }

            final canvas =
                html.CanvasElement(width: targetWidth, height: targetHeight);
            final ctx = canvas.context2D;
            ctx.drawImageScaledFromSource(
                img, sx, sy, sw, sh, 0, 0, targetWidth, targetHeight);

            final croppedDataUrl = canvas.toDataUrl('image/jpeg', quality);
            if (!completer.isCompleted) completer.complete(croppedDataUrl);
          } catch (e) {
            if (!completer.isCompleted) completer.complete(rawDataUrl);
          }
        });

        img.onError.listen((_) {
          if (!completer.isCompleted) completer.complete(rawDataUrl);
        });
      });

      reader.onError.listen((_) {
        if (!completer.isCompleted) completer.complete(null);
      });
    });

    return completer.future;
  }

  static void pickVideoFile(void Function(LocalSelectedFile file) onSelected) {
    try {
      final uploadInput = html.FileUploadInputElement()
        ..accept = 'video/*,video/mp4,video/webm,video/x-matroska';
      uploadInput.click();

      uploadInput.onChange.listen((e) {
        final files = uploadInput.files;
        if (files != null && files.isNotEmpty) {
          final file = files[0];
          final blobUrl = html.Url.createObjectUrl(file);
          onSelected(LocalSelectedFile(name: file.name, blobUrl: blobUrl));
        }
      });
    } catch (e) {
      debugPrint('pickVideoFile error: $e');
    }
  }

  static StreamSubscription? listenWindowMessage(
      void Function(dynamic data) onMessage) {
    try {
      return html.window.onMessage.listen((event) {
        onMessage(event.data);
      });
    } catch (e) {
      debugPrint('listenWindowMessage error: $e');
      return null;
    }
  }
}

class IFrameController {
  html.IFrameElement? _element;

  void init({
    required String viewId,
    required String url,
    bool blockAds = false,
  }) {
    try {
      _element = html.IFrameElement()
        ..src = url
        ..referrerPolicy = 'strict-origin-when-cross-origin'
        ..setAttribute('referrerpolicy', 'strict-origin-when-cross-origin')
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#0A0A14'
        ..allow =
            'autoplay; fullscreen; encrypted-media; picture-in-picture; web-share; clipboard-write';

      if (blockAds) {
        _element!.setAttribute(
          'sandbox',
          'allow-scripts allow-same-origin allow-forms allow-presentation',
        );
      }

      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int id) => _element!,
      );
    } catch (e) {
      debugPrint('IFrameController init error: $e');
    }
  }

  void updateUrl(String url) {
    try {
      _element?.src = url;
    } catch (e) {
      debugPrint('IFrameController updateUrl error: $e');
    }
  }

  void setBlockAds(bool blockAds, String url) {
    try {
      if (_element != null) {
        if (blockAds) {
          _element!.setAttribute(
            'sandbox',
            'allow-scripts allow-same-origin allow-forms allow-presentation',
          );
        } else {
          _element!.removeAttribute('sandbox');
        }
        _element!.src = url;
      }
    } catch (e) {
      debugPrint('IFrameController setBlockAds error: $e');
    }
  }
}
