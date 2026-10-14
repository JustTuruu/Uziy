import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The Uziy logo (assets/logo.png) on a white rounded tile with a soft gold
/// glow. Used by splash and auth screens.
///
/// Pass the same [heroTag] on two screens to fly the logo between them.
class UziyLogo extends StatelessWidget {
  const UziyLogo({
    super.key,
    this.size = 96,
    this.glow = true,
    this.heroTag,
  });

  final double size;
  final bool glow;
  final Object? heroTag;

  static const String assetPath = 'assets/logo.png';

  @override
  Widget build(BuildContext context) {
    Widget tile = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.125),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: glow
            ? AppShadows.glow(
                context.colors.primary,
                strength: 1.0,
                blur: size * 0.4,
                offset: Offset(0, size * 0.06),
              )
            : null,
      ),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        semanticLabel: 'Uziy',
      ),
    );
    if (heroTag != null) tile = Hero(tag: heroTag!, child: tile);
    return tile;
  }
}

/// The app-bar brand: the bare Uziy mark followed by the 'uziy' name, both in
/// the theme's text colour, so it reads as dark-on-light and light-on-dark
/// instead of a white tile glaring out of the dark theme.
class UziyWordmark extends StatelessWidget {
  const UziyWordmark({super.key, this.height = 28, this.color});

  /// Height of the mark; the name is sized to match it.
  final double height;

  /// Ink override for fixed artwork (e.g. white on the wallet card); the
  /// theme's text colour otherwise.
  final Color? color;

  /// The mark alone on transparency (from assets/logo.png), tinted at runtime.
  static const String markAssetPath = 'assets/logo_mark.png';
  static const String name = 'uziy';

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.colors.textPrimary;
    return Semantics(
      label: 'Uziy',
      header: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            markAssetPath,
            height: height,
            color: color,
            colorBlendMode: BlendMode.srcIn,
            filterQuality: FilterQuality.medium,
          ),
          SizedBox(width: height * 0.3),
          Text(
            name,
            textScaler: TextScaler.noScaling,
            style: context.textStyles.headline.copyWith(
              color: color,
              fontSize: height * 0.92,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
