import 'package:flutter/material.dart';

import '../../widgets/ui.dart';

/// Shared, restrained field styling for sign-in and registration.
///
/// [raised] (the sign-in page) lifts every field off the paper with a soft
/// shadow under its outline; registration keeps flat fields.
class LoginFieldsTheme extends StatelessWidget {
  const LoginFieldsTheme({super.key, required this.child, this.raised = false});

  /// Corner radius of every auth field; tiles that look like a field
  /// (birth date, gender) use the same one; it matches [AppButton]'s 16.
  static const BorderRadius radius = AppRadii.brMd;

  final Widget child;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Ink-green on paper; on the dark theme a plain dark shadow (a green
    // one would read as a glow).
    final shadow = !raised
        ? null
        : colors.isDark
            ? Colors.black.withValues(alpha: 0.35)
            : colors.textPrimary.withValues(alpha: 0.07);
    InputBorder border(Color color, [double width = 1]) =>
        SoftShadowInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
          shadowColor: shadow,
        );
    return AutofillGroup(
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                fillColor: colors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 17,
                ),
                enabledBorder: border(colors.borderStrong),
                focusedBorder: border(colors.primary, 1.5),
                errorBorder: border(colors.danger),
                focusedErrorBorder: border(colors.danger, 1.5),
                hintStyle: context.textStyles.body.copyWith(
                  color: colors.textTertiary,
                  fontWeight: FontWeight.w400,
                ),
              ),
        ),
        child: child,
      ),
    );
  }
}

/// An outline border that can also cast a soft shadow below the field.
///
/// The shadow is painted only OUTSIDE the field's rounded rectangle (the
/// inside is clipped away), so it never darkens the white fill — the reason
/// a plain BoxShadow cannot be used on a TextField's decoration.
class SoftShadowInputBorder extends OutlineInputBorder {
  const SoftShadowInputBorder({
    super.borderSide,
    super.borderRadius,
    this.shadowColor,
  });

  /// Null paints no shadow (a plain outline).
  final Color? shadowColor;

  static const double blur = 14;
  static const Offset offset = Offset(0, 4);

  @override
  SoftShadowInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
    double? gapPadding,
  }) =>
      SoftShadowInputBorder(
        borderSide: borderSide ?? this.borderSide,
        borderRadius: borderRadius ?? this.borderRadius,
        shadowColor: shadowColor,
      );

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    final color = shadowColor;
    if (color != null) {
      final shape = borderRadius.toRRect(rect);
      final outside = Path.combine(
        PathOperation.difference,
        Path()..addRect(rect.inflate(blur * 3)),
        Path()..addRRect(shape),
      );
      canvas
        ..save()
        ..clipPath(outside)
        ..drawRRect(
          shape.shift(offset),
          Paint()
            ..color = color
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, blur / 2),
        )
        ..restore();
    }
    super.paint(
      canvas,
      rect,
      gapStart: gapStart,
      gapExtent: gapExtent,
      gapPercentage: gapPercentage,
      textDirection: textDirection,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SoftShadowInputBorder &&
      super == other &&
      other.shadowColor == shadowColor;

  @override
  int get hashCode => Object.hash(super.hashCode, shadowColor);
}
