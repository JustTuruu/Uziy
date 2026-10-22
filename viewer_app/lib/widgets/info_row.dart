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
    final fg = danger ? context.colors.danger : context.colors.textPrimary;
    final iconFg = iconColor ??
        (danger ? context.colors.danger : context.colors.textSecondary);
    final tileBg = danger
        ? context.colors.danger.withValues(alpha: 0.12)
        : (iconColor?.withValues(alpha: 0.14) ?? context.colors.iconTile);
    final trail = trailing ??
        (onTap != null
            ? Icon(
                AppIcons.chevron,
                size: 16,
                color: context.colors.textTertiary,
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
                    style: context.textStyles.bodyStrong.copyWith(color: fg),
                  ),
                  if (subtitle != null)
                    Text(subtitle!, style: context.textStyles.caption),
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
                  style: context.textStyles.body
                      .copyWith(color: context.colors.textSecondary),
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
    this.maxHeight,
  });

  final List<Widget> children;
  final double dividerIndent;
  final double radius;

  /// When set, the card never grows past this height: longer content
  /// scrolls inside it (with a visible scrollbar) while the card's frame
  /// stays put. Shorter content keeps its natural height.
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Divider(
              height: 1,
              thickness: 1,
              indent: dividerIndent,
              color: context.colors.divider,
            ),
          children[i],
        ],
      ],
    );
    final limit = maxHeight;
    return AppCard(
      padding: EdgeInsets.zero,
      radius: radius,
      child:
          limit == null ? rows : _ScrollingBox(maxHeight: limit, child: rows),
    );
  }
}

/// [child] in a box at most [maxHeight] tall that scrolls on its own, with
/// a scrollbar that shows there is more. Owns its controller so it never
/// borrows the page's primary scroll controller.
class _ScrollingBox extends StatefulWidget {
  const _ScrollingBox({required this.maxHeight, required this.child});

  final double maxHeight;
  final Widget child;

  @override
  State<_ScrollingBox> createState() => _ScrollingBoxState();
}

class _ScrollingBoxState extends State<_ScrollingBox> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      // A scrollbar keeps its track clear of the screen's safe-area padding.
      // That padding belongs to the page (the floating nav bar, the home
      // indicator), not to this small box: with it the track lost ~100pt at
      // the bottom, so the bar was too short and stopped well above the end
      // of the list (owner, 2026-10-21).
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        child: _scrollbar(),
      ),
    );
  }

  Widget _scrollbar() {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _controller,
        primary: false,
        // Stops at its ends on every platform. With iOS bouncing the box
        // overscrolled, and the iOS scrollbar shrinks and regrows with the
        // overscroll, so the bar seemed to change size while scrolling
        // (owner, 2026-10-21). A small box inside a scrolling page should
        // not rubber-band anyway.
        physics: const ClampingScrollPhysics(),
        child: widget.child,
      ),
    );
  }
}
