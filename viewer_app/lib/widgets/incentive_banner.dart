import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'coin.dart';

/// The "Incentivized Profiling" banner shown on registration.
/// Verbatim message required by the product spec — see docs/SPEC.md §4A.
///
/// Styled as a premium gold info card: gold-tinted gradient, gold hairline
/// and soft glow, a coin medallion with a "grow" badge and a large faint
/// coin in the corner. The message itself must never be edited.
class IncentiveBanner extends StatelessWidget {
  const IncentiveBanner({super.key});

  static const _message =
      'Та өөрийн нас, хүйс, байршлыг үнэн зөв оруулснаар өөрт тохирсон илүү '
      'олон, илүү өндөр дүнтэй видео судалгаануудыг хүлээн авч, урамшууллаа '
      'нэмэгдүүлэх боломжтой болно.';

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.brLg,
        color: AppColors.surface,
        boxShadow: AppShadows.glow(
          AppColors.primary,
          strength: 0.3,
          blur: 28,
          offset: const Offset(0, 10),
        ),
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: AppRadii.brLg,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.32),
          ),
        ),
        child: ClipRRect(
          borderRadius: AppRadii.brLg,
          child: Stack(
            children: [
              // Gold tint + lit top edge.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withValues(alpha: 0.20),
                        AppColors.primaryDeep.withValues(alpha: 0.06),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: AppGradients.sheen),
                ),
              ),
              // Oversized faint coin peeking from the corner.
              const Positioned(
                right: -26,
                bottom: -30,
                child: ExcludeSemantics(
                  child: Opacity(opacity: 0.12, child: CoinIcon(size: 108)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _GrowthCoin(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _message,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Coin with a small green "trending up" badge: more accurate profile,
/// more earnings. Decorative.
class _GrowthCoin extends StatelessWidget {
  const _GrowthCoin();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 42,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: AppShadows.glow(
                  AppColors.primary,
                  strength: 0.6,
                  blur: 14,
                  offset: const Offset(0, 4),
                ),
              ),
              child: const CoinIcon(size: 42),
            ),
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.success,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.trending_up_rounded,
                  size: 12,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
