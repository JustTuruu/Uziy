import 'package:flutter/material.dart';

import '../../widgets/ui.dart';

/// A quiet, consistent input treatment scoped to the sign-in form.
class LoginFieldsTheme extends StatelessWidget {
  const LoginFieldsTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return AutofillGroup(
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
                fillColor: Color.alphaBlend(
                  colors.surfaceElevated.withValues(alpha: 0.5),
                  colors.surface,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                enabledBorder: border(colors.border),
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
