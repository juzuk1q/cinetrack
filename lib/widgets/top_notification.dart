import 'package:flutter/material.dart';

/// Beautiful Top-Floating Notification Widget (Replaces bottom SnackBars)
class TopNotification {
  TopNotification._();

  static void show(
    BuildContext context, {
    required String message,
    String? title,
    IconData icon = Icons.info_rounded,
    Color color = const Color(0xFF7C3AED),
    Duration duration = const Duration(milliseconds: 3500),
  }) {
    final overlayState = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _TopNotificationWidget(
        message: message,
        title: title,
        icon: icon,
        color: color,
        duration: duration,
        onDismiss: () {
          try {
            entry.remove();
          } catch (e) {
            debugPrint('Error dismissing notification overlay: $e');
          }
        },
      ),
    );

    overlayState.insert(entry);
  }

  static void showSuccess(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      icon: Icons.check_circle_rounded,
      color: const Color(0xFF10B981),
    );
  }

  static void showError(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      icon: Icons.error_rounded,
      color: const Color(0xFFEF4444),
    );
  }

  static void showWarning(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      icon: Icons.warning_rounded,
      color: const Color(0xFFF59E0B),
    );
  }

  static void showInfo(BuildContext context, String message, {String? title}) {
    show(
      context,
      message: message,
      title: title,
      icon: Icons.info_rounded,
      color: const Color(0xFF6366F1),
    );
  }
}

class _TopNotificationWidget extends StatefulWidget {
  final String message;
  final String? title;
  final IconData icon;
  final Color color;
  final Duration duration;
  final VoidCallback onDismiss;

  const _TopNotificationWidget({
    required this.message,
    this.title,
    required this.icon,
    required this.color,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationWidget> createState() => _TopNotificationWidgetState();
}

class _TopNotificationWidgetState extends State<_TopNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack));

    _animCtrl.forward();

    Future.delayed(widget.duration, () {
      if (mounted) {
        _animCtrl.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _closeImmediately() {
    _animCtrl.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 24,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480, minWidth: 280),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF18182E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.6),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.title != null) ...[
                            Text(
                              widget.title!,
                              style: TextStyle(
                                color: widget.color,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _closeImmediately,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
