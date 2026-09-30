import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../utils/format.dart';

/// Money text that counts from its previous value to [value]
/// (`'3,400 ₮'` style via [formatTugrik]), with tabular figures so digits
/// don't jitter.
///
/// On first build it counts up from 0 unless [animateOnMount] is false.
/// Reduce-motion => the final value is shown immediately.
/// Screen readers get only the final value.
class AnimatedMoney extends StatefulWidget {
  const AnimatedMoney({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.withSign = false,
    this.duration = AppDurations.countUp,
    this.animateOnMount = true,
    this.textAlign,
  });

  final num value;

  /// Defaults to [AppTextStyles.money]. Tabular figures are always applied.
  final TextStyle? style;

  /// Text placed before the amount (e.g. `'Үлдэгдэл '`).
  final String prefix;

  /// Show '+' for positive amounts (see [formatTugrik]).
  final bool withSign;
  final Duration duration;
  final bool animateOnMount;
  final TextAlign? textAlign;

  @override
  State<AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<AnimatedMoney> {
  late final double _start =
      widget.animateOnMount ? 0 : widget.value.toDouble();

  String _format(num v) =>
      '${widget.prefix}${formatTugrik(v, withSign: widget.withSign)}';

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? AppTextStyles.money)
        .copyWith(fontFeatures: AppTextStyles.tabular);
    final target = widget.value.toDouble();
    final finalLabel = _format(target);

    Widget text(String s) => Text(
          s,
          style: style,
          maxLines: 1,
          textAlign: widget.textAlign,
        );

    // One TweenAnimationBuilder for both modes (zero duration under
    // reduce-motion), so toggling the OS setting never swaps the subtree and
    // restarts the count from 0. A zero-duration tween lands on the final
    // value in the very first frame.
    final Widget child = TweenAnimationBuilder<double>(
      // When [value] changes, the builder animates from the value currently
      // on screen to the new target.
      tween: Tween<double>(begin: _start, end: target),
      duration: AppMotion.duration(context, widget.duration),
      curve: AppMotion.standard,
      builder: (context, v, _) => text(_format(v)),
    );

    return Semantics(
      label: finalLabel,
      excludeSemantics: true,
      child: child,
    );
  }
}
