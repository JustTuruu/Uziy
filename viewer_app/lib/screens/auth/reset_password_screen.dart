import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/password_reset.dart';
import '../../routes/app_router.dart' show Routes;
import '../../services/api_error.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';
import 'login_fields.dart';
import 'otp_widgets.dart';

const String kResetTitle = 'Шинэ нууц үг';
const String kResetSubtitle = 'Утас баталгаажлаа. Шинэ нууц үгээ оруулна уу.';
const String kResetSubmitLabel = 'Нууц үг шинэчлэх';
const String kResetPasswordLabel = 'Нууц үг';
const String kResetRepeatLabel = 'Нууц үгээ давтах';
const String kResetRepeatHint = 'Нууц үгээ дахин оруулна уу';
const String kResetDone = 'Нууц үг шинэчлэгдлээ. Нэвтэрнэ үү.';
const String kResetStartOverLabel = 'Дахин эхлэх';

/// HTTP status of a reset whose phone check is not (or no longer) usable:
/// only starting over with a new SMS helps.
const int kCheckNotUsableStatus = 400;

/// Last step of a password reset: the phone is proved (the viewer texted the
/// code), so only the new password is asked for — typed twice, each field
/// with its own show/hide eye (owner, 2026-10-21), so a typo cannot lock the
/// viewer out again. The check is spent when it is sent.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.reset});

  final PendingPasswordReset reset;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  final _repeatFocus = FocusNode();
  bool _loading = false;
  bool _checkUsedUp = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    _repeatFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.resetPassword(
        phone: widget.reset.phone,
        verificationId: widget.reset.verification.id,
        newPassword: _password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(kResetDone)));
      context.go(Routes.login);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
        _checkUsedUp = e.statusCode == kCheckNotUsableStatus;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = kUnexpectedError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The same paper, fields and back control as the sign-in page.
    return LoginFieldsTheme(
      raised: true,
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AuthStepAppBar(onBack: () => context.pop()),
        body: SafeArea(
          child: AuthScrollShell(
            padding: const EdgeInsets.fromLTRB(
              AppLayout.screenPadding,
              AppSpacing.lg,
              AppLayout.screenPadding,
              AppSpacing.xxl,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const OtpHeader(
                    icon: AppIcons.resetPassword,
                    title: kResetTitle,
                    subtitle: kResetSubtitle,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  LabeledField(
                    label: kResetPasswordLabel,
                    child: PasswordField(
                      controller: _password,
                      hintText: 'Нууц үгээ оруулна уу',
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _repeatFocus.requestFocus(),
                      validator: AuthValidators.password,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LabeledField(
                    label: kResetRepeatLabel,
                    child: PasswordField(
                      controller: _repeat,
                      focusNode: _repeatFocus,
                      hintText: kResetRepeatHint,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) =>
                          AuthValidators.passwordRepeat(v, _password.text),
                    ),
                  ),
                  OtpErrorText(message: _error),
                  const SizedBox(height: AppSpacing.xxl),
                  if (_checkUsedUp)
                    AppButton(
                      label: kResetStartOverLabel,
                      onPressed: () => context.go(Routes.forgot),
                    )
                  else
                    AppButton(
                      label: kResetSubmitLabel,
                      raised: true,
                      loading: _loading,
                      haptic: true,
                      onPressed: _submit,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
