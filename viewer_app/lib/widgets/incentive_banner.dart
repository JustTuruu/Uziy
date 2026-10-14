import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The "Incentivized Profiling" banner shown on registration.
/// Verbatim message required by the product spec — see docs/SPEC.md §4A.
///
/// Flat like the rest of the auth forms (owner, 2026-10-14): a faint green
/// wash and a hairline in the brand colour. No gradient, no glow.
/// The message itself must never be edited.
class IncentiveBanner extends StatelessWidget {
  const IncentiveBanner({super.key});

  static const _message =
      'Та өөрийн нас, хүйс, байршлыг үнэн зөв оруулснаар өөрт тохирсон илүү '
      'олон, илүү өндөр дүнтэй видео судалгаануудыг хүлээн авч, урамшууллаа '
      'нэмэгдүүлэх боломжтой болно.';

  /// Share of the brand colour in the fill and in the hairline.
  static const double washAlpha = 0.07;
  static const double borderAlpha = 0.22;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.primary.withValues(alpha: washAlpha),
          colors.surface,
        ),
        // Same corners as the auth fields it sits above.
        borderRadius: AppRadii.brSm,
        border: Border.all(
          color: colors.primary.withValues(alpha: borderAlpha),
        ),
      ),
      // No coin of its own: the register page's RewardPromise right above
      // already carries it.
      child: Text(
        _message,
        // Body size, not small print: it is a promise, not a disclaimer
        // (critique 2026-10-14).
        style: context.textStyles.body.copyWith(height: 1.45),
      ),
    );
  }
}
