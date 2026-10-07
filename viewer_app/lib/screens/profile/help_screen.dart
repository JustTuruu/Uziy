import 'package:flutter/material.dart';

import '../../widgets/ui.dart';
import 'help_content.dart';
import 'profile_page_shell.dart';

/// Help page: the FAQ as an accordion (one answer open at a time).
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfilePageShell(
      title: kHelpTitle,
      children: [
        FaqList(items: kFaqItems),
      ],
    );
  }
}

/// Accordion of [items]; opening one closes the previously open one.
class FaqList extends StatefulWidget {
  const FaqList({super.key, required this.items});

  final List<FaqItem> items;

  @override
  State<FaqList> createState() => _FaqListState();
}

class _FaqListState extends State<FaqList> {
  int? _open;

  void _toggle(int index) =>
      setState(() => _open = _open == index ? null : index);

  @override
  Widget build(BuildContext context) {
    return GroupedCard(
      dividerIndent: 0,
      children: [
        for (var i = 0; i < widget.items.length; i++)
          FaqTile(
            item: widget.items[i],
            expanded: _open == i,
            onTap: () => _toggle(i),
          ),
      ],
    );
  }
}

/// One question row; the answer shows underneath while [expanded].
class FaqTile extends StatelessWidget {
  const FaqTile({
    super.key,
    required this.item,
    required this.expanded,
    required this.onTap,
  });

  final FaqItem item;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      label: item.question,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(item.question, style: AppTextStyles.bodyStrong),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: AppDurations.fast,
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: AppDurations.fast,
                curve: AppMotion.standard,
                alignment: Alignment.topCenter,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          item.answer,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
