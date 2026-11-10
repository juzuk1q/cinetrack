// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ImageCropDialog extends StatefulWidget {
  final String rawDataUrl;
  final bool isAvatar; // true = 1:1 circle, false = 3:1 banner
  final int targetWidth;
  final int targetHeight;

  const ImageCropDialog({
    super.key,
    required this.rawDataUrl,
    required this.isAvatar,
    this.targetWidth = 400,
    this.targetHeight = 400,
  });

  @override
  State<ImageCropDialog> createState() => _ImageCropDialogState();
}

class _ImageCropDialogState extends State<ImageCropDialog> {
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  int _naturalWidth = 0;
  int _naturalHeight = 0;
  bool _isLoaded = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
  }

  void _loadImageDimensions() {
    if (kIsWeb) {
      final img = html.ImageElement()..src = widget.rawDataUrl;
      img.onLoad.listen((_) {
        if (mounted) {
          setState(() {
            _naturalWidth = img.naturalWidth;
            _naturalHeight = img.naturalHeight;
            _isLoaded = true;
          });
        }
      });
      img.onError.listen((_) {
        if (mounted) {
          setState(() {
            _naturalWidth = 800;
            _naturalHeight = 600;
            _isLoaded = true;
          });
        }
      });
    } else {
      _naturalWidth = 800;
      _naturalHeight = 600;
      _isLoaded = true;
    }
  }

  Future<void> _applyCrop(double boxWidth, double boxHeight) async {
    if (!kIsWeb) {
      Navigator.pop(context, widget.rawDataUrl);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final img = html.ImageElement()..src = widget.rawDataUrl;
      await img.onLoad.first;

      final canvas = html.CanvasElement(
        width: widget.targetWidth,
        height: widget.targetHeight,
      );
      final ctx = canvas.context2D;

      // Fill with dark background
      ctx.fillStyle = '#0F0F1A';
      ctx.fillRect(0, 0, widget.targetWidth, widget.targetHeight);

      // Scale factor from preview box to canvas
      final ratio = widget.targetWidth / boxWidth;

      // Base aspect fit
      final aspectFitScale = (boxWidth / _naturalWidth).clamp(
        boxWidth / _naturalWidth,
        boxHeight / _naturalHeight,
      );

      final renderW = _naturalWidth * aspectFitScale * _scale * ratio;
      final renderH = _naturalHeight * aspectFitScale * _scale * ratio;

      final destX = (widget.targetWidth - renderW) / 2 + (_offset.dx * ratio);
      final destY = (widget.targetHeight - renderH) / 2 + (_offset.dy * ratio);

      ctx.drawImageScaled(img, destX, destY, renderW, renderH);

      final croppedUrl = canvas.toDataUrl('image/jpeg', 0.88);
      if (mounted) {
        Navigator.pop(context, croppedUrl);
      }
    } catch (e) {
      debugPrint('Error cropping image: $e');
      if (mounted) {
        Navigator.pop(context, widget.rawDataUrl);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    // Viewport box dimensions
    final boxWidth = widget.isAvatar
        ? (screenWidth < 400 ? 240.0 : 280.0)
        : (screenWidth < 500 ? (screenWidth - 80).clamp(260.0, 420.0) : 420.0);
    final boxHeight = widget.isAvatar ? boxWidth : (boxWidth / 3.0);

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1F22) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Icon(
            widget.isAvatar ? Icons.account_circle_rounded : Icons.panorama_rounded,
            color: const Color(0xFF9F67FF),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isAvatar
                  ? 'Настройка и обрезка аватарки'
                  : 'Настройка и обрезка баннера',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Перемещайте изображение пальцем или мышкой и настраивайте масштаб:',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),

            // Live WYSIWYG Crop Viewport
            Center(
              child: Container(
                width: boxWidth,
                height: boxHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141424) : const Color(0xFFF1F5F9),
                  shape: widget.isAvatar ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: widget.isAvatar ? null : BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF7C3AED),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: !_isLoaded
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF7C3AED),
                        ),
                      )
                    : GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            _offset += details.delta;
                          });
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Transform.translate(
                              offset: _offset,
                              child: Transform.scale(
                                scale: _scale,
                                child: Image.network(
                                  widget.rawDataUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_rounded, size: 40),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 18),

            // Zoom Controls & Slider
            Row(
              children: [
                IconButton(
                  tooltip: 'Отдалить (подальше)',
                  icon: const Icon(Icons.zoom_out_rounded, size: 20),
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  onPressed: () {
                    setState(() {
                      _scale = (_scale - 0.15).clamp(0.4, 4.0);
                    });
                  },
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: const Color(0xFF7C3AED),
                      thumbColor: const Color(0xFF9F67FF),
                      inactiveTrackColor: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                    ),
                    child: Slider(
                      value: _scale,
                      min: 0.4,
                      max: 3.5,
                      onChanged: (val) {
                        setState(() => _scale = val);
                      },
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Приблизить (поближе)',
                  icon: const Icon(Icons.zoom_in_rounded, size: 20),
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  onPressed: () {
                    setState(() {
                      _scale = (_scale + 0.15).clamp(0.4, 4.0);
                    });
                  },
                ),
              ],
            ),

            // Reset Position button
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _scale = 1.0;
                  _offset = Offset.zero;
                });
              },
              icon: const Icon(Icons.center_focus_strong_rounded, size: 14),
              label: const Text('Сбросить по центру', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(
            'Отмена',
            style: TextStyle(
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C3AED),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSaving ? null : () => _applyCrop(boxWidth, boxHeight),
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded, size: 16),
          label: Text(_isSaving ? 'Сохранение...' : 'Применить'),
        ),
      ],
    );
  }
}

/// Helper function to open file picker and then open the interactive crop & scale dialog
Future<String?> pickAndInteractiveCropImage({
  required BuildContext context,
  required bool isAvatar,
  int targetWidth = 400,
  int targetHeight = 400,
}) async {
  if (!kIsWeb) return null;
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
    reader.onLoadEnd.listen((_) async {
      final rawDataUrl = reader.result;
      if (rawDataUrl is! String) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      if (!context.mounted) {
        if (!completer.isCompleted) completer.complete(rawDataUrl);
        return;
      }

      final cropped = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => ImageCropDialog(
          rawDataUrl: rawDataUrl,
          isAvatar: isAvatar,
          targetWidth: targetWidth,
          targetHeight: targetHeight,
        ),
      );

      if (!completer.isCompleted) completer.complete(cropped);
    });

    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
  });

  return completer.future;
}
