import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/user.dart';
import '../../widgets/ui.dart';
import 'login_fields.dart';

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

  /// One wording for a wrong phone on every auth screen.
  static const String phoneInvalid = '8 оронтой дугаараа оруулна уу';
  static const int minPasswordLength = 6;
  static const String passwordTooShort = 'Дор хаяж 6 тэмдэгт';

  /// Returns [message] unless [v] holds exactly [phoneLength] digits
  /// (spaces and other separators are ignored).
  static String? phone(String? v, {required String message}) =>
      phoneDigits(v).length != phoneLength ? message : null;

  static String? password(String? v) =>
      (v == null || v.length < minPasswordLength) ? passwordTooShort : null;

  static const String passwordRepeatRequired = 'Нууц үгээ давтан оруулна уу';
  static const String passwordMismatch = 'Нууц үг таарахгүй байна';

  /// The second typing of a new password: it must be exactly [original].
  static String? passwordRepeat(String? v, String original) {
    if (v == null || v.isEmpty) return passwordRepeatRequired;
    return v == original ? null : passwordMismatch;
  }

  /// Same rule and wording as the backend (`RegisterViewerReq.NAME_PATTERN`,
  /// `FieldMessages`): letters of any alphabet plus the spaces, hyphens and
  /// apostrophes double names use ("Оюун-Эрдэнэ"); starts with a letter.
  static final RegExp _name = RegExp(r"^\p{L}[\p{L} '\-]*$", unicode: true);
  static const int nameMaxLength = 60;
  static const String lastNameRequired = 'Овгоо оруулна уу';
  static const String firstNameRequired = 'Нэрээ оруулна уу';
  static const String nameLetters = 'Овог, нэрт зөвхөн үсэг ашиглана уу';
  static const String nameTooLong = 'Овог, нэр хэт урт байна';

  static String? lastName(String? v) => _personName(v, lastNameRequired);
  static String? firstName(String? v) => _personName(v, firstNameRequired);

  static String? _personName(String? v, String required) {
    final name = (v ?? '').trim();
    if (name.isEmpty) return required;
    if (name.length > nameMaxLength) return nameTooLong;
    if (!_name.hasMatch(name)) return nameLetters;
    return null;
  }
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

/// Keeps a phone number to its [AuthValidators.phoneLength] national digits.
/// Spaces and dashes go; a pasted `+976 8811 2233` (or `976…`) loses the
/// country code instead of being cut short to `97688112`.
class PhoneDigitsFormatter extends TextInputFormatter {
  const PhoneDigitsFormatter();

  static const String _countryDigits = '976';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = phoneDigits(newValue.text);
    if (digits.length > AuthValidators.phoneLength &&
        digits.startsWith(_countryDigits)) {
      digits = digits.substring(_countryDigits.length);
    }
    if (digits.length > AuthValidators.phoneLength) {
      digits = digits.substring(0, AuthValidators.phoneLength);
    }
    if (digits == newValue.text) return newValue;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}

/// Phone number entry — an ordinary editable field (caret, selection, paste,
/// autofill) built exactly like [PasswordField]: the same body font, the same
/// input theme (height, border, padding) and the same leading slot, which
/// holds a quiet `+976` where the password field has its lock. The
/// controller holds the bare digits.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.hintText = defaultHint,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.autofillHints = defaultAutofillHints,
    this.helperText,
    this.adorned = false,
  });

  static const String countryCode = '+976';

  /// The adorned field's placeholder.
  static const String adornedHint = '8 оронтой дугаар';
  static const double countryDividerHeight = 20;
  static const String defaultHint = '8 оронтой дугаар';

  /// The phone number is the account login, so it is offered to password
  /// managers as the username (iOS reads only the first hint), plus the
  /// national-format phone hint for Android autofill (national format, so
  /// no country code ends up in the 8-digit field).
  static const List<String> defaultAutofillHints = [
    AutofillHints.username,
    AutofillHints.telephoneNumberNational,
  ];

  final TextEditingController controller;
  final String hintText;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final Iterable<String>? autofillHints;

  /// Text under the field; a single space reserves the error line so a
  /// message does not push the form down.
  final String? helperText;

  /// The sign-in look: '+976' on a soft capsule and a phone glyph at the
  /// right end. Off (registration, reset): plain '+976'.
  final bool adorned;

  @override
  Widget build(BuildContext context) {
    final code = Text(
      countryCode,
      style: context.textStyles.body.copyWith(
        color:
            adorned ? context.colors.textPrimary : context.colors.textSecondary,
      ),
    );
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      // Digits only (iOS number pad). TextInputType.phone would also offer
      // + * # on the keypad.
      keyboardType: TextInputType.number,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      autofillHints: autofillHints,
      inputFormatters: const [PhoneDigitsFormatter()],
      style: context.textStyles.body,
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: EdgeInsetsDirectional.only(
            // The capsule brings its own inner padding.
            start: adorned ? AppSpacing.sm : AppSpacing.md,
            end: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (adorned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: AppRadii.brXs,
                  ),
                  child: code,
                )
              else
                code,
              const SizedBox(width: AppSpacing.md),
              // Hairline between the fixed code and the typed number.
              SizedBox(
                height: countryDividerHeight,
                child: VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.colors.borderStrong,
                ),
              ),
            ],
          ),
        ),
        hintText: hintText,
        helperText: helperText,
        suffixIcon: adorned
            ? ExcludeSemantics(
                child: Icon(
                  AppIcons.phone,
                  size: _adornmentIconSize,
                  color: context.colors.textSecondary,
                ),
              )
            : null,
      ),
      validator: validator,
    );
  }
}

/// Size of the glyphs inside auth fields (phone, lock, eye).
const double _adornmentIconSize = 22;

/// Password field with a lock icon and a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.hintText = 'Нууц үг',
    this.showLeadingIcon = true,
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
  final bool showLeadingIcon;

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
      style: context.textStyles.body,
      decoration: InputDecoration(
        prefixIcon: widget.showLeadingIcon
            ? Icon(
                AppIcons.lock,
                size: _adornmentIconSize,
                color: context.colors.textSecondary,
              )
            : null,
        hintText: widget.hintText,
        helperText: widget.helperText,
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: AppIconButton(
            icon: _obscure ? AppIcons.passwordHidden : AppIcons.passwordShown,
            semanticLabel:
                _obscure ? PasswordField.showLabel : PasswordField.hideLabel,
            variant: AppIconButtonVariant.plain,
            color: context.colors.textSecondary,
            haptic: true,
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      validator: widget.validator,
    );
  }
}

/// Овог and Нэр as two labelled fields with the registration rules. Shared by
/// the register form and the wallet's "add your name" sheet, so both ask for
/// the name the same way.
class PersonNameFields extends StatelessWidget {
  const PersonNameFields({
    super.key,
    required this.lastName,
    required this.firstName,
    this.onDone,
  });

  static const String lastNameLabel = 'Овог';
  static const String firstNameLabel = 'Нэр';

  final TextEditingController lastName;
  final TextEditingController firstName;

  /// Called when the keyboard's done key is pressed in the second field.
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LabeledField(
          label: lastNameLabel,
          child: TextFormField(
            controller: lastName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
            style: context.textStyles.body,
            decoration: const InputDecoration(),
            validator: AuthValidators.lastName,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LabeledField(
          label: firstNameLabel,
          child: TextFormField(
            controller: firstName,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.givenName],
            style: context.textStyles.body,
            decoration: const InputDecoration(),
            validator: AuthValidators.firstName,
            onFieldSubmitted: onDone == null ? null : (_) => onDone!(),
          ),
        ),
      ],
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
    this.focused = false,
  });

  /// Suffix shown after an optional field's label.
  static const String optionalNote = 'заавал биш';

  final String text;

  /// Appends a muted '(заавал биш)'.
  final bool optional;

  /// Hide the label from screen readers when the control below already
  /// announces the same words (otherwise VoiceOver reads them twice).
  final bool excludeSemantics;

  /// Its field has the cursor: the label takes the brand colour.
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final label = Text.rich(
      TextSpan(
        text: text,
        children: [
          if (optional)
            TextSpan(
              text: ' ($optionalNote)',
              style: context.textStyles.label.copyWith(
                color: context.colors.textTertiary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
    final styled = AnimatedDefaultTextStyle(
      duration: AppMotion.duration(context, AppDurations.fast),
      curve: AppMotion.standard,
      // Merged onto the inherited style so the font family and locale
      // fallbacks carry through.
      style: DefaultTextStyle.of(context).style.merge(
            context.textStyles.label.copyWith(
              color: focused
                  ? context.colors.primary
                  : context.colors.textSecondary,
            ),
          ),
      child: label,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: excludeSemantics ? ExcludeSemantics(child: styled) : styled,
    );
  }
}

/// A [FieldLabel] above its [child] field, named for screen readers: VoiceOver announces 'Утасны дугаар, text field' instead of a
/// nameless field (critique 2026-10-14).
class LabeledField extends StatefulWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.optional = false,
    this.trailing,
  });

  final String label;
  final Widget child;
  final bool optional;

  /// A small action on the label's line, right-aligned (e.g. 'Нууц үг
  /// мартсан?' next to 'Нууц үг').
  final Widget? trailing;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final label = FieldLabel(
      widget.label,
      optional: widget.optional,
      excludeSemantics: true,
      focused: _focused,
    );
    final trailing = widget.trailing;
    // Not MergeSemantics: merging an editable text node trips a framework
    // assertion. The visible label is hidden from screen readers and the
    // same words are put on the field's own node instead.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing == null)
          label
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: label),
              const SizedBox(width: AppSpacing.sm),
              // May take up to two thirds of the line; wraps instead of
              // overflowing on a narrow screen with large text.
              Flexible(flex: 2, child: trailing),
            ],
          ),
        // Listens only: tracks whether the field below holds the cursor.
        Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (f) => setState(() => _focused = f),
          child: Semantics(
            label: widget.optional
                ? '${widget.label} (${FieldLabel.optionalNote})'
                : widget.label,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

/// Inline validation message under a custom control (gender cards, birth
/// date tile). It copies the themed TextFormField error text exactly: same
/// style, same 4pt gap below the control and the same start inset as the
/// text inside a field, so custom and text-field errors look identical.
class FieldError extends StatelessWidget {
  const FieldError(this.message, {super.key});

  final String message;

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
          start: contentStart + _m3SubtextGap,
          end: contentStart,
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
  });

  final bool show;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ReducibleAnimatedSize(
      duration: AppDurations.normal,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: show ? FieldError(message) : const FillWidth(),
    );
  }
}

// ---------------------------------------------------------------------------
// Page title, gender + birth date
// ---------------------------------------------------------------------------

/// The big title of every auth page ('Нэвтрэх', 'Бүртгүүлэх', the reset
/// steps): one size across the flow, announced as a heading, with an
/// optional quiet subtitle under it.
class AuthPageTitle extends StatelessWidget {
  const AuthPageTitle(this.text, {super.key, this.subtitle});

  /// The flow's one big word: larger than the in-app display style.
  static const double titleSize = 40;

  final String text;

  /// One quiet line under the title, or none.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            text,
            style: context.textStyles.display.copyWith(fontSize: titleSize),
          ),
        ),
        if (sub != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            sub,
            style: context.textStyles.body.copyWith(
              color: context.colors.textSecondary,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

/// The bar of the auth steps (reset, verify): transparent, with the
/// [AuthBackButton] lined up on the page gutter.
class AuthStepAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AuthStepAppBar({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leadingWidth: AppLayout.screenPadding + AppLayout.minTapTarget,
      leading: Padding(
        padding:
            const EdgeInsetsDirectional.only(start: AppLayout.screenPadding),
        child: Center(child: AuthBackButton(onPressed: onBack)),
      ),
    );
  }
}

/// The back control of the auth steps: a quiet round button in the same
/// see-through paper and sage line as the sign-in page's guest pill.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

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
        width: AppLayout.minTapTarget,
        height: AppLayout.minTapTarget,
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.borderStrong),
        ),
        alignment: Alignment.center,
        child: Icon(
          AppIcons.back,
          size: 20,
          color: context.colors.textPrimary,
        ),
      ),
    );
  }
}

/// Эрэгтэй / Эмэгтэй as one two-part control with the text fields' corners
/// and border, with no check mark: the filled half is the answer. Nothing is
/// chosen until the viewer taps; [error] paints the border red.
class GenderSelector extends StatelessWidget {
  const GenderSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.error = false,
  });

  /// A compact two-choice control (owner, 2026-10-22: the field-high
  /// version, which grew to ~62pt with the line height, was too big). Still
  /// a full 44pt tap target.
  static const double height = 44;

  static const Map<Gender, String> labels = {
    Gender.male: 'Эрэгтэй',
    Gender.female: 'Эмэгтэй',
  };

  final Gender? value;
  final ValueChanged<Gender> onChanged;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final current = value;
    final textStyle = context.textStyles.body;
    // SegmentedButton sizes each half from its label plus padding (and
    // ignores minimumSize for the height), so the label itself carries the
    // height, with the word centred in it. Forcing the outer box instead
    // left the halves short: the word rode high over a dark band.
    return SegmentedButton<Gender>(
      segments: [
        for (final e in labels.entries)
          ButtonSegment(
            value: e.key,
            label: SizedBox(
              height: height,
              child: Center(child: Text(e.value)),
            ),
          ),
      ],
      emptySelectionAllowed: true,
      showSelectedIcon: false,
      selected: {if (current != null) current},
      onSelectionChanged: (values) {
        if (values.isEmpty || values.first == current) return;
        HapticFeedback.selectionClick();
        onChanged(values.first);
      },
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: WidgetStatePropertyAll(textStyle),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: LoginFieldsTheme.radius),
        ),
        side: WidgetStatePropertyAll(BorderSide(
          color: error ? context.colors.danger : context.colors.borderStrong,
        )),
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

    // Geometry mirrors a themed TextFormField without a prefix icon: 54pt
    // tall, text inset like the field text, so the tile lines up with the
    // text fields and dropdowns above and below it.
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
          start: AppSpacing.lg,
          end: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: LoginFieldsTheme.radius,
          border: Border.all(
            color: error
                ? context.colors.danger.withValues(alpha: 0.75)
                : context.colors.borderStrong,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: v == null
                    ? context.textStyles.body
                        .copyWith(color: context.colors.textTertiary)
                    : context.textStyles.bodyStrong
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
              Icon(
                Icons.calendar_month_rounded,
                size: 20,
                color:
                    error ? context.colors.danger : context.colors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Terms
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
    this.error = false,
  });

  static const String termsLabel = 'Үйлчилгээний нөхцөл';
  static const String privacyLabel = 'Нууцлалын бодлого';

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTapTerms;
  final VoidCallback onTapPrivacy;

  /// Submit was tried without agreeing: the frame and the box turn red.
  final bool error;

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
    final linkStyle = TextStyle(
      color: context.colors.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: context.colors.primary,
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
                  context.colors.primary.withValues(alpha: 0.06),
                  context.colors.surface,
                )
              : context.colors.surface,
          borderRadius: LoginFieldsTheme.radius,
          border: Border.all(
            color: checked
                ? context.colors.primary.withValues(alpha: 0.45)
                : widget.error
                    ? context.colors.danger
                    : context.colors.borderStrong,
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
                  // Flat brand fill, like the rest of the form (no gradient).
                  color: checked ? context.colors.primary : null,
                  border: checked
                      ? null
                      : Border.all(
                          color: widget.error
                              ? context.colors.danger
                              : context.colors.textSecondary,
                          width: 1.5,
                        ),
                ),
                alignment: Alignment.center,
                child: AnimatedScale(
                  scale: checked ? 1 : 0,
                  duration: d,
                  curve: AppMotion.standard,
                  child: Icon(
                    Icons.check_rounded,
                    size: 17,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: context.textStyles.bodySmall.copyWith(height: 1.5),
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
                    const TextSpan(text: 'той танилцаж, зөвшөөрч байна.'),
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
