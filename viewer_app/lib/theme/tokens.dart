import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Design tokens for the "Gold Noir" design system.
///
/// Screens should reach for these instead of magic numbers / raw hex values.
/// Colors live on [AppColors] (app_theme.dart); everything else lives here.
/// `app_theme.dart` re-exports this file, so importing either one is enough.

/// Corner radii. 12 / 16 / 20 / 28 / pill.
abstract final class AppRadii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius brXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius brSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius brMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius brLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius brXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius brPill = BorderRadius.all(Radius.circular(pill));

  /// Top-only radius used by bottom sheets.
  static const BorderRadius sheetTop =
      BorderRadius.vertical(top: Radius.circular(xl));
}

/// 4pt spacing grid.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
}

/// Motion durations. Keep UI motion within 150–450 ms; count-up and
/// celebratory effects may run longer.
abstract final class AppDurations {
  static const Duration press = Duration(milliseconds: 110);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 350);
  static const Duration slow = Duration(milliseconds: 450);

  /// Delay between consecutive items in a staggered list entrance.
  static const Duration stagger = Duration(milliseconds: 55);

  /// Money count-up (AnimatedMoney).
  static const Duration countUp = Duration(milliseconds: 900);

  /// One confetti burst.
  static const Duration confetti = Duration(milliseconds: 1800);

  /// One skeleton shimmer sweep.
  static const Duration shimmer = Duration(milliseconds: 1400);
}

/// Curves + reduce-motion helpers.
abstract final class AppMotion {
  static const Curve standard = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeOutBack;

  /// True when the OS "reduce motion" / "remove animations" setting is on.
  /// Safe to call without a MediaQuery ancestor (returns false).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], or [Duration.zero] when reduce-motion is on.
  static Duration duration(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Shadow + glow recipes.
abstract final class AppShadows {
  /// Soft colored glow, e.g. under gold CTAs and reward elements.
  /// [strength] scales opacity (1.0 = default, 0 = invisible).
  static List<BoxShadow> glow(
    Color color, {
    double strength = 1.0,
    double blur = 24,
    double spread = 0,
    Offset offset = const Offset(0, 8),
  }) {
    double a(double base) => (base * strength).clamp(0.0, 1.0);
    return [
      BoxShadow(
        color: color.withValues(alpha: a(0.34)),
        blurRadius: blur,
        spreadRadius: spread,
        offset: offset,
      ),
      BoxShadow(
        color: color.withValues(alpha: a(0.14)),
        blurRadius: blur * 2.4,
        spreadRadius: spread,
        offset: offset * 0.5,
      ),
    ];
  }

  /// Standard gold CTA glow.
  static final List<BoxShadow> goldGlow = glow(AppColors.primary);

  /// Deep drop shadow for floating surfaces (nav bar, sheets, cards on art).
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x73000000), blurRadius: 32, offset: Offset(0, 16)),
  ];

  /// Subtle lift for cards.
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
}

/// Gradients. Gold is the signature — use [gold] for primary CTAs, reward
/// chips, the wallet balance card.
abstract final class AppGradients {
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryLight, AppColors.primary, AppColors.primaryDeep],
    stops: [0.0, 0.45, 1.0],
  );

  /// Tinted translucent gold for highlighted (non-CTA) panels.
  static const LinearGradient goldSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33FFCE00), Color(0x0FFFCE00)],
  );

  /// Top highlight laid over cards — gives surfaces a lit top edge.
  static const LinearGradient sheen = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment(0, 0.2),
    colors: [Color(0x0FFFFFFF), Color(0x00FFFFFF)],
  );

  /// Elevated surface gradient (surfaceElevated -> surface).
  static const LinearGradient surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.surfaceElevated, AppColors.surface],
  );

  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.successLight, AppColors.success, AppColors.successDeep],
    stops: [0.0, 0.5, 1.0],
  );

  /// Bottom scrim for text over imagery / video.
  static const LinearGradient scrimBottom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x00000000), Color(0xB3000000)],
    stops: [0.45, 1.0],
  );

  /// Curated rich, dark-friendly brand gradients for generated campaign art
  /// (see `campaignPalette()` in widgets/campaign_art.dart). Each entry is
  /// [bright, mid, deep], painted top-left -> bottom-right.
  static const List<List<Color>> campaignPalettes = [
    [Color(0xFF3056D3), Color(0xFF182B72), Color(0xFF0B1030)], // royal blue
    [Color(0xFF7443DB), Color(0xFF351A73), Color(0xFF120A2A)], // violet
    [Color(0xFF0F9A6E), Color(0xFF0B4B3B), Color(0xFF061A16)], // emerald
    [Color(0xFFC62A4E), Color(0xFF5E1328), Color(0xFF1C0810)], // crimson
    [Color(0xFFD29200), Color(0xFF5C3F00), Color(0xFF1C1403)], // amber gold
    [Color(0xFF1296B0), Color(0xFF0A4A5C), Color(0xFF06171E)], // teal
    [Color(0xFFC53A82), Color(0xFF5A1A55), Color(0xFF1A0A1E)], // magenta
    [Color(0xFF5264B8), Color(0xFF262D52), Color(0xFF0E1020)], // indigo steel
  ];
}

/// Type scale. Uses the platform system font (SF Pro on iOS). Money styles
/// use tabular figures so digits don't jitter while counting.
abstract final class AppTextStyles {
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static const TextStyle display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.0,
    height: 1.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.15,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: AppColors.textPrimary,
  );

  /// Secondary paragraph text (13, textSecondary).
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.2,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  /// Small uppercase-ish section label (11, w700, tracked out).
  static const TextStyle overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.9,
    height: 1.2,
    color: AppColors.textSecondary,
  );

  static const TextStyle money = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    height: 1.2,
    color: AppColors.textPrimary,
    fontFeatures: tabular,
  );

  static const TextStyle moneyLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    letterSpacing: -1.2,
    height: 1.05,
    color: AppColors.textPrimary,
    fontFeatures: tabular,
  );
}

/// Layout constants.
abstract final class AppLayout {
  /// Horizontal screen gutter.
  static const double screenPadding = 20;

  static const EdgeInsets screenInsets =
      EdgeInsets.symmetric(horizontal: screenPadding);

  /// Minimum interactive size (iOS HIG 44pt).
  static const double minTapTarget = 44;

  /// Cap for content width on tablets / landscape.
  static const double maxContentWidth = 560;

  /// Bottom padding for scrollables on tab screens that sit under the
  /// floating nav bar. When the shell's Scaffold uses `extendBody: true`, the
  /// nav bar's height is already folded into `MediaQuery.paddingOf(context)
  /// .bottom`, so this is that inset + 24.
  static double scrollBottomPadding(BuildContext context) =>
      MediaQuery.paddingOf(context).bottom + 24;
}
