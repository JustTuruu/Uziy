import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'fill_width.dart';

/// Placeholder block for loading layouts. Wrap a group of these in ONE
/// [SkeletonShimmer] so they share a single animation.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadii.xs,
  });

  /// Null fills the available width. Where the width is unbounded (for
  /// example inside a Row without Expanded) it falls back to
  /// [unboundedWidth] instead of throwing.
  final double? width;
  final double height;
  final double radius;

  /// Width used for `width: null` when the incoming width is unbounded.
  static const double unboundedWidth = 120;

  @override
  Widget build(BuildContext context) {
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return ExcludeSemantics(
      child: width == null
          ? FillWidth(fallbackWidth: unboundedWidth, child: block)
          : block,
    );
  }
}

/// Sweeps a soft highlight across its (skeleton) child using one controller
/// and a ShaderMask. Announces 'Ачаалж байна' (loading) to screen readers.
///
/// The sweep repeats forever — in widget tests use `pump(duration)`, not
/// `pumpAndSettle()` (or enable reduce-motion, which renders it static).
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: AppDurations.shimmer);
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduced(context);
    if (_reduced) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = _reduced
        ? widget.child
        : AnimatedBuilder(
            animation: _controller,
            child: widget.child,
            builder: (context, child) => ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) => LinearGradient(
                begin: const Alignment(-1, -0.3),
                end: const Alignment(1, 0.3),
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.07),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.35, 0.5, 0.65],
                transform: _SlideTransform(_controller.value),
              ).createShader(bounds),
              child: child,
            ),
          );

    // The sweep repaints every frame. The boundary keeps that repaint from
    // spreading to the rest of the screen (header, ambient background...).
    return Semantics(
      label: 'Ачаалж байна',
      container: true,
      child: RepaintBoundary(child: body),
    );
  }
}

class _SlideTransform extends GradientTransform {
  const _SlideTransform(this.t);

  /// 0..1 progress of one sweep.
  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2 - 1), 0, 0);
}
