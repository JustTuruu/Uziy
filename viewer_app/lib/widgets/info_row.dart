import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// iOS-settings style row: icon tile, label (+ optional subtitle), optional
/// value on the right, and a chevron when tappable (unless [trailing] is
/// given). Min height 56. [danger] tints the row red (e.g. 'Гарах').
/// Put several inside a [GroupedCard].
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.danger = false,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool danger;

  /// Icon tint override (default textSecondary, or danger).
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.danger : AppColors.textPrimary;
    final iconFg =
        iconColor ?? (danger ? AppColors.danger : AppColors.textSecondary);
    final tileBg = danger
        ? AppColors.danger.withValues(alpha: 0.12)
        : (iconColor?.withValues(alpha: 0.14) ??
            Colors.white.withValues(alpha: 0.06));
    final trail = trailing ??
        (onTap != null
            ? const Icon(
                AppIcons.chevron,
                size: 16,
                color: AppColors.textTertiary,
              )
            : null);

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: iconFg),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyStrong.copyWith(color: fg),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
            if (trail != null) ...[
              const SizedBox(width: 6),
              trail,
            ],
          ],
        ),
      ),
    );

    if (onTap == null) return MergeSemantics(child: row);
    // InkWell adds a tap action but not the button role; add it so screen
    // readers announce tappable rows (e.g. 'Гарах') as buttons.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(onTap: onTap, child: row),
        ),
      ),
    );
  }
}

/// Groups rows in one surface card with hairline dividers between them
/// (n children -> n-1 dividers). Dividers are indented to align with the
/// row text (default 60 = InfoRow icon tile + gaps).
class GroupedCard extends StatelessWidget {
  const GroupedCard({
    super.key,
    required this.children,
    this.dividerIndent = 60,
    this.radius = AppRadii.lg,
  });

  final List<Widget> children;
  final double dividerIndent;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      radius: radius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: dividerIndent,
                color: AppColors.divider,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}
