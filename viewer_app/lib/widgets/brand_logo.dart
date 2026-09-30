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
                AppColors.primary,
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
