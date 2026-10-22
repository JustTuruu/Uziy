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
import '../../widgets/appearance_settings.dart';
import 'feed_logic.dart';

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// One top row — wordmark, balance pill, appearance button — then the video
/// and survey title. (No time-of-day greeting: owner, 2026-10-21.)
class FeedHeader extends StatelessWidget {
  const FeedHeader({
    super.key,
    required this.balance,
    required this.onBalanceTap,
    this.guest = false,
  });

  /// Null while the profile is loading (the pill shows a placeholder).
  final double? balance;
  final VoidCallback onBalanceTap;

  /// A not-signed-in visitor: the balance pill becomes a 'Нэвтрэх' pill
  /// ([onBalanceTap] then opens sign-in).
  final bool guest;

  static const String title = 'Видео & судалгаа';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const UziyWordmark(),
            const SizedBox(width: AppSpacing.md),
            // The pill takes whatever the wordmark and the button leave; a
            // huge balance scales down inside it instead of pushing the row
            // off screen.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: guest
                    ? GuestSignInPill(onTap: onBalanceTap)
                    : BalancePill(balance: balance, onTap: onBalanceTap),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const ThemeModeButton(),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          child: Text(title, style: context.textStyles.pageTitle),
        ),
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
          color: context.colors.surfaceElevated,
          borderRadius: AppRadii.brPill,
          border:
              Border.all(color: context.colors.primary.withValues(alpha: 0.28)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style:
              context.textStyles.label.copyWith(color: context.colors.primary),
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
          color: context.colors.surfaceElevated,
          borderRadius: AppRadii.brPill,
          border:
              Border.all(color: context.colors.primary.withValues(alpha: 0.28)),
          boxShadow: AppShadows.glow(
            context.colors.primary,
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
                      decoration: BoxDecoration(
                        // One step above the pill's surfaceElevated fill.
                        color: context.colors.surfaceHighlight,
                        borderRadius: AppRadii.brXs,
                      ),
                    )
                  : AnimatedMoney(
                      key: const ValueKey('balance-value'),
                      value: b,
                      memoryKey: MoneyMemory.balance,
                      style: context.textStyles.money.copyWith(fontSize: 15),
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
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: context.colors.textSecondary,
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

/// Compact earnings overview with a counted-up total and
/// '2 видео · 1 судалгаа' underneath and a decorative coin stack.
class EarningsHeroCard extends StatelessWidget {
  const EarningsHeroCard({super.key, required this.summary});

  final FeedSummary summary;

  static const String label = 'Боломжит урамшуулал';

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

  /// Fill, line and inks of the card. Light: a flat forest sheet with white
  /// ink. Dark: the graphite surface with sage money (owner, 2026-10-21: a big
  /// sage block was glaring at night). Flat in both — no gradient.
  static ({Color fill, Color border, Color label, Color money, Color caption})
      lookIn(AppPalette c) => c.isDark
          ? (
              fill: c.surfaceElevated,
              border: c.border,
              label: c.textSecondary,
              money: c.primary,
              caption: c.textSecondary,
            )
          : (
              fill: c.primary,
              border: Colors.transparent,
              label: c.onPrimary,
              money: c.onPrimary,
              caption: c.onPrimary.withValues(alpha: 0.8),
            );

  @override
  Widget build(BuildContext context) {
    final caption = summaryCaption(summary);
    final look = lookIn(context.colors);

    return MergeSemantics(
      child: AppCard(
        padding: EdgeInsets.zero,
        color: look.fill,
        radius: AppRadii.xl,
        borderColor: look.border,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showCoins = showsCoins(
              constraints.maxWidth,
              MediaQuery.textScalerOf(context).scale(16) / 16,
            );
            return Padding(
              padding: _padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: context.textStyles.label
                                    .copyWith(color: look.label)),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: AnimatedMoney(
                                value: summary.totalReward,
                                style: context.textStyles.moneyLarge
                                    .copyWith(color: look.money, fontSize: 32),
                              ),
                            ),
                            if (caption.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(caption,
                                  style: context.textStyles.caption
                                      .copyWith(color: look.caption)),
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
                ],
              ),
            );
          },
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

// ---------------------------------------------------------------------------
// Filter
// ---------------------------------------------------------------------------

/// 'Бүгд / Видео / Судалгаа' as three separate chips, each with its icon and
/// its name, so the choice reads at a glance (owner, 2026-10-21: the old box
/// of three small words was hard to read). The counts live in the hero card
/// right above ('2 видео · 1 судалгаа'), so the chips do not repeat them.
/// The selected chip is a flat action-colour fill; changing the selection
/// plays a selection haptic. Each chip is a 44pt target.
class FeedFilterBar extends StatelessWidget {
  const FeedFilterBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final FeedFilter value;
  final ValueChanged<FeedFilter> onChanged;

  static const double height = 44;

  static IconData iconFor(FeedFilter f) => switch (f) {
        FeedFilter.all => AppIcons.feedAll,
        FeedFilter.video => AppIcons.feedVideo,
        FeedFilter.survey => AppIcons.feedSurvey,
      };

  @override
  Widget build(BuildContext context) {
    // Each chip takes its own width, so every label keeps the same size; a
    // narrow screen or large text scrolls the row sideways instead of
    // shrinking one chip's words.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (i, f) in FeedFilter.values.indexed) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            FeedFilterChip(
              icon: iconFor(f),
              label: feedFilterLabel(f),
              selected: f == value,
              onTap: () {
                if (f == value) return;
                HapticFeedback.selectionClick();
                onChanged(f);
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// One chip of [FeedFilterBar].
class FeedFilterChip extends StatelessWidget {
  const FeedFilterChip({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = selected ? c.onPrimary : c.textSecondary;
    final duration = AppMotion.duration(context, AppDurations.fast);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        scale: 0.96,
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.standard,
          height: FeedFilterBar.height,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: selected ? c.primary : c.surface,
            borderRadius: AppRadii.brPill,
            border: Border.all(
              color: selected ? c.primary : c.borderStrong,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: ink),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                style: context.textStyles.label.copyWith(
                  color: selected ? c.onPrimary : c.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Campaign card
// ---------------------------------------------------------------------------

/// Artwork, then the publisher with the reward beside it, then the headline.
/// The entire card is one accessible button (no separate action button).
class CampaignCard extends StatelessWidget {
  const CampaignCard({super.key, required this.campaign, required this.onTap});

  final Campaign campaign;
  final VoidCallback onTap;

  /// Narrowest text column (at 1.0x text) that keeps the publisher and the
  /// reward on one line.
  static const double minInlineWidth = 260;

  /// Text scale above which the reward moves under the publisher.
  static const double maxInlineTextScale = 1.5;

  /// Whether the reward goes on its own line under the publisher.
  static bool stacksReward(double width, double textScale) =>
      width < minInlineWidth * textScale.clamp(1.0, 2.0) ||
      textScale > maxInlineTextScale;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final company = c.companyName.trim();
    return Pressable(
      onTap: onTap,
      scale: 0.985,
      haptic: true,
      semanticLabel: campaignSemanticLabel(c),
      excludeSemantics: true,
      child: AppCard(
        padding: EdgeInsets.zero,
        radius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _CardArt(campaign: c),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Who pays and what they pay share one line (the reward
                  // drops under the name when the line is too tight). The
                  // whole card is the button, so it carries no action button
                  // of its own (owner, 2026-10-21).
                  LayoutBuilder(builder: (context, constraints) {
                    final publisher = Row(children: [
                      if (company.isNotEmpty) ...[
                        _CompanyAvatar(campaignId: c.id, companyName: company),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          company,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.caption.copyWith(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ]);
                    final reward = RewardChip(amount: c.rewardPerUser);
                    if (stacksReward(constraints.maxWidth,
                        MediaQuery.textScalerOf(context).scale(14) / 14)) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (company.isNotEmpty) ...[
                            publisher,
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          reward,
                        ],
                      );
                    }
                    return Row(children: [
                      Expanded(child: publisher),
                      const SizedBox(width: AppSpacing.sm),
                      reward,
                    ]);
                  }),
                  const SizedBox(height: 12),
                  CardTitle(title: c.title),
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
          style: headlineStyle.copyWith(color: context.colors.textPrimary),
        ),
        if (tagline != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            tagline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: taglineStyle.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _CardArt extends StatelessWidget {
  const _CardArt({required this.campaign});

  final Campaign campaign;

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
        Positioned(
          left: 14,
          bottom: 14,
          child: _Medallion(hasVideo: c.hasVideo),
        ),
        Positioned(
          right: 12,
          bottom: 16,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: RewardChip.maxTextScale,
            child: TagChip(
              label: campaignKindLabel(c),
              icon:
                  c.hasVideo ? Icons.schedule_rounded : Icons.checklist_rounded,
              tone: TagTone.glass,
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
          width: 44,
          height: 44,
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
                    size: 28,
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

// ---------------------------------------------------------------------------
// Loading skeletons
// ---------------------------------------------------------------------------

/// Loading placeholder follows the artwork, publisher and reward hierarchy.
class CampaignCardSkeleton extends StatelessWidget {
  const CampaignCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(color: context.colors.surfaceElevated),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Skeleton(width: 24, height: 24, radius: 12),
                  SizedBox(width: 8),
                  Skeleton(width: 88, height: 12),
                ]),
                SizedBox(height: 12),
                Skeleton(height: 22),
                SizedBox(height: 8),
                Skeleton(width: 160, height: 16),
                SizedBox(height: 32),
                Row(children: [
                  Expanded(child: Skeleton(height: 44, radius: 12)),
                  SizedBox(width: 32),
                  Skeleton(width: 82, height: 44, radius: 12),
                ]),
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
