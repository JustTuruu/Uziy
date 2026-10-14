import 'package:flutter/widgets.dart';

import '../theme/app_theme.dart';

/// [AnimatedSize] that simply jumps when the OS asks for reduced motion.
///
/// An [AnimatedSize] whose duration becomes zero (what
/// `AppMotion.duration` returns under reduce-motion) re-dirties itself in the
/// middle of its own layout and throws. Use this instead of a bare
/// [AnimatedSize] whenever the duration follows the motion setting.
class ReducibleAnimatedSize extends StatelessWidget {
  const ReducibleAnimatedSize({
    super.key,
    required this.duration,
    required this.child,
    this.curve = Curves.linear,
    this.alignment = Alignment.center,
  });

  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context) || duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: curve,
      alignment: alignment,
      child: child,
    );
  }
}
