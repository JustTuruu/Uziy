import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart';
import '../../routes/auth_gate.dart';
import '../../services/api_error.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui.dart';
import '../splash_screen.dart';
import 'auth_widgets.dart';
import 'login_backdrop.dart';
import 'login_fields.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.next});

  /// Page to open after signing in (see `auth_gate.dart`); null means Home.
  final String? next;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  String? _error;

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.login(
        phone: phoneDigits(_phoneCtrl.text),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      await finishAuth(context, widget.next);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e, stack) {
      // The details go to the console for us; the user gets a plain sentence.
      debugPrint('[login] unexpected error: $e\n$stack');
      if (!mounted) return;
      setState(() {
        _error = kUnexpectedError;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final switchDuration = AppMotion.duration(context, AppDurations.normal);
    return LoginFieldsTheme(
      raised: true,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: Stack(
          children: [
            const Positioned.fill(child: LoginBackdrop()),
            SafeArea(
              child: AuthScrollShell(
                padding: const EdgeInsets.fromLTRB(
                  AppLayout.screenPadding,
                  AppSpacing.xxl,
                  AppLayout.screenPadding,
                  AppSpacing.xxl,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BrandRow(onGuest: () => context.go(Routes.home)),
                      const SizedBox(height: kLoginHeaderGap),
                      const AuthPageTitle(
                        'Нэвтрэх',
                        subtitle: kLoginSubtitle,
                      ),
                      const SizedBox(height: AppSpacing.huge - AppSpacing.sm),
                      LabeledField(
                        label: 'Утасны дугаар',
                        child: PhoneField(
                          controller: _phoneCtrl,
                          adorned: true,
                          hintText: kPhoneHint,
                          // Reserves the error line: a message never shifts
                          // the form.
                          helperText: kReservedLine,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _passFocus.requestFocus(),
                          validator: (v) => AuthValidators.phone(
                            v,
                            message: AuthValidators.phoneInvalid,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      LabeledField(
                        label: 'Нууц үг',
                        child: PasswordField(
                          controller: _passCtrl,
                          focusNode: _passFocus,
                          hintText: kPasswordHint,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          validator: AuthValidators.password,
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            textStyle: context.textStyles.bodyStrong,
                          ),
                          onPressed: () => context.push(Routes.forgot),
                          child: const Text(
                            'Нууц үг мартсан?',
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _ErrorSlot(
                        duration: switchDuration,
                        child: _error == null
                            ? const SizedBox(
                                key: ValueKey('no-error'),
                                width: double.infinity,
                              )
                            : Padding(
                                key: ValueKey(_error),
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.lg,
                                ),
                                child: StatusBanner(message: _error!),
                              ),
                      ),
                      AppButton(
                        label: 'Нэвтрэх',
                        trailingIcon: AppIcons.next,
                        raised: true,
                        onPressed: _submit,
                        loading: _loading,
                        haptic: true,
                      ),
                      const SizedBox(height: AppSpacing.xxxl),
                      const _OrDivider('Шинэ хэрэглэгч үү?'),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: 'Бүртгүүлэх',
                        variant: AppButtonVariant.secondary,
                        onPressed: () => context.push(
                          authLocation(Routes.register, next: widget.next),
                        ),
                      ),
                      // Free height goes under the form, where the paper's
                      // folds are; the actions stay together with it.
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Header-to-title interval (7 × 8pt).
const double kLoginHeaderGap = 56;

const String kLoginSubtitle = 'Үргэлжлүүлэхийн тулд нэвтэрнэ үү';
const String kPhoneHint = PhoneField.adornedHint;
const String kPasswordHint = 'Нууц үгээ оруулна уу';

/// Helper text of a single space: keeps the line a validation message
/// will use, so an error appears in place instead of pushing the form.
const String kReservedLine = ' ';

/// Logo tile and name on the left, the guest pill on the right. The logo
/// flies in from the splash screen (shared Hero tag).
class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.onGuest});

  final VoidCallback onGuest;

  static const double logoSize = 44;
  static const double nameSize = 26;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const UziyLogo(size: logoSize, heroTag: SplashScreen.logoHeroTag),
        const SizedBox(width: AppSpacing.md),
        // The name gives way first: on a narrow screen with large text the
        // guest pill must stay readable, the logo already says who we are.
        // Expanded, not Flexible: a loose name would leave its unused share
        // at the end of the row and pull the pill off the right edge.
        Expanded(
          child: Text(
            'uziy',
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: context.textStyles.title.copyWith(
              fontSize: nameSize,
              letterSpacing: -0.6,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          flex: 3,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: _GuestPill(onTap: onGuest),
          ),
        ),
      ],
    );
  }
}

/// 'Зочноор үзэх ›' as a quiet pill: a see-through paper surface, a
/// hairline and the text colour — present, never louder than 'Нэвтрэх'.
class _GuestPill extends StatelessWidget {
  const _GuestPill({required this.onTap});

  final VoidCallback onTap;

  static const String label = 'Зочноор үзэх';

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      haptic: true,
      scale: 0.96,
      semanticLabel: label,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppLayout.minTapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: 0.6),
          borderRadius: AppRadii.brPill,
          border: Border.all(color: context.colors.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.end,
                style: context.textStyles.label.copyWith(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              AppIcons.chevron,
              size: 16,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// A caption between two hairlines ('— Шинэ хэрэглэгч үү? —'), centred on
/// the page: the caption takes its own width and the two lines share the
/// rest equally. (A loose `Flexible` caption left its unused share at the end
/// of the row, so the right line came up short and the words sat off-centre.)
class _OrDivider extends StatelessWidget {
  const _OrDivider(this.text);

  final String text;

  /// Widest the caption may get before it wraps, as a share of the screen,
  /// so the hairlines never vanish even with large text.
  static const double maxTextFraction = 0.6;

  @override
  Widget build(BuildContext context) {
    // No LayoutBuilder: the page sits in SliverFillRemaining, which asks for
    // intrinsic sizes; the screen width is enough for a cap.
    final maxText = MediaQuery.sizeOf(context).width * maxTextFraction;
    return Row(
      children: [
        Expanded(child: Divider(color: context.colors.border)),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxText),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: context.textStyles.body
                  .copyWith(color: context.colors.textSecondary),
            ),
          ),
        ),
        Expanded(child: Divider(color: context.colors.border)),
      ],
    );
  }
}

/// Grows and cross-fades whatever [child] is. With no animation time (OS
/// reduce-motion) it is just [child]: an AnimatedSize whose duration is zero
/// re-dirties its own layout and throws.
class _ErrorSlot extends StatelessWidget {
  const _ErrorSlot({required this.duration, required this.child});

  final Duration duration;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (duration == Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(duration: duration, child: child),
    );
  }
}
