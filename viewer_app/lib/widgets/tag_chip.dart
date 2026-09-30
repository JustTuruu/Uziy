import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum TagTone {
  /// Translucent white on surfaces.
  neutral,

  /// Translucent black — over imagery / video (white text).
  glass,

  /// Gold tint.
  gold,
  success,
  info,
  danger,
}

/// Small translucent pill label: '45 сек', 'Судалгаа', 'Видео', 'Шинэ'.
/// Long labels ellipsize instead of overflowing when space is tight.
class TagChip extends StatelessWidget {
  const TagChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = TagTone.neutral,
  });

  final String label;
  final IconData? icon;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (tone) {
      TagTone.neutral => (
          Colors.white.withValues(alpha: 0.08),
          AppColors.textPrimary,
          AppColors.border,
        ),
      TagTone.glass => (
          Colors.black.withValues(alpha: 0.5),
          Colors.white,
          Colors.white.withValues(alpha: 0.14),
        ),
      TagTone.gold => (
          AppColors.primary.withValues(alpha: 0.14),
          AppColors.primary,
          AppColors.primary.withValues(alpha: 0.30),
        ),
      TagTone.success => (
          AppColors.success.withValues(alpha: 0.14),
          AppColors.success,
          AppColors.success.withValues(alpha: 0.30),
        ),
      TagTone.info => (
          AppColors.accent.withValues(alpha: 0.16),
          AppColors.accentLight,
          AppColors.accent.withValues(alpha: 0.32),
        ),
      TagTone.danger => (
          AppColors.danger.withValues(alpha: 0.14),
          AppColors.dangerLight,
          AppColors.danger.withValues(alpha: 0.30),
        ),
    };

    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 5, 10, 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.brPill,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w700,
                height: 1.1,
                fontFeatures: AppTextStyles.tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
