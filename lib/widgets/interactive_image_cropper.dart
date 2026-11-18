import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Modal dialog that allows user to interactively pan, zoom (scale), rotate and crop an image for Avatar or Banner
class InteractiveImageCropperDialog extends StatefulWidget {
  final String imageSource;
  final double aspectRatio;
  final bool isCircle;
  final String title;

  const InteractiveImageCropperDialog({
    super.key,
    required this.imageSource,
    required this.aspectRatio,
    this.isCircle = false,
    required this.title,
  });

  static Future<String?> show(
    BuildContext context, {
    required String imageSource,
    required double aspectRatio,
    bool isCircle = false,
    required String title,
  }) {
    return showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => InteractiveImageCropperDialog(
        imageSource: imageSource,
        aspectRatio: aspectRatio,
        isCircle: isCircle,
        title: title,
      ),
    );
  }

  @override
  State<InteractiveImageCropperDialog> createState() =>
      _InteractiveImageCropperDialogState();
}

class _InteractiveImageCropperDialogState
    extends State<InteractiveImageCropperDialog> {
  final TransformationController _transformCtrl =
      TransformationController();
  final GlobalKey _cropKey = GlobalKey();

  double _currentScale = 1.0;
  int _rotationQuarter = 0; // 0, 1, 2, 3 (* 90 degrees)
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _transformCtrl.addListener(() {
      final matrix = _transformCtrl.value;
      final scale = matrix.getMaxScaleOnAxis();
      if ((scale - _currentScale).abs() > 0.01) {
        setState(() {
          _currentScale = scale.clamp(1.0, 3.5);
        });
      }
    });
  }

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  void _setScale(double newScale) {
    setState(() {
      _currentScale = newScale;
      final translation = _transformCtrl.value.getTranslation();
      _transformCtrl.value = Matrix4.translationValues(translation.x, translation.y, 0.0)
        ..scaleByDouble(newScale, newScale, 1.0, 1.0);
    });
  }

  void _resetTransform() {
    setState(() {
      _currentScale = 1.0;
      _rotationQuarter = 0;
      _transformCtrl.value = Matrix4.identity();
    });
  }

  void _rotate() {
    setState(() {
      _rotationQuarter = (_rotationQuarter + 1) % 4;
    });
  }

  Future<void> _saveCrop() async {
    setState(() => _isProcessing = true);
    try {
      final boundary =
          _cropKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) Navigator.of(context).pop(widget.imageSource);
        return;
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 2.5);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        if (mounted) Navigator.of(context).pop(widget.imageSource);
        return;
      }

      final bytes = byteData.buffer.asUint8List();
      final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
      if (mounted) {
        Navigator.of(context).pop(base64String);
      }
    } catch (e) {
      debugPrint('Error exporting cropped image: $e');
      if (mounted) {
        Navigator.of(context).pop(widget.imageSource);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  ImageProvider _resolveImageProvider(String src) {
    if (src.startsWith('data:image')) {
      final comma = src.indexOf(',');
      if (comma != -1) {
        final b64 = src.substring(comma + 1);
        return MemoryImage(base64Decode(b64));
      }
    }
    return NetworkImage(src);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final maxDialogWidth = (w < 600) ? w * 0.95 : 620.0;

    return Dialog(
      backgroundColor:
          isDark ? const Color(0xFF16162A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxDialogWidth),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.crop_rotate_rounded,
                      color: Color(0xFF9F67FF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Interactive Viewport with Crop Window
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: AspectRatio(
                      aspectRatio: widget.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // RepaintBoundary wrapping the zoomed/panned view
                          RepaintBoundary(
                            key: _cropKey,
                            child: ClipRect(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  InteractiveViewer(
                                    transformationController: _transformCtrl,
                                    boundaryMargin: const EdgeInsets.all(200),
                                    minScale: 0.8,
                                    maxScale: 4.0,
                                    child: Center(
                                      child: RotatedBox(
                                        quarterTurns: _rotationQuarter,
                                        child: Image(
                                          image: _resolveImageProvider(
                                              widget.imageSource),
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Center(
                                            child: Icon(
                                              Icons.broken_image_rounded,
                                              color: Colors.white38,
                                              size: 48,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (widget.isCircle)
                                    IgnorePointer(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF7C3AED)
                                                .withValues(alpha: 0.8),
                                            width: 2.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          // Outer framing border indicator
                          IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white24,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Scale / Zoom Slider Control
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.zoom_out_rounded, size: 20),
                    tooltip: 'Уменьшить',
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    onPressed: _currentScale > 1.05
                        ? () => _setScale((_currentScale - 0.2).clamp(1.0, 3.5))
                        : null,
                  ),
                  Expanded(
                    child: Slider(
                      value: _currentScale,
                      min: 1.0,
                      max: 3.5,
                      activeColor: const Color(0xFF7C3AED),
                      inactiveColor:
                          isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      onChanged: _setScale,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.zoom_in_rounded, size: 20),
                    tooltip: 'Увеличить',
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    onPressed: _currentScale < 3.45
                        ? () => _setScale((_currentScale + 0.2).clamp(1.0, 3.5))
                        : null,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.rotate_right_rounded, size: 20),
                    tooltip: 'Повернуть на 90°',
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    onPressed: _rotate,
                  ),
                  IconButton(
                    icon: const Icon(Icons.restart_alt_rounded, size: 20),
                    tooltip: 'Сбросить масштаб',
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    onPressed: _resetTransform,
                  ),
                ],
              ),

              // Helpful Instruction Hint
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E34)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded,
                        size: 15, color: Color(0xFF9F67FF)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Перетаскивайте изображение мышью или пальцем для выбора области. Ползунок выше меняет масштаб (${_currentScale.toStringAsFixed(1)}x).',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white60
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Bottom Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(null),
                    child: const Text('Отмена'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      _isProcessing ? 'Обработка...' : 'Применить и сохранить',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _isProcessing ? null : _saveCrop,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
