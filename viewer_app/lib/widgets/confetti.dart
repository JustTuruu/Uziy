import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One-shot celebratory confetti burst (reward success).
///
/// Place it in a bounded area, typically `Positioned.fill` in a Stack over
/// the celebration content. If it ends up in an unbounded parent (e.g.
/// directly in a Column) it takes no layout space and bursts across a
/// screen-sized area from where it sits, instead of throwing. Particles are generated from a seeded
/// `Random(seed)`, so every run (and every test) is identical. Ignores
/// pointers, disappears when done, and renders nothing under reduce-motion.
/// Setting [play] from false to true replays the burst.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({
    super.key,
    this.play = true,
    this.particleCount = 60,
    this.colors,
    this.duration = AppDurations.confetti,
    this.origin = const Alignment(0, -0.2),
    this.seed = 42,
    this.onComplete,
  });

  final bool play;
  final int particleCount;

  /// Defaults to golds + accent blue + success green + violet + white.
  final List<Color>? colors;
  final Duration duration;

  /// Where the burst originates within the box.
  final Alignment origin;
  final int seed;

  /// Called once the burst finishes (also under reduce-motion, next frame).
  final VoidCallback? onComplete;

  static const List<Color> defaultColors = [
    AppColors.primaryLight,
    AppColors.primary,
    AppColors.primaryDeep,
    AppColors.accent,
    AppColors.success,
    AppColors.violet,
    AppColors.textPrimary,
  ];

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _Particle {
  const _Particle({
    required this.vx,
    required this.vy,
    required this.size,
    required this.aspect,
    required this.rotation,
    required this.spin,
    required this.flip,
    required this.shape,
    required this.color,
  });

  /// Initial velocity as a fraction of box height per second.
  final double vx, vy;
  final double size, aspect, rotation, spin, flip;

  /// 0 = rectangle, 1 = circle, 2 = thin streamer.
  final int shape;
  final Color color;
}

List<_Particle> _generate(int count, int seed, List<Color> colors) {
  final rnd = math.Random(seed);
  final palette = colors.isEmpty ? ConfettiBurst.defaultColors : colors;
  return List.generate(math.max(0, count), (_) {
    // Upward cone, ~200 degrees wide.
    final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 1.1;
    final speed = 0.7 + rnd.nextDouble() * 0.9;
    return _Particle(
      vx: math.cos(angle) * speed,
      vy: math.sin(angle) * speed,
      size: 5 + rnd.nextDouble() * 5,
      aspect: 0.45 + rnd.nextDouble() * 0.5,
      rotation: rnd.nextDouble() * math.pi * 2,
      spin: (rnd.nextDouble() - 0.5) * 14,
      flip: 4 + rnd.nextDouble() * 8,
      shape: rnd.nextInt(3),
      color: palette[rnd.nextInt(palette.length)],
    );
  });
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener(_onStatus);
  late List<_Particle> _particles = _generate(
    widget.particleCount,
    widget.seed,
    widget.colors ?? ConfettiBurst.defaultColors,
  );
  bool _reduced = false;
  bool _initialized = false;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (mounted) setState(() {});
      widget.onComplete?.call();
    }
  }

  void _start() {
    if (_reduced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onComplete?.call();
      });
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduced(context);
    if (!_initialized) {
      _initialized = true;
      if (widget.play) _start();
    }
  }

  @override
  void didUpdateWidget(covariant ConfettiBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (oldWidget.seed != widget.seed ||
        oldWidget.particleCount != widget.particleCount ||
        oldWidget.colors != widget.colors) {
      _particles = _generate(
        widget.particleCount,
        widget.seed,
        widget.colors ?? ConfettiBurst.defaultColors,
      );
    }
    if (!oldWidget.play && widget.play) _start();
    if (oldWidget.play && !widget.play) _controller.reset();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduced || !widget.play || !_controller.isAnimating) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final screen =
              MediaQuery.maybeSizeOf(context) ?? const Size(400, 800);
          // Physics area: the box when bounded, else the screen.
          final area = Size(
            c.hasBoundedWidth ? c.maxWidth : screen.width,
            c.hasBoundedHeight ? c.maxHeight : screen.height,
          );
          return RepaintBoundary(
            child: CustomPaint(
              // Never claims unbounded space: 0 on an unbounded axis.
              size: c.constrain(Size(
                c.hasBoundedWidth ? c.maxWidth : 0,
                c.hasBoundedHeight ? c.maxHeight : 0,
              )),
              painter: _ConfettiPainter(
                particles: _particles,
                progress: _controller,
                seconds: widget.duration.inMilliseconds / 1000,
                origin: widget.origin,
                area: area,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.particles,
    required this.progress,
    required this.seconds,
    required this.origin,
    required this.area,
  }) : super(repaint: progress);

  final List<_Particle> particles;
  final Animation<double> progress;
  final double seconds;
  final Alignment origin;

  /// Box the burst is laid out in (may be larger than the painted size when
  /// the widget sits in an unbounded parent).
  final Size area;

  static const double _drag = 2.4; // air resistance (1/s)
  static const double _gravity = 1.1; // box heights per s^2

  @override
  void paint(Canvas canvas, Size size) {
    if (area.isEmpty) return;
    final t = progress.value;
    final secs = t * seconds;
    final h = area.height;
    final o = origin.withinRect(Offset.zero & area);
    // Displacement with linear drag: v * (1 - e^(-k t)) / k.
    final dragFactor = (1 - math.exp(-_drag * secs)) / _drag;
    final fall = 0.5 * _gravity * secs * secs * h;
    final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
    final paint = Paint();

    for (final p in particles) {
      final dx = p.vx * h * dragFactor;
      final dy = p.vy * h * dragFactor + fall * 0.55;
      paint.color = p.color.withValues(alpha: p.color.a * opacity);
      canvas.save();
      canvas.translate(o.dx + dx, o.dy + dy);
      canvas.rotate(p.rotation + p.spin * secs);
      // Fake 3D tumble.
      canvas.scale(math.cos(p.flip * secs), 1);
      switch (p.shape) {
        case 0:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: p.size,
              height: p.size * p.aspect,
            ),
            paint,
          );
        case 1:
          canvas.drawCircle(Offset.zero, p.size * 0.4, paint);
        default:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset.zero,
                width: p.size * 1.6,
                height: p.size * 0.3,
              ),
              const Radius.circular(2),
            ),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.particles != particles ||
      oldDelegate.origin != origin ||
      oldDelegate.seconds != seconds ||
      oldDelegate.area != area;
}
