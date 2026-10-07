import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'coin.dart';

/// One drifting coin. All numbers are fractions or small whole numbers so a
/// coin's path is a pure function of time (see [coinPlacement]).
class CoinSpec {
  const CoinSpec({
    required this.x,
    required this.size,
    required this.opacity,
    required this.periodSeconds,
    required this.phase,
    required this.swayPixels,
    required this.swayCycles,
    required this.spinCycles,
  });

  /// Horizontal centre as a fraction of the width (0..1).
  final double x;

  /// Diameter in logical pixels.
  final double size;

  /// Peak opacity (before the fade at the top and bottom).
  final double opacity;

  /// Seconds for one fall from the top to the bottom edge.
  final int periodSeconds;

  /// Where in its fall the coin starts (0..1).
  final double phase;

  /// Sideways drift amplitude in pixels.
  final double swayPixels;

  /// Full sideways swings and coin flips per fall.
  final int swayCycles;
  final int spinCycles;
}

/// Where one coin is at a moment: [dy] from the top, [dx] from its column,
/// its [opacity] and how wide it looks while flipping ([flip], 0.25..1).
typedef CoinPlacement = ({double dy, double dx, double opacity, double flip});

/// Length of the whole animation. Every coin period divides it, so the
/// animation loops without a visible jump.
const int kCoinLoopSeconds = 60;

/// Periods a coin may have; each divides [kCoinLoopSeconds].
const List<int> kCoinPeriods = [12, 15, 20, 30, 60];

/// Opacity ramp at the ends of a fall (share of the fall).
const double _fadeIn = 0.12;
const double _fadeOut = 0.18;

/// Position of [spec] at [seconds] into the loop on a canvas of [height].
/// Pure: the same inputs always give the same placement.
CoinPlacement coinPlacement(CoinSpec spec, double seconds, double height) {
  final raw = seconds / spec.periodSeconds + spec.phase;
  final progress = raw - raw.floorToDouble();
  final travel = height + spec.size * 2;
  final dy = progress * travel - spec.size;
  final dx =
      math.sin(2 * math.pi * spec.swayCycles * progress) * spec.swayPixels;

  final envelope = progress < _fadeIn
      ? progress / _fadeIn
      : progress > 1 - _fadeOut
          ? (1 - progress) / _fadeOut
          : 1.0;
  final flip = math.cos(2 * math.pi * spec.spinCycles * progress).abs();
  return (
    dy: dy,
    dx: dx,
    opacity: spec.opacity * envelope,
    flip: 0.25 + 0.75 * flip,
  );
}

/// [count] coins with scattered columns, sizes and speeds. Deterministic for
/// a given [seed], so the backdrop looks the same on every launch.
List<CoinSpec> buildCoinSpecs({int count = 14, int seed = 7}) {
  final random = math.Random(seed);
  return List.generate(count, (i) {
    // Spread the columns evenly, then jitter, so coins never clump.
    final column = (i + random.nextDouble() * 0.8) / count;
    final size = 14 + random.nextDouble() * 22;
    return CoinSpec(
      x: column,
      size: size,
      // Big coins are closer to the eye: a little more visible, still faint.
      opacity: 0.10 + (size - 14) / 22 * 0.22,
      periodSeconds: kCoinPeriods[random.nextInt(kCoinPeriods.length)],
      phase: random.nextDouble(),
      swayPixels: 6 + random.nextDouble() * 14,
      swayCycles: 1 + random.nextInt(3),
      spinCycles: 1 + random.nextInt(4),
    );
  });
}

/// Faint gold coins drifting down behind a screen: depth for an otherwise
/// flat backdrop. Decorative only — ignores touches, has no semantics, and
/// under reduce-motion it shows the same coins frozen mid-fall.
class FallingCoins extends StatefulWidget {
  const FallingCoins({
    super.key,
    this.count = 14,
    this.seed = 7,
    this.child,
  });

  final int count;
  final int seed;

  /// Drawn above the coins.
  final Widget? child;

  /// Moment shown when motion is reduced.
  static const double frozenSeconds = 17;

  @override
  State<FallingCoins> createState() => _FallingCoinsState();
}

class _FallingCoinsState extends State<FallingCoins>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: kCoinLoopSeconds),
  );
  late List<CoinSpec> _specs = buildCoinSpecs(
    count: widget.count,
    seed: widget.seed,
  );
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = AppMotion.reduced(context);
    if (_reduced) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void didUpdateWidget(FallingCoins old) {
    super.didUpdateWidget(old);
    if (old.count != widget.count || old.seed != widget.seed) {
      _specs = buildCoinSpecs(count: widget.count, seed: widget.seed);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: LayoutBuilder(
                builder: (context, box) => AnimatedBuilder(
                  animation: _clock,
                  builder: (context, _) {
                    final seconds = _reduced
                        ? FallingCoins.frozenSeconds
                        : _clock.value * kCoinLoopSeconds;
                    return Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (final spec in _specs)
                          _coin(spec, seconds, box.maxWidth, box.maxHeight),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }

  Widget _coin(CoinSpec spec, double seconds, double width, double height) {
    final p = coinPlacement(spec, seconds, height);
    return Positioned(
      left: spec.x * width + p.dx - spec.size / 2,
      top: p.dy,
      width: spec.size,
      height: spec.size,
      child: Opacity(
        opacity: p.opacity.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(p.flip, 1, 1),
          child: CoinIcon(size: spec.size),
        ),
      ),
    );
  }
}
