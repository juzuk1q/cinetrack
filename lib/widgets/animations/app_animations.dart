import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shimmer gradient effect for placeholder skeletons
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const ShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ??
        (isDark ? const Color(0xFF1E1E34) : const Color(0xFFE2E8F0));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF2E2E50) : const Color(0xFFF1F5F9));

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: const Alignment(-1.5, -0.3),
              end: const Alignment(1.5, 0.3),
              stops: [
                (_ctrl.value - 0.3).clamp(0.0, 1.0),
                _ctrl.value,
                (_ctrl.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: [
                base,
                highlight,
                base,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shimmer placeholder container
class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ShimmerLoading(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Interactive button with springy bounce scale animation on tap
class BouncyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final Duration duration;

  const BouncyButton({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.92,
    this.duration = const Duration(milliseconds: 140),
  });

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scale = Tween<double>(begin: 1.0, end: widget.scaleFactor).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) _ctrl.forward();
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _ctrl.reverse();
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}

/// Pulsating neon badge (e.g. for Live, Watching status)
class PulseBadge extends StatefulWidget {
  final Widget child;
  final Color glowColor;

  const PulseBadge({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF10B981),
  });

  @override
  State<PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<PulseBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.35 * _animation.value),
                blurRadius: 10 * _animation.value,
                spreadRadius: 1.5 * _animation.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Universal interactive hover card with smooth lift, scale, border glow, and shadow elevation
class AnimatedHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final double lift;
  final BorderRadius? borderRadius;
  final Color? glowColor;

  const AnimatedHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 1.035,
    this.lift = -5.0,
    this.borderRadius,
    this.glowColor,
  });

  @override
  State<AnimatedHoverCard> createState() => _AnimatedHoverCardState();
}

class _AnimatedHoverCardState extends State<AnimatedHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final br = widget.borderRadius ?? BorderRadius.circular(16);
    final glow = widget.glowColor ?? const Color(0xFF7C3AED);

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0.0, _isHovered ? widget.lift : 0.0, 0.0)
            ..scaleByDouble(_isHovered ? widget.scale : 1.0, _isHovered ? widget.scale : 1.0, 1.0, 1.0),
          decoration: BoxDecoration(
            borderRadius: br,
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: glow.withValues(alpha: 0.32),
                      blurRadius: 20,
                      spreadRadius: 1,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Helper to create smooth fade-through page transitions for GoRouter
CustomTransitionPage<T> buildSmoothTransitionPage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      final slide = Tween<Offset>(
        begin: const Offset(0.0, 0.035),
        end: Offset.zero,
      ).animate(curved);

      final fade = Tween<double>(begin: 0.0, end: 1.0).animate(curved);

      final secondaryCurved = CurvedAnimation(
        parent: secondaryAnimation,
        curve: Curves.easeInCubic,
      );
      final secondaryFade = Tween<double>(begin: 1.0, end: 0.88).animate(secondaryCurved);
      final secondaryScale = Tween<double>(begin: 1.0, end: 0.98).animate(secondaryCurved);

      return SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: secondaryScale,
            child: FadeTransition(
              opacity: secondaryFade,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
