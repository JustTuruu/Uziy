import 'package:flutter/material.dart';

import '../../widgets/ui.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.28),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 26, color: context.colors.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          child: Text(title, style: context.textStyles.display),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: context.textStyles.body
              .copyWith(color: context.colors.textSecondary),
        ),
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
