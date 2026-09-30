import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/ui.dart';
import 'wallet_logic.dart';

// Presentational widgets for the wallet tab and the payout form.
//
// Nothing here imports the router or a service, so every widget can be
// pumped on its own in widget tests.

// --- Balance card -----------------------------------------------------------

/// The hero gold card on the wallet tab: coin, 'Одоогийн үлдэгдэл', the
/// balance counting up, the verification badge and, while the balance is
/// still under the payout minimum, a progress meter toward it.
class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.verified,
    this.progress,
  });

  final num balance;
  final bool verified;

  /// Shown as a meter when set and the minimum is not reached yet.
  final PayoutProgress? progress;

  static const String balanceLabel = 'Одоогийн үлдэгдэл';

  @override
  Widget build(BuildContext context) {
    final meter = progress;
    const ink = AppColors.onPrimary;

    return AppCard(
      gradient: AppGradients.gold,
      radius: AppRadii.xl,
      padding: EdgeInsets.zero,
      borderColor: Colors.white.withValues(alpha: 0.30),
      shadows: AppShadows.glow(
        AppColors.primary,
        strength: 0.75,
        blur: 30,
        offset: const Offset(0, 14),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _CardEngravingPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CoinIcon(size: 28),
                          const SizedBox(width: AppSpacing.sm + 2),
                          Expanded(
                            child: Text(
                              balanceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.label.copyWith(
                                color: ink.withValues(alpha: 0.72),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md + 2),
                      // Scales down instead of overflowing for very large
                      // balances or big OS text sizes.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedMoney(
                          value: balance,
                          style: AppTextStyles.moneyLarge.copyWith(
                            color: ink,
                            fontSize: 42,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md + 2),
                WalletVerifiedBadge(verified: verified),
                if (meter != null && !meter.reached) ...[
                  const SizedBox(height: AppSpacing.lg + 2),
                  Container(height: 1, color: ink.withValues(alpha: 0.10)),
                  const SizedBox(height: AppSpacing.md + 2),
                  PayoutProgressMeter(progress: meter),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill on the gold card: solid dark 'Баталгаажсан' or outlined
/// 'Баталгаажаагүй'.
class WalletVerifiedBadge extends StatelessWidget {
  const WalletVerifiedBadge({super.key, required this.verified});

  final bool verified;

  static const String verifiedLabel = 'Баталгаажсан';
  static const String unverifiedLabel = 'Баталгаажаагүй';

  @override
  Widget build(BuildContext context) {
    const ink = AppColors.onPrimary;
    final label = verified ? verifiedLabel : unverifiedLabel;
    return Semantics(
      label: 'Бүртгэл: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
        decoration: BoxDecoration(
          color: verified
              ? ink.withValues(alpha: 0.88)
              : ink.withValues(alpha: 0.07),
          borderRadius: AppRadii.brPill,
          border: Border.all(
            color: verified ? Colors.transparent : ink.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Icons.verified_rounded : Icons.shield_outlined,
              size: 15,
              color: verified ? AppColors.primary : ink,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: verified ? AppColors.primaryLight : ink,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 'Мөнгө татахад 600 ₮ дутуу' + percent + an engraved bar. Designed to sit
/// on the gold balance card (dark ink on gold).
class PayoutProgressMeter extends StatelessWidget {
  const PayoutProgressMeter({super.key, required this.progress});

  final PayoutProgress progress;

  /// 'Мөнгө татахад 600 ₮ дутуу'.
  static String labelFor(PayoutProgress p) =>
      'Мөнгө татахад ${formatTugrik(p.remaining)} дутуу';

  @override
  Widget build(BuildContext context) {
    const ink = AppColors.onPrimary;
    final percent = (progress.fraction * 100).floor();
    final label = labelFor(progress);

    return Semantics(
      label: label,
      value: '$percent%',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.label.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$percent%',
                style: AppTextStyles.label.copyWith(
                  color: ink.withValues(alpha: 0.68),
                  fontWeight: FontWeight.w700,
                  fontFeatures: AppTextStyles.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          _MeterBar(fraction: progress.fraction),
        ],
      ),
    );
  }
}

class _MeterBar extends StatelessWidget {
  const _MeterBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    const ink = AppColors.onPrimary;
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.12),
        borderRadius: AppRadii.brPill,
      ),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
        duration: AppMotion.duration(context, AppDurations.countUp),
        curve: AppMotion.standard,
        builder: (context, v, _) => FractionallySizedBox(
          widthFactor: v,
          heightFactor: 1,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: ink,
              borderRadius: AppRadii.brPill,
            ),
          ),
        ),
      ),
    );
  }
}

/// Satin sheen + engraved coin rings with a reeded edge, anchored to the
/// bottom-right corner of the gold card. Purely decorative.
class _CardEngravingPainter extends CustomPainter {
  const _CardEngravingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final bounds = Offset.zero & size;

    // Diagonal satin band.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.16, 0.30, 0.44],
        ).createShader(bounds),
    );

    // Concentric rings, like the face of a big coin peeking in.
    final center = Offset(w * 0.96, h * 1.02);
    final base = math.max(w, h) * 0.34;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 5; i++) {
      ring.color = AppColors.primaryInk.withValues(alpha: 0.14 - i * 0.022);
      canvas.drawCircle(center, base * (0.55 + i * 0.22), ring);
    }

    // Reeded edge: short radial ticks around the second ring.
    final inner = base * 0.77 + 3;
    final outer = inner + 7;
    final tick = Paint()
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primaryInk.withValues(alpha: 0.12);
    const ticks = 96;
    for (var i = 0; i < ticks; i++) {
      final a = (i / ticks) * math.pi * 2;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + d * inner, center + d * outer, tick);
    }

    // Specular highlight on the innermost ring.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: base * 0.55),
      math.pi * 1.08,
      math.pi * 0.34,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.20),
    );
  }

  @override
  bool shouldRepaint(_CardEngravingPainter oldDelegate) => false;
}

/// Loading placeholder shaped like the balance card + payout button.
class WalletCardSkeleton extends StatelessWidget {
  const WalletCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card outline with the balance card's layout blocked in.
          Container(
            height: 188,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.brXl,
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Skeleton(width: 28, height: 28, radius: 14),
                    SizedBox(width: AppSpacing.sm + 2),
                    Skeleton(width: 120, height: 14),
                  ],
                ),
                SizedBox(height: AppSpacing.lg + 2),
                Skeleton(width: 170, height: 40, radius: 10),
                Spacer(),
                Skeleton(width: 120, height: 28, radius: AppRadii.pill),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Skeleton(height: 54, radius: AppRadii.md),
        ],
      ),
    );
  }
}

/// Subtle icon + caption row (e.g. the first-payout verification note).
class WalletNote extends StatelessWidget {
  const WalletNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}

// --- How it works -----------------------------------------------------------

/// Үзэх -> Хариулах -> Авах, three icon steps in a card.
class HowItWorksCard extends StatelessWidget {
  const HowItWorksCard({super.key});

  static const List<(String, String)> steps = [
    ('Үзэх', 'Видеог эцэс хүртэл'),
    ('Хариулах', 'Богино судалгаа'),
    ('Авах', 'Хэтэвчинд шууд'),
  ];

  @override
  Widget build(BuildContext context) {
    final icons = <Widget>[
      const Icon(
        Icons.play_arrow_rounded,
        size: 24,
        color: AppColors.primary,
      ),
      const Icon(
        Icons.checklist_rounded,
        size: 22,
        color: AppColors.primary,
      ),
      const CoinIcon(size: 24),
    ];

    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      if (i > 0) {
        children.add(
          const ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.only(top: 13),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        );
      }
      final (title, caption) = steps[i];
      children.add(
        Expanded(
          child: _Step(
            index: i,
            icon: icons[i],
            title: title,
            caption: caption,
            highlight: i == steps.length - 1,
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.icon,
    required this.title,
    required this.caption,
    required this.highlight,
  });

  final int index;
  final Widget icon;
  final String title;
  final String caption;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${index + 1}-р алхам: $title. $caption',
      excludeSemantics: true,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: highlight ? AppGradients.goldSoft : null,
              color: highlight ? null : AppColors.surfaceElevated,
              border: Border.all(
                color: highlight
                    ? AppColors.primary.withValues(alpha: 0.45)
                    : AppColors.borderStrong,
              ),
              boxShadow: highlight
                  ? AppShadows.glow(
                      AppColors.primary,
                      strength: 0.35,
                      blur: 16,
                      offset: Offset.zero,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: icon,
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

// --- Payout form pieces -----------------------------------------------------

/// Quick-pick amount pills ('1,000 ₮', '2,000 ₮', ...). Four across when they
/// fit, otherwise two per row.
class QuickAmountChips extends StatelessWidget {
  const QuickAmountChips({
    super.key,
    this.amounts = kQuickPayoutAmounts,
    required this.selected,
    required this.onSelected,
  });

  final List<int> amounts;

  /// The amount currently in the field (highlighted), or null.
  final int? selected;
  final ValueChanged<int> onSelected;

  static const double _gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        final perRow = (width - _gap * 3) / 4 >= 70 * scale ? 4 : 2;
        final rows = <Widget>[];
        for (var start = 0; start < amounts.length; start += perRow) {
          final slice = amounts.skip(start).take(perRow).toList();
          if (rows.isNotEmpty) rows.add(const SizedBox(height: _gap));
          rows.add(
            Row(
              children: [
                for (var i = 0; i < perRow; i++) ...[
                  if (i > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: i < slice.length
                        ? _AmountChip(
                            amount: slice[i],
                            selected: slice[i] == selected,
                            onTap: () => onSelected(slice[i]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final int amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.95,
      child: Semantics(
        selected: selected,
        child: AnimatedContainer(
          duration: AppMotion.duration(context, AppDurations.fast),
          curve: AppMotion.standard,
          height: AppLayout.minTapTarget,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : AppColors.surfaceElevated,
            borderRadius: AppRadii.brSm,
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.70)
                  : AppColors.borderStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatTugrik(amount),
              maxLines: 1,
              style: AppTextStyles.label.copyWith(
                color: selected ? AppColors.primary : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontFeatures: AppTextStyles.tabular,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable bank tiles, two per row (one per row when the names would not
/// fit, e.g. narrow phones with large text).
class BankPicker extends StatelessWidget {
  const BankPicker({
    super.key,
    this.banks = kPayoutBanks,
    required this.selected,
    required this.onSelected,
  });

  final List<String> banks;
  final String selected;
  final ValueChanged<String> onSelected;

  static const double _gap = AppSpacing.sm + 2;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        final perRow = (width - _gap) / 2 >= 130 * scale ? 2 : 1;
        final rows = <Widget>[];
        for (var start = 0; start < banks.length; start += perRow) {
          if (rows.isNotEmpty) rows.add(const SizedBox(height: _gap));
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < perRow; i++) ...[
                    if (i > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: start + i < banks.length
                          ? BankTile(
                              name: banks[start + i],
                              paletteSeed: start + i,
                              selected: banks[start + i] == selected,
                              onTap: () => onSelected(banks[start + i]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Semantics(
          container: true,
          explicitChildNodes: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        );
      },
    );
  }
}

/// One bank option: colored monogram, name, gold ring + check when selected.
class BankTile extends StatelessWidget {
  const BankTile({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
    this.paletteSeed = 0,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  /// Picks the monogram gradient (see [campaignPalette]).
  final int paletteSeed;

  @override
  Widget build(BuildContext context) {
    final palette = campaignPalette(paletteSeed);
    final fast = AppMotion.duration(context, AppDurations.fast);

    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.97,
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: AnimatedContainer(
          duration: fast,
          curve: AppMotion.standard,
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.10)
                : AppColors.surface,
            borderRadius: AppRadii.brMd,
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.75)
                  : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Decorative: the tile's semantics come from the bank name.
              ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 34,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [palette[0], palette[1]],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          monogramOf(name, fallback: 'B'),
                          textScaler: TextScaler.noScaling,
                          style: AppTextStyles.label.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -1,
                        bottom: -1,
                        child: AnimatedScale(
                          scale: selected ? 1 : 0,
                          duration: fast,
                          curve: AppMotion.emphasized,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: selected
                        ? AppColors.textPrimary
                        : AppColors.textPrimary.withValues(alpha: 0.88),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Success sheet ----------------------------------------------------------

/// Bottom-sheet body shown after a payout request is accepted.
class PayoutSuccessSheet extends StatelessWidget {
  const PayoutSuccessSheet({
    super.key,
    required this.amount,
    required this.bank,
    required this.onDone,
  });

  final num amount;
  final String bank;
  final VoidCallback onDone;

  static const String title = 'Хүсэлт хүлээн авлаа';
  static const String message =
      'Админ таны дансны мэдээллийг шалгасны дараа мөнгө шилжинэ. '
      'Эхний амжилттай таталтын дараа таны бүртгэл баталгаажна.';
  static const String doneLabel = 'Ойлголоо';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.sm,
        AppSpacing.xxl,
        AppSpacing.lg + bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: _SuccessMedallion()),
          const SizedBox(height: AppSpacing.xl),
          Semantics(
            header: true,
            liveRegion: true,
            child: const Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headline,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxl),
          GroupedCard(
            children: [
              InfoRow(
                icon: Icons.payments_outlined,
                label: 'Дүн',
                value: formatTugrik(amount),
              ),
              InfoRow(
                icon: Icons.account_balance_outlined,
                label: 'Банк',
                value: bank,
              ),
              const InfoRow(
                icon: Icons.schedule_rounded,
                label: 'Төлөв',
                trailing: TagChip(label: 'Хянагдаж байна', tone: TagTone.gold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(label: doneLabel, onPressed: onDone, haptic: true),
        ],
      ),
    );
  }
}

class _SuccessMedallion extends StatelessWidget {
  const _SuccessMedallion();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: AppMotion.duration(context, AppDurations.slow),
        curve: AppMotion.emphasized,
        builder: (context, v, child) => Transform.scale(
          scale: v,
          child:
              Opacity(opacity: ((v - 0.6) / 0.4).clamp(0.0, 1.0), child: child),
        ),
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.success,
            boxShadow: AppShadows.glow(
              AppColors.success,
              strength: 0.8,
              blur: 28,
              offset: const Offset(0, 10),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.check_rounded,
            size: 44,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// Error SnackBar with an icon, using the themed floating style.
SnackBar walletErrorSnackBar(String message) => SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: AppColors.dangerLight,
          ),
          const SizedBox(width: AppSpacing.md - 2),
          Expanded(child: Text(message)),
        ],
      ),
    );
