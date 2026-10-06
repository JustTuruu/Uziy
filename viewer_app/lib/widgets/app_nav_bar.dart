import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// One destination of [AppNavBar].
@immutable
class AppNavItem {
  /// Either [icon] (a Material icon, optionally with a filled [selectedIcon])
  /// or a custom [glyphBuilder] must be given.
  const AppNavItem({
    this.icon,
    this.glyphBuilder,
    required this.label,
    IconData? selectedIcon,
  })  : selectedIcon = selectedIcon ?? icon,
        assert(
          icon != null || glyphBuilder != null,
          'AppNavItem needs an icon or a glyphBuilder',
        );

  /// Icon shown while the destination is not selected (outlined style).
  final IconData? icon;

  /// Icon shown while selected (filled style). Defaults to [icon].
  final IconData? selectedIcon;

  /// Custom-drawn glyph (for icons Material doesn't have). Receives the
  /// colour to draw in and whether the destination is selected. Takes
  /// precedence over [icon].
  final Widget Function(Color color, bool selected)? glyphBuilder;

  /// Short Mongolian label, always shown under the icon (and used as the
  /// screen-reader label).
  final String label;
}

/// Floating, pill-shaped glass bottom navigation bar for the main shell.
///
/// Static and fixed: every destination gets an equal slice of the pill, with
/// its icon on top and its label underneath. The selected destination is
/// shown in [AppColors.primary] (filled icon); the others in
/// [AppColors.textSecondary]. Nothing slides or animates.
///
/// - Frosted surface (backdrop blur + surface at 80%) with a hairline border
///   and a deep floating shadow.
/// - `HapticFeedback.selectionClick` when the selection changes.
/// - Every item is a >= 44pt button with `selected` semantics.
/// - Floats [bottomGap] above the bottom edge, respecting the safe area.
///
/// Designed for `Scaffold(extendBody: true, bottomNavigationBar: AppNavBar())`:
/// the body scrolls underneath the bar and the margins around the pill stay
/// tappable (only the pill itself absorbs hits).
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<AppNavItem> items;

  /// Height of the pill (icon over label).
  static const double barHeight = 68;

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

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final selected = currentIndex.clamp(0, items.length - 1);
    final gap = bottomGap(MediaQuery.paddingOf(context).bottom);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxTextScale,
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
                constraints: const BoxConstraints(maxWidth: maxWidth),
                child: _GlassPill(
                  child: SizedBox(
                    height: barHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < items.length; i++)
                          Expanded(
                            child: _NavButton(
                              item: items[i],
                              selected: i == selected,
                              onTap: () {
                                if (i != selected) {
                                  HapticFeedback.selectionClick();
                                }
                                onTap(i);
                              },
                            ),
                          ),
                      ],
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

/// One destination: icon with its label underneath, plus tap + semantics.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            item.glyphBuilder?.call(color, selected) ??
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 24,
                  color: color,
                ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label.copyWith(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
