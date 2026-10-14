import 'package:flutter/material.dart';

import '../../widgets/ui.dart';

/// What one survey pays, as the register page states it (docs/SPEC.md: a
/// viewer receives about 500–700 ₮ per watched video + survey).
/// A no-break space keeps '₮' on the amount's line.
const String kRewardRangeLabel = '500–700\u00A0₮';
const String kRewardRangeCaption = 'Нэг судалгаанаас';
const String kRewardRangeLine =
    'Видеог бүтэн үзэж, асуултад хариулаад хэтэвчиндээ авна';

/// The register page's opening promise: a big coin and the amount one
/// survey pays, so the form reads as the way to money, not a toll gate
/// (critique 2026-10-14: "the register screen sells nothing").
///
/// Flat: the coin is the app's own currency artwork, the amount uses the
/// money type style, no card or gradient around it.
class RewardPromise extends StatelessWidget {
  const RewardPromise({super.key});

  static const double coinSize = 56;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const ExcludeSemantics(child: CoinIcon(size: coinSize)),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(kRewardRangeCaption, style: context.textStyles.caption),
                const SizedBox(height: AppSpacing.xxs),
                // One line always: on a narrow phone with large text the
                // amount shrinks a little rather than breaking.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    kRewardRangeLabel,
                    maxLines: 1,
                    style: context.textStyles.moneyLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  kRewardRangeLine,
                  style: context.textStyles.bodySmall
                      .copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
