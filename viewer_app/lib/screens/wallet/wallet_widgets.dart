import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/payout_request.dart';
import '../../models/view_history_item.dart';
import '../../widgets/ui.dart';
import '../profile/history_logic.dart' show historyDayLabel, historyTimeLabel;
import '../profile/history_screen.dart' show HistoryRow;
import 'wallet_logic.dart';

// Presentational widgets for the wallet tab and the payout form.
//
// Nothing here imports the router or a service, so every widget can be
// pumped on its own in widget tests.

// --- Balance card -----------------------------------------------------------

/// The wallet balance drawn as an Uziy bank card: brand mark, EMV chip and
/// contactless glyph, the balance counting up, the masked phone in the
/// card-number slot and the verification badge. A light sheen sweeps across
/// once when it appears. While the balance is under the payout minimum a
/// progress meter sits right under the card.
class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    required this.balance,
    required this.verified,
    this.phoneNumber,
    this.holderName,
    this.onAddName,
    this.progress,
  });

  final num balance;
  final bool verified;

  /// Shown on the card in place of the name when [holderName] is null: an
  /// account from before names were asked can add one. Null hides it.
  final VoidCallback? onAddName;

  /// Printed above the number like a bank card's holder name: the name given
  /// at registration (`walletCardName`); nothing is shown when null.
  final String? holderName;

  /// Shown masked ('•••• 9911') where a bank card prints its number.
  final String? phoneNumber;

  /// Shown as a meter when set and the minimum is not reached yet.
  final PayoutProgress? progress;

  static const String balanceLabel = 'Одоогийн үлдэгдэл';
  static const String cardTitle = 'ХЭТЭВЧ';
  static const String holderLabel = 'Данс эзэмшигч';

  /// ISO/IEC 7810 ID-1 card proportions. The card never gets shorter than
  /// this, but may grow with very large text instead of clipping it.
  static const double aspectRatio = 85.6 / 53.98;

  @override
  Widget build(BuildContext context) {
    final meter = progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, box) => ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxWidth / aspectRatio),
            child: _CardFace(
              balance: balance,
              verified: verified,
              cardNumber: maskedCardNumber(phoneNumber),
              holderName: holderName,
              onAddName: onAddName,
            ),
          ),
        ),
        if (meter != null && !meter.reached) ...[
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: PayoutProgressMeter(progress: meter),
          ),
        ],
      ],
    );
  }
}

/// The card itself. White ink on fixed forest artwork in both themes.
class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.balance,
    required this.verified,
    required this.cardNumber,
    this.holderName,
    this.onAddName,
  });

  final num balance;
  final bool verified;
  final String cardNumber;
  final String? holderName;
  final VoidCallback? onAddName;

  static const Color _ink = Colors.white;

  @override
  Widget build(BuildContext context) {
    final soft = _ink.withValues(alpha: 0.72);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppGradients.walletCard,
        borderRadius: AppRadii.brXl,
        border: Border.all(color: _ink.withValues(alpha: 0.14)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33082A1E),
            blurRadius: 24,
            spreadRadius: -6,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _CardEngravingPainter()),
            ),
          ),
          const Positioned.fill(child: _CardSheen()),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const UziyWordmark(height: 22, color: _ink),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        textAlign: TextAlign.end,
                        WalletBalanceCard.cardTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.caption.copyWith(
                          color: soft,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ExcludeSemantics(
                      child: Icon(Icons.contactless_outlined,
                          size: 22, color: soft),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const ExcludeSemantics(child: CardChip()),
                const SizedBox(height: AppSpacing.md),
                MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        WalletBalanceCard.balanceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textStyles.caption.copyWith(color: soft),
                      ),
                      const SizedBox(height: 2),
                      // Scales down instead of overflowing for very large
                      // balances or big OS text sizes.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AnimatedMoney(
                          value: balance,
                          memoryKey: MoneyMemory.balance,
                          style: context.textStyles.moneyLarge.copyWith(
                            color: _ink,
                            fontSize: 36,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                if (holderName case final name?) ...[
                  Semantics(
                    label: WalletBalanceCard.holderLabel,
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textStyles.label.copyWith(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                ] else if (onAddName case final add?) ...[
                  AddNameChip(onTap: add),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Утасны дугаарын сүүлийн 4 орон',
                        child: Text(
                          cardNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textStyles.label.copyWith(
                            color: soft,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                            fontFeatures: AppTextStyles.tabular,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(child: WalletVerifiedBadge(verified: verified)),
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

/// '+ Нэрээ нэмэх' where the holder name goes, for an account without one:
/// a see-through white pill on the card's fixed forest artwork.
class AddNameChip extends StatelessWidget {
  const AddNameChip({super.key, required this.onTap});

  final VoidCallback onTap;

  static const String label = 'Нэрээ нэмэх';
  static const Color _ink = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.96,
      semanticLabel: label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppLayout.minTapTarget),
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: _ink.withValues(alpha: 0.12),
            borderRadius: AppRadii.brPill,
            border: Border.all(color: _ink.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, size: 16, color: _ink),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textStyles.label.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w700,
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

/// A gold EMV contact chip, as printed on bank cards. Decorative.
class CardChip extends StatelessWidget {
  const CardChip({super.key});

  static const Size size = Size(40, 30);

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
        size: size,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.cardChip,
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
          child: CustomPaint(painter: _ChipContactsPainter()),
        ),
      );
}

/// The chip's contact pads: a centre pad and the lines dividing the sides.
class _ChipContactsPainter extends CustomPainter {
  const _ChipContactsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x99775521);
    final pad = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(w / 2, h / 2), width: w * 0.34, height: h * 0.5),
      const Radius.circular(3),
    );
    canvas.drawRRect(pad, line);
    for (final y in [h / 3, h * 2 / 3]) {
      canvas.drawLine(Offset(0, y), Offset(pad.left, y), line);
      canvas.drawLine(Offset(pad.right, y), Offset(w, y), line);
    }
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, pad.top), line);
    canvas.drawLine(Offset(w / 2, pad.bottom), Offset(w / 2, h), line);
  }

  @override
  bool shouldRepaint(_ChipContactsPainter oldDelegate) => false;
}

/// One diagonal light sweep across the card when it first appears, like
/// tilting a real card under a lamp. Skipped under reduce-motion.
class _CardSheen extends StatefulWidget {
  const _CardSheen();

  @override
  State<_CardSheen> createState() => _CardSheenState();
}

class _CardSheenState extends State<_CardSheen>
    with SingleTickerProviderStateMixin {
  /// A short pause (the card settles in first), then a 1.4 s sweep.
  static const Duration total = Duration(milliseconds: 1750);
  static const Curve _curve = Interval(0.2, 1, curve: Curves.easeInOutCubic);

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: total);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!AppMotion.reduced(context)) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _curve.transform(_controller.value);
            if (t == 0 || t == 1) return const SizedBox.expand();
            final centre = -0.3 + t * 1.6;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.18),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: [
                    (centre - 0.12).clamp(0.0, 1.0),
                    centre.clamp(0.0, 1.0),
                    (centre + 0.12).clamp(0.0, 1.0),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
      );
}

/// Pill on the wallet card: solid white 'Баталгаажсан' or outlined
/// 'Баталгаажаагүй'. Fixed colours: the card is dark in both themes.
class WalletVerifiedBadge extends StatelessWidget {
  const WalletVerifiedBadge({super.key, required this.verified});

  final bool verified;

  static const String verifiedLabel = 'Баталгаажсан';
  static const String unverifiedLabel = 'Баталгаажаагүй';

  @override
  Widget build(BuildContext context) {
    const ink = Colors.white;
    const onBadge = AppColors.primary;
    final label = verified ? verifiedLabel : unverifiedLabel;
    return Semantics(
      label: 'Бүртгэл: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
        decoration: BoxDecoration(
          color: verified ? ink : ink.withValues(alpha: 0.08),
          borderRadius: AppRadii.brPill,
          border: Border.all(
            color: verified ? Colors.transparent : ink.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Icons.verified_rounded : Icons.shield_outlined,
              size: 15,
              color: verified ? onBadge : ink,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.caption.copyWith(
                  color: verified ? onBadge : ink,
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

/// 'Мөнгө татахад 600 ₮ дутуу' + percent + a bar, on the panel under the
/// wallet card.
class PayoutProgressMeter extends StatelessWidget {
  const PayoutProgressMeter({super.key, required this.progress});

  final PayoutProgress progress;

  /// 'Мөнгө татахад 600 ₮ дутуу'.
  static String labelFor(PayoutProgress p) =>
      'Мөнгө татахад ${formatTugrik(p.remaining)} дутуу';

  @override
  Widget build(BuildContext context) {
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
                  style: context.textStyles.label.copyWith(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$percent%',
                style: context.textStyles.label.copyWith(
                  color: context.colors.textSecondary,
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
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: context.colors.surfaceHighlight,
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
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: AppRadii.brPill,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fine guilloche waves (the security pattern on bank cards) and a large
/// faint ring in the bottom-right corner. Purely decorative.
class _CardEngravingPainter extends CustomPainter {
  const _CardEngravingPainter();

  static const int _waves = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;

    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var i = 0; i < _waves; i++) {
      wave.color = Colors.white.withValues(alpha: 0.035 + (i % 3) * 0.012);
      final baseY = h * (0.15 + i * 0.065);
      final path = Path()..moveTo(0, baseY);
      for (var x = 0.0; x <= w; x += 4) {
        final y = baseY +
            math.sin(x / w * math.pi * 2 + i * 0.45) * h * 0.06 +
            math.sin(x / w * math.pi * 5 + i) * h * 0.012;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, wave);
    }

    final center = Offset(w * 0.98, h * 1.05);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (var i = 0; i < 4; i++) {
      ring.color = Colors.white.withValues(alpha: 0.07 - i * 0.014);
      canvas.drawCircle(center, h * (0.42 + i * 0.16), ring);
    }
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
          // Card outline with the balance card's layout blocked in. Like the
          // real card it is at least ID-1 shaped and grows when its blocks
          // need more room: a fixed AspectRatio overflowed on 320pt phones.
          LayoutBuilder(
            builder: (context, box) => ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: box.maxWidth / WalletBalanceCard.aspectRatio,
              ),
              child: IntrinsicHeight(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: AppRadii.brXl,
                    border: Border.all(color: context.colors.border),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Skeleton(width: 70, height: 22),
                          Spacer(),
                          Skeleton(width: 60, height: 14),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md),
                      Skeleton(width: 40, height: 30, radius: 6),
                      Spacer(),
                      Skeleton(width: 90, height: 12),
                      SizedBox(height: AppSpacing.sm),
                      Skeleton(width: 160, height: 34, radius: 10),
                      SizedBox(height: AppSpacing.sm + 2),
                      Row(
                        children: [
                          Skeleton(width: 90, height: 14),
                          Spacer(),
                          Skeleton(
                              width: 110, height: 26, radius: AppRadii.pill),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
            child: Icon(icon, size: 16, color: context.colors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: context.textStyles.caption)),
        ],
      ),
    );
  }
}

// --- Payout form pieces -----------------------------------------------------

/// Quick-pick amount pills ('5,000 ₮', '10,000 ₮', ...). Four across when they
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
                ? context.colors.primary.withValues(alpha: 0.14)
                : context.colors.surfaceElevated,
            borderRadius: AppRadii.brSm,
            border: Border.all(
              color: selected
                  ? context.colors.primary.withValues(alpha: 0.70)
                  : context.colors.borderStrong,
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatTugrik(amount),
              maxLines: 1,
              style: context.textStyles.label.copyWith(
                color: selected
                    ? context.colors.primary
                    : context.colors.textPrimary,
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
                              logoAsset: kBankLogoAssets[banks[start + i]],
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

/// One bank option: the bank's logo (or a coloured monogram when there is
/// none), its name, and a ring + check when selected.
class BankTile extends StatelessWidget {
  const BankTile({
    super.key,
    required this.name,
    required this.selected,
    required this.onTap,
    this.logoAsset,
    this.paletteSeed = 0,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  /// Bundled logo image; a missing or unreadable file falls back to the
  /// monogram, so a bank never shows a broken image.
  final String? logoAsset;

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
                ? context.colors.primary.withValues(alpha: 0.10)
                : context.colors.surface,
            borderRadius: AppRadii.brMd,
            border: Border.all(
              color: selected
                  ? context.colors.primary.withValues(alpha: 0.75)
                  : context.colors.border,
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
                      BankLogo(
                        name: name,
                        logoAsset: logoAsset,
                        palette: palette,
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
                              color: context.colors.primary,
                              border: Border.all(
                                color: context.colors.surface,
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.check_rounded,
                              size: 11,
                              color: context.colors.onPrimary,
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
                  style: context.textStyles.label.copyWith(
                    color: selected
                        ? context.colors.textPrimary
                        : context.colors.textPrimary.withValues(alpha: 0.88),
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

/// A bank's mark in a 32pt rounded square (the shape banks' own app icons
/// use), or the coloured monogram when there is no logo file.
///
/// The files in `assets/banks/` are normalised to one format — a 256 px
/// opaque square, either the bank's full-bleed app icon or its mark centred
/// on white — so the image is drawn edge to edge and every bank looks the
/// same size. Add a new logo in that format, not as a raw download.
class BankLogo extends StatelessWidget {
  const BankLogo({
    super.key,
    required this.name,
    required this.palette,
    this.logoAsset,
  });

  static const double size = 32;

  /// Large enough to hide the rounded corners baked into some app icons.
  static const double cornerRadius = size * 0.25;
  static const BorderRadius _radius =
      BorderRadius.all(Radius.circular(cornerRadius));

  final String name;
  final List<Color> palette;
  final String? logoAsset;

  @override
  Widget build(BuildContext context) {
    final asset = logoAsset;
    if (asset == null) return _monogram(context);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: _radius,
        color: Colors.white,
      ),
      // Painted over the image so a white logo still has an edge on a light
      // tile.
      foregroundDecoration: BoxDecoration(
        borderRadius: _radius,
        border: Border.all(color: context.colors.border),
      ),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, _, __) => _monogram(context),
      ),
    );
  }

  Widget _monogram(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: _radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette[0], palette[1]],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        alignment: Alignment.center,
        child: Text(
          monogramOf(name, fallback: 'B'),
          textScaler: TextScaler.noScaling,
          style: context.textStyles.label.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      );
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
      'Таны дансны мэдээллийг шалгасны дараа мөнгө шилжинэ. '
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
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: context.textStyles.headline,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.textStyles.body
                .copyWith(color: context.colors.textSecondary),
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
            gradient: context.gradients.success,
            boxShadow: AppShadows.glow(
              context.colors.success,
              strength: 0.8,
              blur: 28,
              offset: const Offset(0, 10),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.check_rounded,
            size: 44,
            color: context.colors.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// Error SnackBar with an icon, using the themed floating style.
SnackBar walletErrorSnackBar(String message, {required AppPalette palette}) =>
    _walletSnackBar(message, Icons.error_outline_rounded, palette.dangerLight);

/// News that a payout request was decided while the wallet was open.
SnackBar payoutDecisionSnackBar(PayoutRequest p,
        {required AppPalette palette}) =>
    _walletSnackBar(
      payoutDecisionMessage(p),
      p.status == PayoutStatus.approved
          ? Icons.check_circle_rounded
          : Icons.undo_rounded,
      p.status == PayoutStatus.approved
          ? palette.successLight
          : palette.warning,
    );

SnackBar _walletSnackBar(String message, IconData icon, Color iconColor) =>
    SnackBar(
      content: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: AppSpacing.md - 2),
          Expanded(child: Text(message)),
        ],
      ),
    );

/// 'Хэтэвчний түүх' on the wallet tab itself: money in and money out
/// totals, then every reward and payout request, newest first, so a payout
/// decision shows up as the status of its own row. The list sits in a box of
/// [kWalletHistoryBoxHeight] that scrolls on its own, so a long history does
/// not push the rest of the page away.
class WalletHistorySection extends StatefulWidget {
  const WalletHistorySection({
    super.key,
    required this.rewards,
    required this.payouts,
    required this.now,
  });

  final List<ViewHistoryItem> rewards;
  final List<PayoutRequest> payouts;

  /// Reference time for 'Өнөөдөр' / 'Өчигдөр'.
  final DateTime now;

  @override
  State<WalletHistorySection> createState() => _WalletHistorySectionState();
}

class _WalletHistorySectionState extends State<WalletHistorySection> {
  WalletHistoryFilter _filter = WalletHistoryFilter.all;

  void _select(WalletHistoryFilter tapped) {
    HapticFeedback.selectionClick();
    setState(() => _filter = toggleWalletFilter(_filter, tapped));
  }

  @override
  Widget build(BuildContext context) {
    final all = buildWalletHistory(widget.rewards, widget.payouts);
    final shown = filterWalletHistory(all, _filter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(title: kWalletHistoryTitle),
        const SizedBox(height: AppSpacing.md),
        if (all.isEmpty)
          const EmptyState(
            icon: AppIcons.history,
            title: kWalletHistoryEmptyTitle,
            message: kWalletHistoryEmptyMessage,
          )
        else ...[
          WalletTotalsCard(
            income: walletIncome(widget.rewards),
            spending: walletSpending(widget.payouts),
            selected: _filter,
            onSelect: _select,
          ),
          if (_filter != WalletHistoryFilter.all)
            WalletFilterLine(
              filter: _filter,
              onShowAll: () => _select(_filter),
            ),
          const SizedBox(height: AppSpacing.md),
          if (shown.isEmpty)
            GroupedCard(children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  _filter == WalletHistoryFilter.income
                      ? kWalletNoIncome
                      : kWalletNoSpending,
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodySmall,
                ),
              ),
            ])
          else
            GroupedCard(
              maxHeight: kWalletHistoryBoxHeight,
              children: [
                for (final e in shown)
                  switch (e) {
                    RewardEntry(:final reward) => HistoryRow(
                        item: reward,
                        now: widget.now,
                        icon: MoneyFlow.incoming.icon,
                        iconColor: MoneyFlow.incoming.colorIn(context.colors),
                      ),
                    PayoutEntry(:final payout) =>
                      PayoutHistoryRow(payout: payout, now: widget.now),
                  },
              ],
            ),
        ],
      ],
    );
  }
}

/// 'Зөвхөн орлого' on the left, 'Бүгдийг харах' on the right: says the list
/// is narrowed and how to undo it.
class WalletFilterLine extends StatelessWidget {
  const WalletFilterLine({
    super.key,
    required this.filter,
    required this.onShowAll,
  });

  final WalletHistoryFilter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final flow = filter == WalletHistoryFilter.income
        ? MoneyFlow.incoming
        : MoneyFlow.outgoing;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(flow.icon, size: 16, color: flow.colorIn(context.colors)),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              filter == WalletHistoryFilter.income
                  ? kWalletOnlyIncome
                  : kWalletOnlySpending,
              style: context.textStyles.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: onShowAll,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, AppLayout.minTapTarget),
              foregroundColor: context.colors.primary,
              textStyle: context.textStyles.label,
            ),
            child: const Text(kWalletShowAll),
          ),
        ],
      ),
    );
  }
}

/// Pattern: lookup table — the ONE place a [MoneyFlow] gets its glyph and
/// colour, so the totals and every history row speak the same language:
/// green ↙ money in, red ↗ money out, grey ↶ a payout that came back.
extension MoneyFlowLook on MoneyFlow {
  IconData get icon => switch (this) {
        MoneyFlow.incoming => AppIcons.moneyIn,
        MoneyFlow.outgoing => AppIcons.moneyOut,
        MoneyFlow.returned => AppIcons.payoutReturned,
      };

  Color colorIn(AppPalette colors) => switch (this) {
        MoneyFlow.incoming => colors.success,
        MoneyFlow.outgoing => colors.danger,
        MoneyFlow.returned => colors.textTertiary,
      };
}

/// Round tile with the flow's arrow on a faint wash of its colour.
class MoneyFlowBadge extends StatelessWidget {
  const MoneyFlowBadge({super.key, required this.flow});

  final MoneyFlow flow;

  static const double size = 40;
  static const double iconSize = 22;

  /// Strength of the colour wash behind the arrow.
  static const double washOpacity = 0.14;

  @override
  Widget build(BuildContext context) {
    final color = flow.colorIn(context.colors);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: washOpacity),
      ),
      alignment: Alignment.center,
      child: Icon(flow.icon, size: iconSize, color: color),
    );
  }
}

/// Total income and total spending as two cards side by side, each led by its
/// [MoneyFlowBadge] so in and out read at a glance. With [onSelect] each card
/// is a toggle that narrows the history to it ([selected] is lit).
class WalletTotalsCard extends StatelessWidget {
  const WalletTotalsCard({
    super.key,
    required this.income,
    required this.spending,
    this.selected = WalletHistoryFilter.all,
    this.onSelect,
  });

  final double income;
  final double spending;
  final WalletHistoryFilter selected;
  final ValueChanged<WalletHistoryFilter>? onSelect;

  @override
  Widget build(BuildContext context) {
    final select = onSelect;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: WalletTotalTile(
              flow: MoneyFlow.incoming,
              label: kWalletIncomeLabel,
              value: formatTugrik(income, withSign: true),
              valueColor: context.colors.success,
              selected: selected == WalletHistoryFilter.income,
              onTap: select == null
                  ? null
                  : () => select(WalletHistoryFilter.income),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: WalletTotalTile(
              flow: MoneyFlow.outgoing,
              label: kWalletSpendingLabel,
              value: formatTugrik(-spending),
              valueColor: context.colors.textPrimary,
              selected: selected == WalletHistoryFilter.spending,
              onTap: select == null
                  ? null
                  : () => select(WalletHistoryFilter.spending),
            ),
          ),
        ],
      ),
    );
  }
}

/// One total: the flow badge, its label and the amount. Tappable when
/// [onTap] is set; when [selected] it takes a wash and a line of its flow's
/// colour.
class WalletTotalTile extends StatelessWidget {
  const WalletTotalTile({
    super.key,
    required this.flow,
    required this.label,
    required this.value,
    required this.valueColor,
    this.selected = false,
    this.onTap,
  });

  final MoneyFlow flow;
  final String label;
  final String value;
  final Color valueColor;
  final bool selected;
  final VoidCallback? onTap;

  /// Strength of the flow colour wash on a selected tile.
  static const double selectedWash = 0.08;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final flowColor = flow.colorIn(c);
    final card = AppCard(
      color: selected
          ? Color.alphaBlend(
              flowColor.withValues(alpha: selectedWash), c.surface)
          : null,
      borderColor: selected ? flowColor : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MoneyFlowBadge(flow: flow),
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            style: context.textStyles.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: context.textStyles.title.copyWith(
                color: valueColor,
                fontFeatures: AppTextStyles.tabular,
              ),
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    return Semantics(
      container: true,
      button: tap != null,
      selected: tap != null ? selected : null,
      label: '$label: $value',
      excludeSemantics: true,
      child:
          tap == null ? card : Pressable(onTap: tap, scale: 0.97, child: card),
    );
  }
}

/// Widest the amount at the end of a payout history row may get; a longer
/// one (a big sum at large text) scales down so the title keeps its room.
const double kHistoryAmountMaxWidth = 120;

/// One payout request in the history: bank, status · day · time, and the
/// amount going out. A rejected one is struck through — it came back.
class PayoutHistoryRow extends StatelessWidget {
  const PayoutHistoryRow({super.key, required this.payout, required this.now});

  final PayoutRequest payout;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final rejected = payout.status == PayoutStatus.rejected;
    final time = payout.decidedAt ?? payout.requestedAt;
    final when = '${historyDayLabel(time, now)} · ${historyTimeLabel(time)}';
    final reason = payout.rejectReason;
    final flow = moneyFlowOf(PayoutEntry(payout));
    return InfoRow(
      icon: flow.icon,
      iconColor: flow.colorIn(context.colors),
      label: payoutEntryTitle(payout),
      subtitle: [
        payoutEntryStatus(payout),
        if (rejected && reason != null) reason,
        when,
      ].join(' · '),
      // A big sum at large text used to take the whole row and squeeze the
      // bank name into one letter per line; now the amount scales down.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kHistoryAmountMaxWidth),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            formatTugrik(-payout.amount),
            style: context.textStyles.body.copyWith(
              color: rejected
                  ? context.colors.textTertiary
                  : context.colors.textPrimary,
              fontWeight: FontWeight.w700,
              fontFeatures: AppTextStyles.tabular,
              decoration: rejected ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
      ),
    );
  }
}
