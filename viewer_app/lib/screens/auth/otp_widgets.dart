import 'package:flutter/material.dart';

import '../../widgets/ui.dart';
import 'auth_widgets.dart' show AuthPageTitle;

/// Icon medallion, [title] and [subtitle] at the top of a phone-check or
/// password-reset step.
class OtpHeader extends StatelessWidget {
  const OtpHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// The step's glyph tile: flat sage, the field corner (16).
  static const double tileSize = 56;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: context.colors.surfaceElevated,
              borderRadius: AppRadii.brMd,
              border: Border.all(color: context.colors.border),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 26, color: context.colors.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AuthPageTitle(title, subtitle: subtitle),
      ],
    );
  }
}

/// Red one-line message under a step's field; takes no space when empty.
class OtpErrorText extends StatelessWidget {
  const OtpErrorText({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        text,
        key: const ValueKey('otp-error'),
        textAlign: TextAlign.center,
        style: context.textStyles.bodySmall
            .copyWith(color: context.colors.dangerLight),
      ),
    );
  }
}
