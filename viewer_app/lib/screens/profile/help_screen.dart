import 'package:flutter/material.dart';

import '../../widgets/ui.dart';
import 'help_content.dart';
import 'profile_page_shell.dart';

/// Help page as a chat (owner, 2026-10-21): Uziy greets, then every question
/// is the viewer's own bubble on the right and its answer Uziy's bubble on the
/// left, so the FAQ reads top to bottom like a conversation — nothing to
/// open or close, just scroll.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfilePageShell(
      title: kHelpTitle,
      children: [
        HelpChat(items: kFaqItems),
      ],
    );
  }
}

/// The conversation: a greeting, then each [FaqItem] as a question bubble and
/// an answer bubble.
class HelpChat extends StatelessWidget {
  const HelpChat({super.key, required this.items});

  final List<FaqItem> items;

  /// Gap between two bubbles of the same exchange.
  static const double pairGap = AppSpacing.sm;

  /// Gap before the next question.
  static const double exchangeGap = AppSpacing.xl;

  @override
  Widget build(BuildContext context) {
    var step = 0;
    Widget enter(Widget child) =>
        FadeSlideIn(index: step++, offset: 10, child: child);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        enter(const ChatBubble.uziy(text: kHelpGreeting, showSender: true)),
        for (final item in items) ...[
          const SizedBox(height: exchangeGap),
          enter(ChatBubble.viewer(text: item.question)),
          const SizedBox(height: pairGap),
          enter(ChatBubble.uziy(text: item.answer)),
        ],
      ],
    );
  }
}

/// One message. The viewer's sit on the right in the action colour; Uziy's
/// sit on the left on the card surface, led by the Uziy coin. The corner
/// nearest the speaker is tucked in, like a messenger tail.
class ChatBubble extends StatelessWidget {
  const ChatBubble.viewer({super.key, required this.text})
      : fromViewer = true,
        showSender = false;

  const ChatBubble.uziy(
      {super.key, required this.text, this.showSender = false})
      : fromViewer = false;

  final String text;
  final bool fromViewer;

  /// Print 'Uziy' over the bubble (the first message of the chat).
  final bool showSender;

  /// A bubble never runs wider than this share of the screen.
  static const double maxWidthFactor = 0.78;
  static const double avatarSize = 28;
  static const Radius _round = Radius.circular(18);
  static const Radius _tail = Radius.circular(6);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final maxWidth = MediaQuery.sizeOf(context).width * maxWidthFactor;
    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: fromViewer ? c.primary : c.surface,
          border: fromViewer ? null : Border.all(color: c.border),
          borderRadius: BorderRadius.only(
            topLeft: _round,
            topRight: _round,
            bottomLeft: fromViewer ? _round : _tail,
            bottomRight: fromViewer ? _tail : _round,
          ),
        ),
        child: Text(
          text,
          style: fromViewer
              ? context.textStyles.bodyStrong.copyWith(color: c.onPrimary)
              : context.textStyles.body,
        ),
      ),
    );

    if (fromViewer) {
      return Align(alignment: AlignmentDirectional.centerEnd, child: bubble);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const ExcludeSemantics(child: CoinIcon(size: avatarSize)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSender) ...[
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: Text(kHelpSender, style: context.textStyles.caption),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              bubble,
            ],
          ),
        ),
      ],
    );
  }
}
