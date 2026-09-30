import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// One-shot entrance: fades in while sliding up [offset] px.
///
/// For staggered lists pass the item [index]. Items that mount in the same
/// frame form a batch, and each waits `AppDurations.stagger * n`, where n is
/// its index minus the lowest index in that batch (capped at
/// [maxStaggerIndex]). So the first screenful of a feed cascades 0, 1, 2...
/// while a card that `ListView.builder` builds later during a scroll (say
/// index 14) starts its fade right away and does not sit blank for 440 ms.
///
/// Plays once on mount. It uses no Timers, so `pumpAndSettle` is safe in
/// widget tests. Reduce-motion shows the child immediately.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.delay = Duration.zero,
    this.duration = AppDurations.medium,
    this.offset = 16,
  });

  final Widget child;
  final int index;

  /// Extra delay added before the stagger delay.
  final Duration delay;
  final Duration duration;

  /// Starting vertical offset in logical pixels (negative = from above).
  final double offset;

  static const int maxStaggerIndex = 8;

  /// Stagger step for an item at [index] in a batch whose lowest index is
  /// [batchMinIndex]: `clamp(index - batchMinIndex, 0, maxStaggerIndex)`.
  /// Pure, exposed for tests.
  static int staggerSlot(int index, int batchMinIndex) =>
      (index - batchMinIndex).clamp(0, maxStaggerIndex);

  // Lowest index among FadeSlideIns that mounted in the current frame. It is
  // reset after the frame, so the next frame starts a new batch.
  static int? _batchMinIndex;

  static int _joinBatch(int index) {
    final current = _batchMinIndex;
    if (current == null) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _batchMinIndex = null;
      });
    }
    final min = current == null ? index : math.min(current, index);
    _batchMinIndex = min;
    return staggerSlot(index, min);
  }

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _curve;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (AppMotion.reduced(context)) return;

    final slot = FadeSlideIn._joinBatch(math.max(widget.index, 0));
    final wait = widget.delay + AppDurations.stagger * slot;
    final total = wait + widget.duration;
    final start = total.inMicroseconds == 0
        ? 0.0
        : wait.inMicroseconds / total.inMicroseconds;
    final controller = AnimationController(vsync: this, duration: total);
    _controller = controller;
    _curve = CurvedAnimation(
      parent: controller,
      curve: Interval(start, 1, curve: AppMotion.standard),
    );
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = _curve;
    if (curve == null) return widget.child;
    return FadeTransition(
      opacity: curve,
      child: AnimatedBuilder(
        animation: curve,
        // The boundary lets the per-frame translate move a cached layer
        // instead of repainting the whole card (art, text, chips) each frame.
        child: RepaintBoundary(child: widget.child),
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - curve.value)),
          child: child,
        ),
      ),
    );
  }
}
