import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// One destination of [AppNavBar].
@immutable
class AppNavItem {
  const AppNavItem({
    required this.icon,
    required this.label,
    IconData? selectedIcon,
  }) : selectedIcon = selectedIcon ?? icon;

  /// Icon shown while the destination is not selected (outlined style).
  final IconData icon;

  /// Icon shown on the gold capsule while selected (filled style). Defaults
  /// to [icon].
  final IconData selectedIcon;

  /// Short Mongolian label. Visible next to the icon on the selected
  /// capsule, and always used as the screen-reader label.
  final String label;
}

/// Floating, pill-shaped glass bottom navigation bar for the main shell.
///
/// - Frosted surface (backdrop blur + surface at 80%) with a hairline border
///   and a deep floating shadow.
/// - The selected destination sits on a gold gradient capsule showing its
///   icon and label; the capsule slides and stretches between items.
///   Unselected destinations collapse to a [AppColors.textSecondary] icon.
///   Whatever passes under the capsule is drawn in [AppColors.onPrimary]
///   (masked), so icons stay legible mid-slide.
/// - `HapticFeedback.selectionClick` when the selection changes.
/// - Every item is a >= 44pt button with `selected` semantics.
/// - Floats [bottomGap] above the bottom edge, respecting the safe area.
///
/// Designed for `Scaffold(extendBody: true, bottomNavigationBar: AppNavBar())`:
/// the body scrolls underneath the bar and the margins around the pill stay
/// tappable (only the pill itself absorbs hits).
class AppNavBar extends StatefulWidget {
  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;

  /// Height of the pill.
  static const double barHeight = 64;

  /// Gap between the pill edge and the capsule (keeps radii concentric).
  static const double innerPadding = 6;

  /// Narrowest an unselected (icon-only) item gets. Above the 44pt minimum.
  static const double collapsedItemWidth = 56;

  /// Most extra width the selected item takes over the others; the rest of
  /// the free space is shared evenly so icons stay nicely spread out.
  static const double maxSelectedBonus = 96;

  /// Widest the pill gets on tablets / landscape.
  static const double maxWidth = 420;

  /// OS text scaling is capped inside the fixed-height pill.
  static const double maxTextScale = 1.3;

  /// Minimum distance between the pill and the bottom edge of the screen.
  static const double minBottomGap = 12;

  /// Distance between the bottom of the pill and the bottom of the screen.
  ///
  /// On devices with a home indicator (safe-area bottom inset > 0) the pill
  /// sits just above the indicator; otherwise it floats [minBottomGap] up.
  static double bottomGap(double safeBottom) {
    if (!safeBottom.isFinite || safeBottom <= 0) return minBottomGap;
    return math.max(minBottomGap, safeBottom - 8);
  }

  /// Selection weight of each item at animation progress [t] (0..1), moving
  /// from the weights [from] towards selecting index [to].
  ///
  /// Weights of a settled bar are one-hot. Interrupting an animation simply
  /// starts a new one from the current (mixed) weights, so nothing jumps.
  static List<double> weightsAt(List<double> from, int to, double t) {
    final p = t.clamp(0.0, 1.0);
    return [
      for (var i = 0; i < from.length; i++)
        from[i] + ((i == to ? 1.0 : 0.0) - from[i]) * p,
    ];
  }

  /// Width of each item for the given selection [weights].
  ///
  /// The selected item gets a bonus of up to [maxBonus] over the others
  /// (split by weight mid-animation); everything else is shared evenly, and
  /// no item is narrower than [collapsed]. Widths always sum to [available].
  /// When the bar is too narrow for that, the space is split evenly.
  static List<double> itemWidths(
    double available,
    List<double> weights, {
    double collapsed = collapsedItemWidth,
    double maxBonus = maxSelectedBonus,
  }) {
    final n = weights.length;
    if (n == 0) return const [];
    final space = available.isFinite ? math.max(0.0, available) : 0.0;
    final extra = space - n * collapsed;
    if (extra <= 0) return List<double>.filled(n, space / n);
    final bonus = math.min(extra, math.max(0.0, maxBonus));
    final base = (space - bonus) / n;
    final total = weights.fold<double>(0, (s, w) => s + math.max(0.0, w));
    return [
      for (final w in weights)
        base + (total <= 0 ? bonus / n : bonus * math.max(0.0, w) / total),
    ];
  }

  /// Where the gold capsule sits: the weight-blended rect of the items. For
  /// a settled bar this is exactly the selected item's rect.
  static Rect indicatorRect(
    List<double> widths,
    List<double> weights,
    double height,
  ) {
    var left = 0.0;
    var x = 0.0;
    var width = 0.0;
    var total = 0.0;
    for (var i = 0; i < widths.length && i < weights.length; i++) {
      final w = math.max(0.0, weights[i]);
      left += x * w;
      width += widths[i] * w;
      total += w;
      x += widths[i];
    }
    if (total <= 0) return Rect.fromLTWH(0, 0, 0, height);
    return Rect.fromLTWH(left / total, 0, width / total, height);
  }

  @override
  State<AppNavBar> createState() => _AppNavBarState();
}

class _AppNavBarState extends State<AppNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppDurations.medium,
    value: 1,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.standard,
  );

  late List<double> _from = _oneHot(_selected);

  /// Item currently held down (press-scale feedback), if any.
  int? _pressed;

  int get _count => widget.items.length;

  int get _selected => _clampIndex(widget.currentIndex, _count);

  static int _clampIndex(int index, int count) =>
      count == 0 ? 0 : index.clamp(0, count - 1);

  List<double> _oneHot(int index) =>
      [for (var i = 0; i < _count; i++) i == index ? 1.0 : 0.0];

  List<double> get _weights =>
      AppNavBar.weightsAt(_from, _selected, _curve.value);

  @override
  void didUpdateWidget(covariant AppNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _from = _oneHot(_selected);
      _pressed = null;
      _controller.value = 1;
      return;
    }
    final oldSelected = _clampIndex(oldWidget.currentIndex, _count);
    if (oldSelected == _selected) return;
    // Start from wherever the capsule currently is (even mid-flight).
    _from = AppNavBar.weightsAt(_from, oldSelected, _curve.value);
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    if (index != widget.currentIndex) HapticFeedback.selectionClick();
    widget.onTap(index);
  }

  void _setPressed(int? index) {
    if (_pressed == index || !mounted) return;
    setState(() => _pressed = index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final gap = AppNavBar.bottomGap(MediaQuery.paddingOf(context).bottom);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: AppNavBar.maxTextScale,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft fade behind the pill so content scrolling underneath
          // recedes instead of colliding with the bar. Never takes hits.
          const Positioned(
            left: 0,
            right: 0,
            top: -AppSpacing.xxxl,
            bottom: 0,
            child: IgnorePointer(child: _BottomFade()),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppLayout.screenPadding,
              0,
              AppLayout.screenPadding,
              gap,
            ),
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AppNavBar.maxWidth),
                child: _GlassPill(
                  child: SizedBox(
                    height: AppNavBar.barHeight,
                    child: Padding(
                      padding: const EdgeInsets.all(AppNavBar.innerPadding),
                      child: LayoutBuilder(builder: _buildItems),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItems(BuildContext context, BoxConstraints constraints) {
    // The bar always gets a bounded width from the Scaffold; the fallback
    // only keeps it from throwing if it is ever placed in an unbounded box.
    final available = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : _count * AppNavBar.collapsedItemWidth + AppNavBar.maxSelectedBonus;
    final height = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : AppNavBar.barHeight - 2 * AppNavBar.innerPadding;
    final reduced = AppMotion.reduced(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final weights = _weights;
        final widths = AppNavBar.itemWidths(available, weights);
        final indicator = AppNavBar.indicatorRect(widths, weights, height);
        // Tiny "pop" on the icon that is becoming selected.
        final pop = _controller.isAnimating
            ? math.sin(math.pi * _controller.value) * 0.08
            : 0.0;
        final lefts = <double>[];
        var x = 0.0;
        for (final w in widths) {
          lefts.add(x);
          x += w;
        }

        // Icons + labels, drawn twice: textSecondary outside the capsule and
        // onPrimary inside it. Both layers share the exact same layout.
        Widget layer(Color color, {required bool inside}) {
          return Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: ClipPath(
                  clipper: _CapsuleClipper(indicator, inside: inside),
                  child: Stack(
                    children: [
                      for (var i = 0; i < widths.length; i++)
                        Positioned(
                          left: lefts[i],
                          top: 0,
                          bottom: 0,
                          width: widths[i],
                          child: _NavItemContent(
                            item: widget.items[i],
                            weight: weights[i],
                            color: color,
                            pop: i == _selected ? 1 + pop : 1,
                            pressed: _pressed == i && !reduced,
                            reduced: reduced,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return SizedBox(
          width: available,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fromRect(
                rect: indicator,
                child: const _GoldCapsule(),
              ),
              layer(AppColors.textSecondary, inside: false),
              layer(AppColors.onPrimary, inside: true),
              // Hit targets + semantics on top of the visuals.
              for (var i = 0; i < widths.length; i++)
                Positioned(
                  left: lefts[i],
                  top: 0,
                  bottom: 0,
                  width: widths[i],
                  child: _NavHitTarget(
                    label: widget.items[i].label,
                    selected: i == _selected,
                    onTap: () => _handleTap(i),
                    onPressed: (down) => _setPressed(down ? i : null),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Clips to the capsule (rounded ends), or to everything except it.
class _CapsuleClipper extends CustomClipper<Path> {
  const _CapsuleClipper(this.rect, {required this.inside});

  final Rect rect;
  final bool inside;

  @override
  Path getClip(Size size) {
    final capsule = Path()
      ..addRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide / 2)),
      );
    if (inside) return capsule;
    return Path()
      ..fillType = PathFillType.evenOdd
      // Generous bounds so press-scaled content is never cut at the edges.
      ..addRect((Offset.zero & size).inflate(AppNavBar.innerPadding * 2))
      ..addPath(capsule, Offset.zero);
  }

  @override
  bool shouldReclip(_CapsuleClipper oldClipper) =>
      oldClipper.rect != rect || oldClipper.inside != inside;
}

/// Frosted pill surface: blur + translucent surface + top sheen + hairline.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: AppRadii.brPill,
        boxShadow: AppShadows.floating,
      ),
      child: ClipRRect(
        borderRadius: AppRadii.brPill,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.8),
            ),
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: AppGradients.sheen),
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.brPill,
                  border: Border.all(color: AppColors.border),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sliding gold capsule behind the selected item.
class _GoldCapsule extends StatelessWidget {
  const _GoldCapsule();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.gold,
        borderRadius: AppRadii.brPill,
        boxShadow: AppShadows.glow(
          AppColors.primary,
          strength: 0.6,
          blur: 14,
          offset: const Offset(0, 4),
        ),
      ),
      child: DecoratedBox(
        // Lit top edge so the capsule reads as a physical, glossy object.
        decoration: BoxDecoration(
          borderRadius: AppRadii.brPill,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Colors.white.withValues(alpha: 0.25),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Background fade under the floating bar.
class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.background.withValues(alpha: 0),
            AppColors.background.withValues(alpha: 0.6),
          ],
        ),
      ),
    );
  }
}

/// Invisible tap target + semantics for one destination.
class _NavHitTarget extends StatelessWidget {
  const _NavHitTarget({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<bool> onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: (_) => onPressed(true),
        onTapUp: (_) => onPressed(false),
        onTapCancel: () => onPressed(false),
        onTap: onTap,
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// Icon (+ label when selected) for one destination, in a single [color].
class _NavItemContent extends StatelessWidget {
  const _NavItemContent({
    required this.item,
    required this.weight,
    required this.color,
    required this.pop,
    required this.pressed,
    required this.reduced,
  });

  final AppNavItem item;

  /// 0 = collapsed icon, 1 = fully selected capsule.
  final double weight;
  final Color color;

  /// Scale of the selection "pop" (driven every frame by the bar).
  final double pop;

  /// Held down: shrinks slightly (press feedback).
  final bool pressed;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final w = weight.clamp(0.0, 1.0);
    // The label fades in only once the capsule has mostly opened.
    final labelAlpha =
        Curves.easeOut.transform(((w - 0.35) / 0.65).clamp(0.0, 1.0));

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: AnimatedScale(
          scale: pressed ? 0.9 : 1,
          duration: reduced ? Duration.zero : AppDurations.press,
          curve: AppMotion.standard,
          child: Transform.scale(
            scale: pop,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 24,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 24,
                        color: color.withValues(alpha: 1 - w),
                      ),
                      Icon(
                        item.selectedIcon,
                        size: 24,
                        color: color.withValues(alpha: w),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm * w),
                Flexible(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: w,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          fontWeight: FontWeight.w700,
                          color: color.withValues(alpha: labelAlpha),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
