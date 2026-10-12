import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../widgets/ui.dart';

// Presentational pieces + pure helpers shared by the login and register
// screens. This file must NOT import routes/app_router.dart (directly or
// transitively) so it can be widget-tested in isolation.

// ---------------------------------------------------------------------------
// Pure helpers
// ---------------------------------------------------------------------------

/// Form validation rules for the auth screens. The rules are the product's:
/// the phone is exactly 8 digits (Mongolian numbering plan, shown with a
/// +976 prefix) and the password has at least 6 characters.
abstract final class AuthValidators {
  static const int phoneLength = 8;
  static const int minPasswordLength = 6;
  static const String passwordTooShort = 'Дор хаяж 6 тэмдэгт';

  /// Returns [message] unless [v] holds exactly [phoneLength] digits
  /// (spaces and other separators are ignored).
  static String? phone(String? v, {required String message}) =>
      phoneDigits(v).length != phoneLength ? message : null;

  static String? password(String? v) =>
      (v == null || v.length < minPasswordLength) ? passwordTooShort : null;
}

final RegExp _nonDigits = RegExp(r'\D');

/// The digits of a phone number, anything else removed:
/// `'8877 8899'` -> `'88778899'`. This is what goes to the backend.
String phoneDigits(String? text) => (text ?? '').replaceAll(_nonDigits, '');

/// Birth date as shown in the register form: `2001.03.09`.
String formatBirthDate(DateTime date) => DateFormat('yyyy.MM.dd').format(date);

/// Whole years between [birth] and [now]; one less when this year's birthday
/// has not been reached yet.
int ageInYears(DateTime birth, DateTime now) {
  var age = now.year - birth.year;
  final hadBirthday = now.month > birth.month ||
      (now.month == birth.month && now.day >= birth.day);
  if (!hadBirthday) age--;
  return age;
}

/// Date picker bounds for the birth date: the youngest allowed date is
/// Jan 1 of (this year - 13), the oldest Jan 1 of (this year - 80), and the
/// picker opens 20 years back.
({DateTime initial, DateTime first, DateTime last}) birthDatePickerBounds(
  DateTime now,
) =>
    (
      initial: DateTime(now.year - 20, now.month, now.day),
      first: DateTime(now.year - 80),
      last: DateTime(now.year - 13),
    );

/// Where the picker opens: the already chosen [current] date when it is
/// still inside the bounds, otherwise the default 20-years-back date.
DateTime birthDatePickerInitial(DateTime? current, DateTime now) {
  final b = birthDatePickerBounds(now);
  if (current == null || current.isBefore(b.first) || current.isAfter(b.last)) {
    return b.initial;
  }
  return current;
}

/// Screens shorter than this (iPhone SE, landscape) get the compact login
/// hero, so the primary button stays above the fold.
const double kCompactAuthHeight = 700;

/// Logo size, the large hero gaps and whether to drop optional extras (the
/// how-it-works strip) on the login screen for a screen of [screenHeight]
/// points.
({double logoSize, double gap, bool compact}) authHeroMetrics(
  double screenHeight,
) =>
    screenHeight < kCompactAuthHeight
        ? (logoSize: 56, gap: AppSpacing.xl, compact: true)
        : (logoSize: 76, gap: AppSpacing.xxxl, compact: false);

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

/// Scrollable page body for auth forms: at least viewport-tall (so a Column
/// with Spacers can push a footer down) and capped at
/// [AppLayout.maxContentWidth], centred.
///
/// The width cap is applied as a SliverPadding OUTSIDE SliverFillRemaining,
/// so the child's intrinsic height is measured at the width it is really
/// laid out at. (A ConstrainedBox inside SliverFillRemaining is measured at
/// the full viewport width, which under-measures text that wraps only at
/// the capped width and overflows in landscape / on tablets.)
class AuthScrollShell extends StatelessWidget {
  const AuthScrollShell({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.controller,
  });

  final Widget child;

  /// Inner padding around [child], inside the width cap.
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  /// Horizontal inset that centres a column of at most [maxContentWidth]
  /// in [availableWidth].
  static double sideInset(
    double availableWidth, {
    double maxContentWidth = AppLayout.maxContentWidth,
  }) {
    if (!availableWidth.isFinite) return 0;
    final side = (availableWidth - maxContentWidth) / 2;
    return side > 0 ? side : 0;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = sideInset(constraints.maxWidth);
        return CustomScrollView(
          controller: controller,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Fields
// ---------------------------------------------------------------------------

/// Phone number entry: a fixed `+976`, then one short line per digit that
/// the typed digits sit on — `+976 9 9 1 1  _ _ _ _`. The line of the digit
/// being typed is gold; all of them turn red after a failed validation.
///
/// Pattern: Adapter (same as `OtpInput`) — one invisible numeric [TextField]
/// does the real work (keyboard, autofill, backspace) and the slots only
/// draw its text. It is a [FormField], so a `Form` validates it like any
/// text field. The controller holds the bare digits.
class BigPhoneField extends StatefulWidget {
  const BigPhoneField({
    super.key,
    required this.controller,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.autofillHints = defaultAutofillHints,
  });

  static const String countryCode = '+976';

  /// The phone number is the account login, so it is offered to password
  /// managers as the username (iOS reads only the first hint), plus the
  /// national-format phone hint for Android autofill (national format, so
  /// no country code ends up in the 8-digit field).
  static const List<String> defaultAutofillHints = [
    AutofillHints.username,
    AutofillHints.telephoneNumberNational,
  ];

  /// Big, heavy, tabular: a number read at a glance, digits never jitter.
  static const TextStyle style = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.2,
    color: AppColors.textPrimary,
    fontFeatures: AppTextStyles.tabular,
  );

  /// Digits per visual group: `8877 8899`.
  static const int groupSize = 4;

  static const double prefixGap = AppSpacing.md;
  static const double slotGap = 6;
  static const double groupGap = AppSpacing.lg;
  static const EdgeInsets padding =
      EdgeInsets.symmetric(vertical: AppSpacing.sm);

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final Iterable<String>? autofillHints;

  @override
  State<BigPhoneField> createState() => _BigPhoneFieldState();
}

class _BigPhoneFieldState extends State<BigPhoneField> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(BigPhoneField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
    }
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_onFocus);
      _focus.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.removeListener(_onFocus);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() => setState(() {});

  /// Typing, autofill and a programmatic `controller.text = …` all end up
  /// here, so the form value (what the validator sees) never lags behind.
  void _onText() {
    final field = _fieldKey.currentState;
    final text = widget.controller.text;
    if (field != null && field.value != text) field.didChange(text);
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.controller.text,
      validator: widget.validator,
      builder: (field) {
        final digits = phoneDigits(widget.controller.text);
        // The slot being typed into; after the last digit it stays on the
        // last.
        final active = _focus.hasFocus
            ? digits.length.clamp(0, AuthValidators.phoneLength - 1)
            : -1;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: AlignmentDirectional.centerStart,
              children: [
                ExcludeSemantics(
                  child: Padding(
                    padding: BigPhoneField.padding,
                    // A narrow screen or large text shrinks the row instead
                    // of overflowing. (No LayoutBuilder: auth pages sit in
                    // SliverFillRemaining, which asks for intrinsic sizes.)
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: _slots(digits, active, field.hasError),
                    ),
                  ),
                ),
                // Invisible but hit-testable: a tap anywhere on the number
                // lands here and opens the keyboard.
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      autofocus: widget.autofocus,
                      // Digits only (iOS number pad). TextInputType.phone
                      // would also offer + * # and letters on the keypad.
                      keyboardType: TextInputType.number,
                      textInputAction: widget.textInputAction,
                      onSubmitted: widget.onFieldSubmitted,
                      onChanged: widget.onChanged,
                      autofillHints: widget.autofillHints,
                      // The caret always sits after the last digit, which is
                      // what the highlighted slot shows.
                      enableInteractiveSelection: false,
                      showCursor: false,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(
                          AuthValidators.phoneLength,
                        ),
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            InlineFieldError(
              show: field.hasError,
              message: field.errorText ?? '',
              flush: true,
            ),
          ],
        );
      },
    );
  }

  Widget _slots(String digits, int active, bool error) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(BigPhoneField.countryCode, style: BigPhoneField.style),
        const SizedBox(width: BigPhoneField.prefixGap),
        for (var i = 0; i < AuthValidators.phoneLength; i++) ...[
          if (i > 0)
            SizedBox(
              width: i % BigPhoneField.groupSize == 0
                  ? BigPhoneField.groupGap
                  : BigPhoneField.slotGap,
            ),
          PhoneDigitSlot(
            digit: i < digits.length ? digits[i] : null,
            active: i == active,
            error: error,
          ),
        ],
      ],
    );
  }
}

/// One digit position of a [BigPhoneField]: the digit, once typed, standing
/// on a short line. The line is grey, gold when it is the one being typed
/// into ([active]) and red on a validation [error].
class PhoneDigitSlot extends StatelessWidget {
  const PhoneDigitSlot({
    super.key,
    required this.digit,
    required this.active,
    required this.error,
  });

  final String? digit;
  final bool active;
  final bool error;

  /// Room for one tabular digit of [BigPhoneField.style].
  static const double width = 22;

  /// One text line of [BigPhoneField.style] (30pt x 1.2).
  static const double digitHeight = 36;
  static const double lineGap = AppSpacing.xs;
  static const double lineThickness = 3;
  static const double restingLineOpacity = 0.6;

  static Color get restingLineColor =>
      AppColors.textTertiary.withValues(alpha: restingLineOpacity);

  /// Line colour for the slot's state; an error wins over the active gold.
  static Color lineColor({required bool active, required bool error}) => error
      ? AppColors.danger
      : active
          ? AppColors.primary
          : restingLineColor;

  @override
  Widget build(BuildContext context) {
    // The slot grows with the OS text size, like the digit inside it.
    final scaler = MediaQuery.textScalerOf(context);
    return SizedBox(
      width: scaler.scale(width),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: scaler.scale(digitHeight),
            child: Center(
              child: Text(
                digit ?? '',
                maxLines: 1,
                style: BigPhoneField.style,
              ),
            ),
          ),
          const SizedBox(height: lineGap),
          AnimatedContainer(
            duration: AppMotion.duration(context, AppDurations.fast),
            height: lineThickness,
            decoration: BoxDecoration(
              color: lineColor(active: active, error: error),
              borderRadius: BorderRadius.circular(lineThickness / 2),
            ),
          ),
        ],
      ),
    );
  }
}

/// The phone step as one block: a heading, one line saying what the number
/// is for, then the [BigPhoneField].
class PhoneNumberSection extends StatelessWidget {
  const PhoneNumberSection({
    super.key,
    required this.controller,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofocus = false,
  });

  static const String title = 'Утасны дугаар';
  static const String helper =
      'Дугаарыг зөвхөн баталгаажуулахад ашиглана. Бусад хэрэглэгчдэд '
      'харагдахгүй.';

  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: const Text(title, style: AppTextStyles.headline),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          helper,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        BigPhoneField(
          controller: controller,
          validator: validator,
          focusNode: focusNode,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          autofocus: autofocus,
        ),
      ],
    );
  }
}

/// Password field with a lock icon and a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hintText = 'Нууц үг',
    this.helperText,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.autofillHints = const [AutofillHints.password],
  });

  static const String showLabel = 'Нууц үг харуулах';
  static const String hideLabel = 'Нууц үг нуух';

  final TextEditingController controller;
  final String hintText;

  /// Persistent rule under the field (e.g. the minimum length). Unlike the
  /// hint it stays visible while typing; the error replaces it.
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  /// [AutofillHints.password] to sign in; pass [AutofillHints.newPassword]
  /// when creating an account.
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscure,
      // The ordinary keyboard (letters, symbols, any language). Not
      // visiblePassword: on iOS that is ASCII-only and blocks Cyrillic.
      keyboardType: TextInputType.text,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onFieldSubmitted,
      onChanged: widget.onChanged,
      autofillHints: widget.autofillHints,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        hintText: widget.hintText,
        helperText: widget.helperText,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: AppIconButton(
            icon: _obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            semanticLabel:
                _obscure ? PasswordField.showLabel : PasswordField.hideLabel,
            variant: AppIconButtonVariant.plain,
            color: AppColors.textSecondary,
            haptic: true,
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      validator: widget.validator,
    );
  }
}

/// Label above a form control. Every control on the register form has one,
/// so the page reads the same way from top to bottom.
class FieldLabel extends StatelessWidget {
  const FieldLabel(
    this.text, {
    super.key,
    this.optional = false,
    this.excludeSemantics = false,
  });

  /// Suffix shown after an optional field's label.
  static const String optionalNote = 'заавал биш';

  final String text;

  /// Appends a muted '(заавал биш)'.
  final bool optional;

  /// Hide the label from screen readers when the control below already
  /// announces the same words (otherwise VoiceOver reads them twice).
  final bool excludeSemantics;

  @override
  Widget build(BuildContext context) {
    final label = Text.rich(
      TextSpan(
        text: text,
        children: [
          if (optional)
            TextSpan(
              text: ' ($optionalNote)',
              style: AppTextStyles.label.copyWith(
                color: AppColors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: excludeSemantics ? ExcludeSemantics(child: label) : label,
    );
  }
}

/// Inline validation message under a custom control (gender cards, birth
/// date tile). It copies the themed TextFormField error text exactly: same
/// style, same 4pt gap below the control and the same start inset as the
/// text inside a field, so custom and text-field errors look identical.
class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key, this.flush = false});

  final String message;

  /// No side inset: for a control with no box, whose content starts at the
  /// edge ([BigPhoneField]).
  final bool flush;

  /// Material 3 InputDecorator gap between the field and its error text,
  /// and between the content padding and the error text's start.
  static const double _m3SubtextGap = AppSpacing.xs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inputTheme = theme.inputDecorationTheme;
    final contentStart =
        inputTheme.contentPadding?.resolve(Directionality.of(context)).left ??
            AppSpacing.md;
    // What InputDecorator does: M3 bodySmall defaults merged with the
    // theme's errorStyle.
    final style = (theme.textTheme.bodySmall ?? const TextStyle())
        .merge(inputTheme.errorStyle);

    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: flush ? 0 : contentStart + _m3SubtextGap,
          end: flush ? 0 : contentStart,
          top: _m3SubtextGap,
        ),
        child: Text(
          message,
          style: style,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// [FieldError] that grows in when [show] turns true and shrinks away when
/// it turns false (used for the register form's required choices).
class InlineFieldError extends StatelessWidget {
  const InlineFieldError({
    super.key,
    required this.show,
    required this.message,
    this.flush = false,
  });

  final bool show;
  final String message;

  /// See [FieldError.flush].
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final child = show ? FieldError(message, flush: flush) : const FillWidth();
    // Reduce-motion: no AnimatedSize at all. With a zero duration it
    // re-dirties itself in the middle of its own layout and throws.
    if (AppMotion.reduced(context)) return child;
    return AnimatedSize(
      duration: AppDurations.normal,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

/// Visible [FieldLabel] plus a row of equally wide choice cards (e.g. the
/// two gender cards), grouped for screen readers under the same [label].
class ChoiceCardGroup extends StatelessWidget {
  const ChoiceCardGroup({
    super.key,
    required this.label,
    required this.children,
    this.spacing = AppSpacing.md,
  });

  final String label;
  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The group node below carries the label for screen readers.
        FieldLabel(label, excludeSemantics: true),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: label,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(child: children[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Gender + birth date
// ---------------------------------------------------------------------------

/// Large selectable card with a medallion icon. The selected card gets a
/// gold border, a faint gold glow (the gold CTA stays the strongest
/// element on the page), a gold medallion and a check badge.
class GenderOptionCard extends StatelessWidget {
  const GenderOptionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.error = false,
  });

  static const Key checkBadgeKey = ValueKey('gender-card-check');

  /// Kept low on purpose: only the primary CTA glows at full strength.
  static const double selectedGlowStrength = 0.3;

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  /// Red border (the field is required and nothing is chosen yet).
  final bool error;

  @override
  Widget build(BuildContext context) {
    final d = AppMotion.duration(context, AppDurations.normal);
    final Color borderColor = selected
        ? AppColors.primary
        : error
            ? AppColors.danger.withValues(alpha: 0.75)
            : AppColors.borderStrong;

    // One semantics node carrying button + selected + label + tap, so the
    // selected state is announced with the option (not on an ancestor).
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        haptic: true,
        scale: 0.96,
        child: AnimatedContainer(
          duration: d,
          curve: AppMotion.standard,
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: selected
                ? Color.alphaBlend(
                    AppColors.primary.withValues(alpha: 0.10),
                    AppColors.surface,
                  )
                : AppColors.surface,
            borderRadius: AppRadii.brLg,
            border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
            boxShadow: selected
                ? AppShadows.glow(
                    AppColors.primary,
                    strength: selectedGlowStrength,
                    blur: 16,
                    offset: const Offset(0, 4),
                  )
                : const [],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: d,
                      curve: AppMotion.standard,
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: selected
                            ? AppGradients.gold
                            : const LinearGradient(
                                colors: [
                                  AppColors.surfaceElevated,
                                  AppColors.surfaceElevated,
                                ],
                              ),
                        border: Border.all(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.28)
                              : AppColors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        size: 24,
                        color: selected
                            ? AppColors.onPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedDefaultTextStyle(
                      duration: d,
                      style: AppTextStyles.titleSmall.copyWith(
                        color: selected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -8,
                right: -2,
                child: AnimatedScale(
                  key: checkBadgeKey,
                  scale: selected ? 1 : 0,
                  duration: d,
                  curve: selected ? AppMotion.emphasized : AppMotion.exit,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppGradients.gold,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Field-like tile that opens the birth date picker. Shows the chosen date
/// as `yyyy.MM.dd` plus an age chip, or a placeholder.
class BirthDateTile extends StatelessWidget {
  const BirthDateTile({
    super.key,
    required this.value,
    required this.onTap,
    this.error = false,
    this.label = 'Төрсөн он сар өдөр',
    this.placeholder = 'Огноо сонгох',
  });

  final DateTime? value;
  final VoidCallback onTap;
  final bool error;

  /// Screen-reader prefix.
  final String label;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final text = v == null ? placeholder : formatBirthDate(v);
    final Color iconColor = error
        ? AppColors.danger
        : v != null
            ? AppColors.primary
            : AppColors.textSecondary;

    // Geometry mirrors a themed TextFormField with a prefixIcon: 54pt tall,
    // a 48pt icon slot, then the text after a 4pt gap, so the tile lines up
    // with the text fields and dropdown above and below it.
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.98,
      semanticLabel: '$label: $text',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppDurations.fast),
        constraints: const BoxConstraints(minHeight: 54),
        padding: const EdgeInsetsDirectional.only(
          end: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadii.brMd,
          border: Border.all(
            color: error
                ? AppColors.danger.withValues(alpha: 0.75)
                : AppColors.borderStrong,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Icon(Icons.cake_outlined, size: 24, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: v == null
                    ? AppTextStyles.body.copyWith(color: AppColors.textTertiary)
                    : AppTextStyles.bodyStrong
                        .copyWith(fontFeatures: AppTextStyles.tabular),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (v != null)
              Flexible(
                child: TagChip(
                  label: '${ageInYears(v, DateTime.now())} нас',
                  tone: TagTone.gold,
                ),
              )
            else
              const Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Terms + footer link
// ---------------------------------------------------------------------------

/// "I agree to the Terms and Privacy Policy" row. Tapping anywhere outside
/// the two links toggles the box; the links open the legal sheets.
class TermsAgreementTile extends StatefulWidget {
  const TermsAgreementTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onTapTerms,
    required this.onTapPrivacy,
  });

  static const String termsLabel = 'Үйлчилгээний нөхцөл';
  static const String privacyLabel = 'Нууцлалын бодлого';

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTapTerms;
  final VoidCallback onTapPrivacy;

  @override
  State<TermsAgreementTile> createState() => _TermsAgreementTileState();
}

class _TermsAgreementTileState extends State<TermsAgreementTile> {
  // Owned (and disposed) here instead of being recreated on every build.
  late final TapGestureRecognizer _termsTap = TapGestureRecognizer()
    ..onTap = _openTerms;
  late final TapGestureRecognizer _privacyTap = TapGestureRecognizer()
    ..onTap = _openPrivacy;

  void _openTerms() => widget.onTapTerms();
  void _openPrivacy() => widget.onTapPrivacy();
  void _toggle() => widget.onChanged(!widget.value);

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checked = widget.value;
    final d = AppMotion.duration(context, AppDurations.fast);
    const linkStyle = TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primary,
    );

    return Pressable(
      onTap: _toggle,
      haptic: true,
      scale: 0.985,
      isButton: false,
      child: AnimatedContainer(
        duration: d,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: checked
              ? Color.alphaBlend(
                  AppColors.primary.withValues(alpha: 0.06),
                  AppColors.surface,
                )
              : AppColors.surface,
          borderRadius: AppRadii.brMd,
          border: Border.all(
            color: checked
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // No action of its own: the checked flag merges into the
            // Pressable's node, whose tap toggles.
            Semantics(
              checked: checked,
              label: 'Нөхцөлийг зөвшөөрөх',
              child: AnimatedContainer(
                duration: d,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: checked ? AppGradients.gold : null,
                  // No glow: the gold fill is enough, and glow is reserved
                  // for the CTA and reward elements.
                  border: checked
                      ? null
                      : Border.all(color: AppColors.textSecondary, width: 1.5),
                ),
                alignment: Alignment.center,
                child: AnimatedScale(
                  scale: checked ? 1 : 0,
                  duration: d,
                  curve: AppMotion.standard,
                  child: const Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.bodySmall.copyWith(height: 1.5),
                  children: [
                    const TextSpan(text: 'Би '),
                    TextSpan(
                      text: TermsAgreementTile.termsLabel,
                      style: linkStyle,
                      recognizer: _termsTap,
                    ),
                    const TextSpan(text: ' болон '),
                    TextSpan(
                      text: TermsAgreementTile.privacyLabel,
                      style: linkStyle,
                      recognizer: _privacyTap,
                    ),
                    const TextSpan(text: '-той танилцаж, зөвшөөрч байна.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered "prompt + gold action" link with a full 44pt tap target,
/// e.g. 'Шинээр бүртгүүлэх үү? Бүртгүүлэх'.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Pressable(
        onTap: onTap,
        haptic: true,
        scale: 0.96,
        semanticLabel: '$prompt $action',
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppLayout.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary),
                  children: [
                    TextSpan(text: '$prompt '),
                    TextSpan(
                      text: action,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// How it works
// ---------------------------------------------------------------------------

/// The three steps of the product in one row of icon + label, shown under the
/// login form so a new visitor sees what signing in is for.
class HowItWorksStrip extends StatelessWidget {
  const HowItWorksStrip({super.key});

  static const List<({IconData icon, String label})> steps = [
    (icon: AppIcons.watched, label: 'Видео үз'),
    (icon: AppIcons.answer, label: 'Асуултад хариул'),
    (icon: AppIcons.reward, label: 'Урамшуулал ав'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in steps)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.22),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(step.icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  step.label,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
