/// Presentational building blocks for the home feed.
///
/// Stateless, callback-driven, and free of routing / services, so every
/// piece can be widget-tested without the router (this file must never
/// import routes/app_router.dart).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/campaign.dart';
import '../../widgets/ui.dart';
import 'feed_logic.dart';

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// Greeting line + balance pill, then the big 'Шинэ видеонууд' title and a
/// one-line explainer.
class FeedHeader extends StatelessWidget {
  const FeedHeader({
    super.key,
    required this.now,
    required this.balance,
    required this.onBalanceTap,
    this.guest = false,
  });

  /// Drives the greeting ('Өглөөний мэнд', ...). Injected for tests.
  final DateTime now;

  /// Null while the profile is loading (the pill shows a placeholder).
  final double? balance;
  final VoidCallback onBalanceTap;

  /// A not-signed-in visitor: the balance pill becomes a 'Нэвтрэх' pill
  /// ([onBalanceTap] then opens sign-in).
  final bool guest;

  static const String title = 'Шинэ видеонууд';
  static const String subtitle = 'Үзэж, хариулж, урамшуулал аваарай';

  /// Share of the header width the balance pill may use.
  static const double pillMaxWidthFactor = 0.62;

  static IconData iconFor(DayPart part) => switch (part) {
        DayPart.morning => Icons.wb_twilight_rounded,
        DayPart.afternoon => Icons.wb_sunny_rounded,
        DayPart.evening => Icons.nights_stay_rounded,
        DayPart.night => Icons.bedtime_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final part = dayPartOf(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(iconFor(part), size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        greetingFor(part),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // The pill may take most of the row; a huge balance scales
              // down inside it instead of pushing the row off screen.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: box.maxWidth * pillMaxWidthFactor,
                ),
                child: guest
                    ? GuestSignInPill(onTap: onBalanceTap)
                    : BalancePill(balance: balance, onTap: onBalanceTap),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Semantics(
          header: true,
          child: const Text(title, style: AppTextStyles.display),
        ),
        const SizedBox(height: 6),
        const Text(subtitle, style: AppTextStyles.bodySmall),
      ],
    );
  }
}

/// Header pill for a guest: a gold 'Нэвтрэх' call to action.
class GuestSignInPill extends StatelessWidget {
  const GuestSignInPill({super.key, required this.onTap});

  final VoidCallback onTap;

  static const String label = 'Нэвтрэх';

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.95,
      semanticLabel: label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppLayout.minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadii.brPill,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Wallet shortcut in the header: coin + counting balance + chevron.
class BalancePill extends StatelessWidget {
  const BalancePill({super.key, required this.balance, required this.onTap});

  /// Null shows a static placeholder bar instead of a number.
  final double? balance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = balance;
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.95,
      semanticLabel:
          b == null ? 'Хэтэвч' : 'Хэтэвч, үлдэгдэл ${formatTugrik(b)}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppLayout.minTapTarget),
        padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadii.brPill,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
          boxShadow: AppShadows.glow(
            AppColors.primary,
            strength: 0.25,
            blur: 18,
            offset: const Offset(0, 4),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final Widget amount = AnimatedSwitcher(
              duration: AppMotion.duration(context, AppDurations.normal),
              child: b == null
                  ? Container(
                      key: const ValueKey('balance-placeholder'),
                      width: 52,
                      height: 14,
                      decoration: const BoxDecoration(
                        // One step above the pill's surfaceElevated fill.
                        color: AppColors.surfaceHighlight,
                        borderRadius: AppRadii.brXs,
                      ),
                    )
                  : AnimatedMoney(
                      key: const ValueKey('balance-value'),
                      value: b,
                      style: AppTextStyles.money.copyWith(fontSize: 15),
                    ),
            );
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinIcon(size: 26),
                const SizedBox(width: AppSpacing.sm),
                // With a width cap (the header) the amount scales down to
                // fit; with no cap it simply hugs its text.
                if (box.hasBoundedWidth)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: amount,
                    ),
                  )
                else
                  amount,
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Earning-potential hero
// ---------------------------------------------------------------------------

/// Gold hero card: what the whole current feed is worth, counted up, with
/// '2 видео · 1 судалгаа' underneath and a decorative coin stack.
class EarningsHeroCard extends StatelessWidget {
  const EarningsHeroCard({super.key, required this.summary});

  final FeedSummary summary;

  static const String label = 'Өнөөдөр олох боломж';

  /// Width the decorative coin stack takes, including its gap.
  static const double _coinsReserve = 78 + AppSpacing.md;

  /// Text column width (at 1.0x text) the coin stack must leave free; scaled
  /// by the OS text size. A 320pt phone keeps the coins at 1.0x and drops
  /// them at 1.3x.
  static const double minTextColumn = 150;

  /// Whether a card [width] wide has room for the coin stack at
  /// [textScale].
  static bool showsCoins(double width, double textScale) =>
      width - _padding.horizontal - _coinsReserve >= minTextColumn * textScale;

  static const EdgeInsets _padding = EdgeInsets.fromLTRB(20, 18, 16, 20);

  @override
  Widget build(BuildContext context) {
    final caption = summaryCaption(summary);
    const ink = AppColors.onPrimary;

    return MergeSemantics(
      child: AppCard(
        padding: EdgeInsets.zero,
        gradient: AppGradients.gold,
        borderColor: Colors.white.withValues(alpha: 0.30),
        shadows: AppShadows.glow(
          AppColors.primary,
          strength: 0.55,
          blur: 30,
          offset: const Offset(0, 12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showCoins = showsCoins(
              constraints.maxWidth,
              MediaQuery.textScalerOf(context).scale(16) / 16,
            );
            return Stack(
              children: [
                const Positioned(
                  right: -56,
                  top: -64,
                  child: _Ring(size: 190),
                ),
                const Positioned(
                  right: -14,
                  bottom: -46,
                  child: _Ring(size: 120),
                ),
                Padding(
                  padding: _padding,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: AppTextStyles.label.copyWith(
                                color: ink.withValues(alpha: 0.72),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: AnimatedMoney(
                                value: summary.totalReward,
                                style: AppTextStyles.moneyLarge
                                    .copyWith(color: ink),
                              ),
                            ),
                            if (caption.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: ink.withValues(alpha: 0.10),
                                  borderRadius: AppRadii.brPill,
                                ),
                                child: Text(
                                  caption,
                                  style: AppTextStyles.caption.copyWith(
                                    color: ink.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: AppTextStyles.tabular,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (showCoins) ...[
                        const SizedBox(width: AppSpacing.md),
                        const _CoinStack(),
                      ],
                    ],
                  ),
                ),
                const Positioned.fill(child: _SheenSweep()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
    );
  }
}

class _CoinStack extends StatelessWidget {
  const _CoinStack();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: 78,
        height: 72,
        child: Stack(
          children: [
            Positioned(right: 0, top: 0, child: CoinIcon(size: 54)),
            Positioned(left: 0, bottom: 0, child: CoinIcon(size: 36)),
          ],
        ),
      ),
    );
  }
}

/// One-shot diagonal light sweep across the gold card on mount.
/// Reduce-motion: nothing is painted.
class _SheenSweep extends StatelessWidget {
  const _SheenSweep();

  static const Duration duration = Duration(milliseconds: 1600);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: AppMotion.duration(context, duration),
        curve: const Interval(0.35, 1, curve: Curves.easeInOutCubic),
        builder: (context, t, _) {
          if (t <= 0 || t >= 1) return const SizedBox.shrink();
          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(-1, -0.6),
                end: const Alignment(1, 0.6),
                colors: [
                  Colors.white.withValues(alpha: 0),
                  Colors.white.withValues(alpha: 0.38),
                  Colors.white.withValues(alpha: 0),
                ],
                stops: const [0.42, 0.5, 0.58],
                transform: _SweepTransform(t),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SweepTransform extends GradientTransform {
  const _SweepTransform(this.t);

  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * 1.2 * (t * 2 - 1), 0, 0);
}

// ---------------------------------------------------------------------------
// Filter
// ---------------------------------------------------------------------------

/// 'Бүгд / Видео / Судалгаа' segmented control with a sliding gold pill.
/// Each segment is a full-height (48) tap target; changing the selection
/// plays a selection haptic.
class FeedFilterBar extends StatelessWidget {
  const FeedFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final FeedFilter value;
  final ValueChanged<FeedFilter> onChanged;

  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    const filters = FeedFilter.values;
    final n = filters.length;
    final index = filters.indexOf(value);
    final duration = AppMotion.duration(context, AppDurations.normal);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.brPill,
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: AnimatedAlign(
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
              duration: duration,
              curve: AppMotion.standard,
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.gold,
                    borderRadius: AppRadii.brPill,
                    boxShadow: AppShadows.glow(
                      AppColors.primary,
                      strength: 0.45,
                      blur: 12,
                      offset: const Offset(0, 3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final f in filters)
                Expanded(
                  child: _FilterSegment(
                    label: feedFilterLabel(f),
                    selected: f == value,
                    duration: duration,
                    onTap: () {
                      if (f == value) return;
                      HapticFeedback.selectionClick();
                      onChanged(f);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterSegment extends StatelessWidget {
  const _FilterSegment({
    required this.label,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: duration,
                curve: AppMotion.standard,
                // Merge onto the inherited style: AnimatedDefaultTextStyle
                // replaces it outright, which would drop the theme's font.
                style: DefaultTextStyle.of(context).style.merge(
                      AppTextStyles.label.copyWith(
                        color: selected
                            ? AppColors.onPrimary
                            : AppColors.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                child: Text(label, maxLines: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Campaign card
// ---------------------------------------------------------------------------

/// Feed card: 16:9 art with duration / reward chips and a play (or survey)
/// medallion, then title, company and a subtle 'Үзэх' / 'Бөглөх' CTA.
/// The whole card is one button with a single screen-reader sentence.
class CampaignCard extends StatelessWidget {
  const CampaignCard({super.key, required this.campaign, required this.onTap});

  final Campaign campaign;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final company = c.companyName.trim();

    return Pressable(
      onTap: onTap,
      scale: 0.98,
      semanticLabel: campaignSemanticLabel(c),
      excludeSemantics: true,
      child: AppCard(
        padding: EdgeInsets.zero,
        shadows: AppShadows.soft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _CardArt(campaign: c),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  CardTitle(title: c.title),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: company.isEmpty
                            ? const SizedBox.shrink()
                            : Row(
                                children: [
                                  _CompanyAvatar(
                                    campaignId: c.id,
                                    companyName: company,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Flexible(
                                    child: Text(
                                      company,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 15,
                                    color: AppColors.accent,
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _CardCta(label: campaignCtaLabel(c)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card title: the headline big and bold, the tagline underneath in a
/// lighter, smaller weight. A title without a separator is just the headline.
class CardTitle extends StatelessWidget {
  const CardTitle({super.key, required this.title});

  final String title;

  static const TextStyle headlineStyle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle taglineStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) {
    final parts = splitCampaignTitle(title);
    final tagline = parts.tagline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          parts.headline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: headlineStyle,
        ),
        if (tagline != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            tagline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: taglineStyle,
          ),
        ],
      ],
    );
  }
}

class _CardArt extends StatelessWidget {
  const _CardArt({required this.campaign});

  final Campaign campaign;

  /// Below this width the kind tag shows its label only.
  static const double _tagIconMinWidth = 72;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    return Stack(
      fit: StackFit.expand,
      children: [
        CampaignArt(
          campaignId: c.id,
          companyName: c.companyName,
          thumbnailUrl: c.thumbnailUrl,
          hasVideo: c.hasVideo,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(gradient: AppGradients.scrimBottom),
        ),
        Center(child: _Medallion(hasVideo: c.hasVideo)),
        Positioned(
          top: AppSpacing.md,
          left: AppSpacing.md,
          right: AppSpacing.md,
          // Badges on artwork stop growing past 1.3x OS text size (the
          // RewardChip caps itself the same way).
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: RewardChip.maxTextScale,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  // The reward wins the space; when the kind tag is left
                  // with too little room it drops its icon and ellipsizes.
                  child: LayoutBuilder(
                    builder: (context, box) => TagChip(
                      label: campaignKindLabel(c),
                      icon: box.maxWidth < _tagIconMinWidth
                          ? null
                          : (c.hasVideo
                              ? Icons.schedule_rounded
                              : Icons.checklist_rounded),
                      tone: TagTone.glass,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                RewardChip(amount: c.rewardPerUser, glow: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Glass play button (video) or checklist badge (survey-only) in the middle
/// of the art. Decorative: the card itself is the button.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.hasVideo});

  final bool hasVideo;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
        ),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.38),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: hasVideo
              ? const Padding(
                  // Optical centering: the triangle's mass sits left.
                  padding: EdgeInsets.only(left: 3),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.checklist_rounded,
                  size: 28,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }
}

class _CompanyAvatar extends StatelessWidget {
  const _CompanyAvatar({required this.campaignId, required this.companyName});

  final int campaignId;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    final palette = campaignPalette(campaignId);
    return ExcludeSemantics(
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette[0], palette[1]],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        alignment: Alignment.center,
        child: Text(
          monogramOf(companyName),
          maxLines: 1,
          // Fixed-size badge: size from the circle, not the OS text setting.
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            fontSize: 11,
            height: 1.0,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CardCta extends StatelessWidget {
  const _CardCta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: AppRadii.brPill,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            style: AppTextStyles.label.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          const Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeletons
// ---------------------------------------------------------------------------

/// Static placeholder with the exact shape of a [CampaignCard]. Put it
/// inside a [SkeletonShimmer] (see [FeedSkeleton]).
class CampaignCardSkeleton extends StatelessWidget {
  const CampaignCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.brLg,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: AppColors.surfaceElevated),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Skeleton(height: 16),
                SizedBox(height: AppSpacing.sm),
                Skeleton(width: 160, height: 16),
                SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Skeleton(width: 24, height: 24, radius: 12),
                    SizedBox(width: AppSpacing.sm),
                    Skeleton(width: 88, height: 12),
                    Spacer(),
                    Skeleton(width: 72, height: 32, radius: AppRadii.pill),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading layout for the feed body: hero, filter bar and [cardCount]
/// cards, all under one shimmer.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key, this.cardCount = 2});

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Skeleton(height: 132, radius: AppRadii.lg),
          const SizedBox(height: AppSpacing.xl),
          const Skeleton(height: FeedFilterBar.height, radius: AppRadii.pill),
          for (var i = 0; i < cardCount; i++) ...[
            const SizedBox(height: AppSpacing.lg),
            const CampaignCardSkeleton(),
          ],
        ],
      ),
    );
  }
}
