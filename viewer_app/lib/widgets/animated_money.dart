import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

/// The last amount each [AnimatedMoney.memoryKey] showed, for the whole app
/// session. A balance that has not changed since it was last on screen then
/// appears at once instead of replaying an animation on every tab switch.
abstract final class MoneyMemory {
  /// The viewer's wallet balance (Home pill, wallet card, profile).
  static const String balance = 'balance';

  static final Map<String, double> _shown = {};

  static double? lastShown(String key) => _shown[key];

  static void remember(String key, double value) => _shown[key] = value;

  @visibleForTesting
  static void clear() => _shown.clear();
}

/// Money text (`'3,400 ₮'` via [formatTugrik]) whose changed digits roll like
/// an odometer when [value] changes: up when the amount grows, down when it
/// shrinks, rightmost digit first. Unchanged digits, separators and '₮'
/// stay still. At rest it is a plain [Text] with tabular figures.
///
/// Where it starts:
/// * with a [memoryKey]: from the amount last shown under that key — so an
///   unchanged balance appears at once, and a reward rolls only the digits
///   that changed. The first time ever it simply shows [value].
/// * otherwise from 0 when [animateOnMount], else at [value].
///
/// Reduce-motion => the final value at once. Screen readers get only the
/// final value.
class AnimatedMoney extends StatefulWidget {
  const AnimatedMoney({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.withSign = false,
    this.duration = AppDurations.countUp,
    this.animateOnMount = true,
    this.memoryKey,
    this.textAlign,
  });

  final num value;

  /// Defaults to [context.textStyles.money]. Tabular figures are always applied.
  final TextStyle? style;

  /// Text placed before the amount (e.g. `'Үлдэгдэл '`).
  final String prefix;

  /// Show '+' for positive amounts (see [formatTugrik]).
  final bool withSign;
  final Duration duration;
  final bool animateOnMount;

  /// Remember the shown amount under this key (see [MoneyMemory]).
  final String? memoryKey;
  final TextAlign? textAlign;

  @override
  State<AnimatedMoney> createState() => _AnimatedMoneyState();
}

class _AnimatedMoneyState extends State<AnimatedMoney>
    with SingleTickerProviderStateMixin {
  late final AnimationController _roll =
      AnimationController(vsync: this, duration: widget.duration);

  /// The amount the current roll started from. Read before [_rollTo]
  /// stores the new amount in [MoneyMemory].
  late double _from;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _from = _startValue();
  }

  double get _target => widget.value.toDouble();

  double _startValue() {
    final key = widget.memoryKey;
    if (key != null) return MoneyMemory.lastShown(key) ?? _target;
    return widget.animateOnMount ? 0 : _target;
  }

  String _format(num v) =>
      '${widget.prefix}${formatTugrik(v, withSign: widget.withSign)}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs MediaQuery (reduce-motion), so not in initState.
    if (_started) return;
    _started = true;
    _rollTo(_target);
  }

  @override
  void didUpdateWidget(covariant AnimatedMoney oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;
    // Start from what is on screen: the old target, or mid-roll the old one.
    _from = oldWidget.value.toDouble();
    _rollTo(_target);
  }

  void _rollTo(double target) {
    final key = widget.memoryKey;
    if (key != null) MoneyMemory.remember(key, target);
    final duration = AppMotion.duration(context, widget.duration);
    if (_from == target || duration == Duration.zero) {
      _roll.value = 1;
      return;
    }
    _roll
      ..duration = duration
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? context.textStyles.money)
        .copyWith(fontFeatures: AppTextStyles.tabular);
    final finalLabel = _format(_target);

    return Semantics(
      label: finalLabel,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _roll,
        builder: (context, _) => OdometerText(
          from: _format(_from),
          to: finalLabel,
          progress: _roll.value,
          rising: _target >= _from,
          style: style,
          textAlign: widget.textAlign,
        ),
      ),
    );
  }
}

/// [to] with the characters that differ from [from] mid-roll at [progress]
/// (0..1). The two strings are aligned on the right, so '2,700 ₮' →
/// '3,400 ₮' rolls only '2'→'3' and '7'→'4'. At progress 1 it is a plain
/// [Text] of [to].
class OdometerText extends StatelessWidget {
  const OdometerText({
    super.key,
    required this.from,
    required this.to,
    required this.progress,
    required this.style,
    this.rising = true,
    this.textAlign,
  });

  final String from;
  final String to;
  final double progress;
  final TextStyle style;

  /// Digits travel up (new from below) when true, down when false.
  final bool rising;
  final TextAlign? textAlign;

  /// Each digit further left starts this share of the roll later.
  static const double stagger = 0.08;

  /// The stagger never eats more than this share of the whole roll.
  static const double maxTotalStagger = 0.45;

  @override
  Widget build(BuildContext context) {
    if (progress >= 1 || from == to) {
      return Text(to, style: style, maxLines: 1, textAlign: textAlign);
    }
    final n = to.length;
    final old =
        from.length >= n ? from.substring(from.length - n) : from.padLeft(n);
    final step = n > 1 ? math.min(stagger, maxTotalStagger / (n - 1)) : 0.0;
    final span = 1 - step * (n - 1);

    // Like the resting one-line Text, a row too wide for its slot is clipped,
    // never reported as an overflow.
    return UnconstrainedBox(
      constrainedAxis: Axis.vertical,
      clipBehavior: Clip.hardEdge,
      alignment: textAlign == TextAlign.center
          ? Alignment.center
          : AlignmentDirectional.centerStart,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < n; i++)
            if (old[i] == to[i])
              Text(to[i], style: style)
            else
              _RollingChar(
                from: old[i],
                to: to[i],
                style: style,
                rising: rising,
                // Rightmost first, like a real counter.
                t: Curves.easeOutCubic.transform(
                  ((progress - step * (n - 1 - i)) / span).clamp(0.0, 1.0),
                ),
              ),
        ],
      ),
    );
  }
}

/// One character cell: [from] slides out while [to] slides in, clipped to
/// the cell. The cell is sized by [to], so the row ends exactly as wide as
/// the final text.
class _RollingChar extends StatelessWidget {
  const _RollingChar({
    required this.from,
    required this.to,
    required this.style,
    required this.rising,
    required this.t,
  });

  final String from;
  final String to;
  final TextStyle style;
  final bool rising;
  final double t;

  @override
  Widget build(BuildContext context) {
    final dir = rising ? -1.0 : 1.0;
    Widget slide(String c, double dy) => Positioned.fill(
          child: FractionalTranslation(
            translation: Offset(0, dy),
            child: Text(c, style: style, softWrap: false),
          ),
        );
    return ClipRect(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(opacity: 0, child: Text(to, style: style)),
          slide(from, dir * t),
          slide(to, dir * (t - 1)),
        ],
      ),
    );
  }
}
