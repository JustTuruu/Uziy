import 'package:flutter/material.dart';

import '../../models/survey_question.dart';
import '../../widgets/ui.dart';

// Presentational pieces of the survey flow + pure helpers.
//
// Deliberately does NOT import the router (directly or transitively), so the
// widget tests in test/screens/survey/ compile on their own.

// ---------------------------------------------------------------------------
// Pure helpers
// ---------------------------------------------------------------------------

/// Mongolian Cyrillic enumerators for answer options, in the order used on
/// printed tests and questionnaires: А, Б, В, Г, Д... Letters that never
/// start an enumeration (Ё, Й, Щ, Ъ, Ы, Ь) are skipped. Cyrillic rather than
/// Latin A/B/C so every visible string stays Mongolian.
const List<String> optionAlphabet = [
  'А', 'Б', 'В', 'Г', 'Д', 'Е', 'Ж', 'З', 'И', 'К', //
  'Л', 'М', 'Н', 'О', 'Ө', 'П', 'Р', 'С', 'Т', 'У', //
  'Ү', 'Ф', 'Х', 'Ц', 'Ч', 'Ш', 'Э', 'Ю', 'Я', //
];

/// Badge letter for the option at 0-based [index]: 0 -> 'А', 1 -> 'Б', ...
/// Past the last letter it continues spreadsheet-style ('Я' is followed by
/// 'АА', 'АБ', ...), so every index gets a unique label. Negative indexes
/// are clamped to 0.
String optionLetter(int index) {
  final base = optionAlphabet.length;
  var n = (index < 0 ? 0 : index) + 1;
  final parts = <String>[];
  while (n > 0) {
    n -= 1;
    parts.add(optionAlphabet[n % base]);
    n ~/= base;
  }
  return parts.reversed.join();
}

/// Whether the viewer may move past [question] with [answer].
///
/// Optional questions can always be skipped. A required question needs a
/// non-null answer that is not a blank string and not an empty list.
bool canAdvance(SurveyQuestion question, dynamic answer) {
  if (!question.required) return true;
  if (answer == null) return false;
  if (answer is String && answer.trim().isEmpty) return false;
  if (answer is List && answer.isEmpty) return false;
  return true;
}

/// Header label, e.g. 'Асуулт 2/3' for [index] 1 of [total] 3.
String questionProgressLabel(int index, int total) =>
    'Асуулт ${index + 1}/$total';

/// Short instruction shown under the prompt for each answer type.
String answerHintFor(QuestionType type) => switch (type) {
      QuestionType.singleChoice => 'Нэг хариулт сонгоно уу',
      QuestionType.multipleChoice => 'Хэд хэдийг сонгож болно',
      QuestionType.text => 'Өөрийн үгээр бичнэ үү',
    };

/// Counter under the free-text answer: '12 тэмдэгт'. Counts user-perceived
/// characters (grapheme clusters), not UTF-16 code units.
String characterCountLabel(String text) => '${text.characters.length} тэмдэгт';

// ---------------------------------------------------------------------------
// Question heading
// ---------------------------------------------------------------------------

/// Gold overline ('АСУУЛТ 2' + an 'Заавал биш' tag for optional questions),
/// the prompt in headline style and a one-line answer hint.
class QuestionHeading extends StatelessWidget {
  const QuestionHeading({
    super.key,
    required this.number,
    required this.question,
  });

  /// 1-based question number.
  final int number;
  final SurveyQuestion question;

  static const String optionalLabel = 'Заавал биш';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Асуулт $number'.toUpperCase(),
              style: AppTextStyles.overline.copyWith(color: AppColors.primary),
            ),
            if (!question.required) const TagChip(label: optionalLabel),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          header: true,
          child: Text(question.prompt, style: AppTextStyles.headline),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(answerHintFor(question.type), style: AppTextStyles.bodySmall),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Option tile
// ---------------------------------------------------------------------------

/// One answer choice.
///
/// Single choice ([multiple] false): a Cyrillic letter badge (А, Б, В...)
/// that turns gold when selected, plus a gold check badge on the right.
/// Multiple choice: a checkbox-style rounded square badge.
/// Selected state animates to a gold border, gold-tinted fill and soft glow.
/// Tapping gives a selection-click haptic. Screen readers hear the option
/// text with a checked / unchecked state (radio-style for single choice).
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.index,
    required this.selected,
    required this.onTap,
    this.multiple = false,
  });

  final String label;

  /// 0-based position, drives the letter badge.
  final int index;
  final bool selected;
  final VoidCallback? onTap;

  /// Checkbox badge (multiple choice) instead of a letter badge.
  final bool multiple;

  static const double minHeight = 64;

  /// Key of the trailing check badge (single choice only), for tests.
  static const Key checkKey = ValueKey('option-tile-check');

  @override
  Widget build(BuildContext context) {
    final d = AppMotion.duration(context, AppDurations.normal);
    const curve = AppMotion.standard;

    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.98,
      isButton: false,
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: multiple ? null : true,
        child: AnimatedContainer(
          duration: d,
          curve: curve,
          constraints: const BoxConstraints(minHeight: minHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    AppColors.primary.withValues(alpha: 0.10),
                    AppColors.surface,
                  )
                : AppColors.surface,
            borderRadius: AppRadii.brMd,
            boxShadow: selected
                ? AppShadows.glow(
                    AppColors.primary,
                    strength: 0.35,
                    blur: 18,
                    offset: const Offset(0, 6),
                  )
                : const [],
          ),
          // Border in the foreground so its width change (1 -> 1.5) never
          // shifts the content.
          foregroundDecoration: BoxDecoration(
            borderRadius: AppRadii.brMd,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: multiple
                    ? _CheckboxBadge(selected: selected, duration: d)
                    : _LetterBadge(
                        letter: optionLetter(index),
                        selected: selected,
                        duration: d,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: d,
                  curve: curve,
                  // Merged onto the inherited style: AnimatedDefaultTextStyle
                  // replaces it, which would drop the theme's font family.
                  style: DefaultTextStyle.of(context).style.merge(
                        AppTextStyles.bodyStrong.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                  child: Text(label),
                ),
              ),
              if (!multiple) ...[
                const SizedBox(width: 10),
                AnimatedOpacity(
                  key: checkKey,
                  opacity: selected ? 1 : 0,
                  duration: d,
                  curve: curve,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0.5,
                    duration: d,
                    curve: AppMotion.emphasized,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.gold,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LetterBadge extends StatelessWidget {
  const _LetterBadge({
    required this.letter,
    required this.selected,
    required this.duration,
  });

  final String letter;
  final bool selected;
  final Duration duration;

  static const LinearGradient _idle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.surfaceHighlight, AppColors.surfaceElevated],
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: AppMotion.standard,
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected ? AppGradients.gold : _idle,
        boxShadow: selected
            ? AppShadows.glow(
                AppColors.primary,
                strength: 0.5,
                blur: 10,
                offset: const Offset(0, 3),
              )
            : const [],
      ),
      alignment: Alignment.center,
      child: AnimatedDefaultTextStyle(
        duration: duration,
        style: DefaultTextStyle.of(context).style.merge(
              AppTextStyles.label.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.onPrimary : AppColors.textSecondary,
              ),
            ),
        child: Text(
          letter,
          maxLines: 1,
          // Fixed-size circle: cap OS text scaling so the letter fits.
          textScaler: MediaQuery.textScalerOf(context)
              .clamp(maxScaleFactor: RewardChip.maxTextScale),
        ),
      ),
    );
  }
}

class _CheckboxBadge extends StatelessWidget {
  const _CheckboxBadge({required this.selected, required this.duration});

  final bool selected;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    // Same 34pt slot as the letter badge so texts line up across types.
    return SizedBox.square(
      dimension: 34,
      child: Center(
        child: AnimatedContainer(
          duration: duration,
          curve: AppMotion.standard,
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: AppRadii.brXs,
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderStrong,
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: selected ? 1 : 0,
            duration: duration,
            curve: AppMotion.emphasized,
            child: const Icon(
              Icons.check_rounded,
              size: 18,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Free-text answer
// ---------------------------------------------------------------------------

/// Large multiline answer field with a live character counter.
class SurveyTextField extends StatelessWidget {
  const SurveyTextField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Санал бодлоо бичээрэй...',
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          minLines: 5,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyles.body,
          decoration: InputDecoration(
            hintText: hintText,
            contentPadding: const EdgeInsets.all(18),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => Text(
              characterCountLabel(value.text),
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary,
                fontFeatures: AppTextStyles.tabular,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Back button + loading skeleton
// ---------------------------------------------------------------------------

/// Square secondary 'Буцах' button (54pt, matches AppButton's height and
/// radius) for the survey action bar. Icon-only so the primary CTA keeps
/// room for 'Илгээх ба урамшуулал авах'. Announced as 'Буцах'.
class StepBackButton extends StatelessWidget {
  const StepBackButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  static const double size = 54;
  static const String label = 'Буцах';

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      haptic: true,
      scale: 0.94,
      semanticLabel: label,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: AppRadii.brMd,
          border: Border.all(color: AppColors.borderStrong),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.arrow_back_rounded,
          size: 22,
          color: onPressed == null
              ? AppColors.textTertiary
              : AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Width [text] takes on one line in [style] at [textScaler].
double measureLabelWidth(
  String text,
  TextStyle style, {
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Primary [AppButton] that never shows a truncated CTA: when [label] would
/// be cut off at the current width / OS text scale it first drops the
/// [icon], then switches to [compactLabel]. Screen readers always hear the
/// full [label].
class AdaptiveCtaButton extends StatelessWidget {
  const AdaptiveCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.compactLabel,
    this.icon,
    this.loading = false,
    this.haptic = false,
  });

  final String label;
  final String? compactLabel;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool haptic;

  // AppButton (normal size) geometry: 22pt side padding, 20pt icon + 8 gap.
  static const double _sidePadding = 22;
  static const double _iconSlot = 28;

  /// Picks what fits in [maxWidth]: (label, icon). Pure; exposed for tests.
  static (String, IconData?) resolve({
    required String label,
    required String? compactLabel,
    required IconData? icon,
    required double maxWidth,
    required double Function(String) measure,
  }) {
    if (!maxWidth.isFinite) return (label, icon);
    // Small safety margin for font metric differences.
    final room = maxWidth - _sidePadding * 2 - 2;
    final labelWidth = measure(label);
    if (icon != null && labelWidth + _iconSlot <= room) return (label, icon);
    if (labelWidth <= room || compactLabel == null) return (label, null);
    return (compactLabel, null);
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
          AppTextStyles.button.copyWith(fontWeight: FontWeight.w700),
        );
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final (text, shownIcon) = resolve(
          label: label,
          compactLabel: compactLabel,
          icon: icon,
          maxWidth: constraints.maxWidth,
          measure: (s) => measureLabelWidth(s, style, textScaler: scaler),
        );
        return AppButton(
          label: text,
          icon: shownIcon,
          semanticLabel: label,
          onPressed: onPressed,
          loading: loading,
          haptic: haptic,
        );
      },
    );
  }
}

/// Loading placeholder shaped like a question: overline, two-line prompt,
/// hint and three option tiles, under one shimmer.
class SurveySkeleton extends StatelessWidget {
  const SurveySkeleton({super.key, this.optionCount = 3});

  final int optionCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(width: 76, height: 12, radius: AppRadii.pill),
          const SizedBox(height: AppSpacing.lg),
          const Skeleton(height: 26),
          const SizedBox(height: AppSpacing.sm),
          const FractionallySizedBox(
            widthFactor: 0.62,
            child: Skeleton(height: 26),
          ),
          const SizedBox(height: AppSpacing.md),
          const Skeleton(width: 150, height: 14),
          const SizedBox(height: AppSpacing.xxl),
          for (var i = 0; i < optionCount; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            const Skeleton(height: OptionTile.minHeight, radius: AppRadii.md),
          ],
        ],
      ),
    );
  }
}

/// Softly fades the top and bottom edges of a scrolling area so content
/// dissolves under the header / action bar instead of being cut off.
class ScrollEdgeFade extends StatelessWidget {
  const ScrollEdgeFade({
    super.key,
    required this.child,
    this.top = 12,
    this.bottom = 24,
  });

  final Widget child;

  /// Fade heights in logical pixels.
  final double top;
  final double bottom;

  /// Gradient stops for a box of [height]: opaque between the two fades.
  /// Degenerate heights (fades taller than the box) collapse gracefully.
  static List<double> stopsFor(double height, double top, double bottom) {
    if (height <= 0) return const [0, 0, 1, 1];
    final a = (top / height).clamp(0.0, 0.5);
    final b = (1 - bottom / height).clamp(0.5, 1.0);
    return [0, a, b, 1];
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: stopsFor(rect.height, top, bottom),
      ).createShader(rect),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Reward celebration (bottom sheet content)
// ---------------------------------------------------------------------------

/// Celebration shown after a successful submit: confetti, a glowing gold
/// coin medallion with a success check, the headline, the reward counting up
/// to '+700 ₮' in gold, a reassurance line and the continue CTA.
///
/// Designed as bottom-sheet content: it sizes to its content, paints a soft
/// gold glow clipped to the sheet's top radius, and pads for the bottom
/// safe area. The confetti may paint past its box (the sheet should use
/// `clipBehavior: Clip.none` so the burst flies out over the scrim).
/// The haptic is the caller's job (HapticFeedback.mediumImpact on show).
class RewardCelebration extends StatelessWidget {
  const RewardCelebration({
    super.key,
    required this.reward,
    required this.onContinue,
  });

  final num reward;
  final VoidCallback onContinue;

  static const String title = 'Урамшуулал таны хэтэвчинд орлоо';
  static const String subtitle = 'Хэтэвч рүү шууд орлоо';
  static const String continueLabel = 'Дараагийн видео үзэх';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadii.sheetTop,
                gradient: RadialGradient(
                  center: const Alignment(0, -1.1),
                  radius: 1.1,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    AppColors.primary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Behind the content, bursting from the medallion.
        const Positioned.fill(
          child: ConfettiBurst(
            particleCount: 70,
            origin: Alignment(0, -0.55),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xxxl,
            AppSpacing.xxl,
            AppSpacing.xxl + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _RewardMedallion(),
              const SizedBox(height: AppSpacing.xxl),
              const Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.title,
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: AppGradients.gold.createShader,
                  child: AnimatedMoney(
                    value: reward,
                    withSign: true,
                    textAlign: TextAlign.center,
                    // White so the gold gradient mask shows at full strength.
                    style: AppTextStyles.moneyLarge.copyWith(
                      fontSize: 46,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 16,
                    color: AppColors.successLight,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),
              AdaptiveCtaButton(
                label: continueLabel,
                icon: Icons.play_arrow_rounded,
                onPressed: onContinue,
                haptic: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Gold coin on a glowing halo with a green success check. Pops in once
/// (coin first, then the check); static under reduce-motion.
class _RewardMedallion extends StatelessWidget {
  const _RewardMedallion();

  static const double _box = 136;
  static const double _coin = 92;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.duration(
          context,
          const Duration(milliseconds: 800),
        ),
        builder: (context, t, _) {
          final halo =
              const Interval(0, 0.6, curve: AppMotion.standard).transform(t);
          final coin =
              const Interval(0, 0.65, curve: AppMotion.emphasized).transform(t);
          final check =
              const Interval(0.45, 1, curve: AppMotion.emphasized).transform(t);

          return SizedBox.square(
            dimension: _box,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Halo.
                Opacity(
                  opacity: halo,
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * halo,
                    child: Container(
                      width: _box,
                      height: _box,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.30),
                            AppColors.primary.withValues(alpha: 0.10),
                            AppColors.primary.withValues(alpha: 0),
                          ],
                          stops: const [0, 0.6, 1],
                        ),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                  ),
                ),
                // Coin with glow.
                Opacity(
                  opacity: coin.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.4 + 0.6 * coin,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.glow(
                          AppColors.primary,
                          strength: 1.1,
                          blur: 34,
                          offset: const Offset(0, 10),
                        ),
                      ),
                      child: const CoinIcon(size: _coin),
                    ),
                  ),
                ),
                // Success check.
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Transform.scale(
                    scale: check.clamp(0.0, 1.4),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.success,
                        border: Border.all(color: AppColors.surface, width: 3),
                        boxShadow: AppShadows.glow(
                          AppColors.success,
                          strength: 0.7,
                          blur: 12,
                          offset: const Offset(0, 4),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check_rounded,
                        size: 20,
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
