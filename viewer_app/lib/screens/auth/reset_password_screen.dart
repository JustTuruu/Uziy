import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/password_reset.dart';
import '../../routes/app_router.dart' show Routes;
import '../../services/api_error.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';
import 'otp_widgets.dart';

const String kResetTitle = 'Шинэ нууц үг';
const String kResetSubtitle = 'Утас баталгаажлаа. Шинэ нууц үгээ оруулна уу.';
const String kResetSubmitLabel = 'Нууц үг шинэчлэх';
const String kResetDone = 'Нууц үг шинэчлэгдлээ. Нэвтэрнэ үү.';
const String kResetStartOverLabel = 'Дахин эхлэх';

/// HTTP status of a reset whose phone check is not (or no longer) usable:
/// only starting over with a new SMS helps.
const int kCheckNotUsableStatus = 400;

/// Last step of a password reset: the phone is proved (the viewer texted the
/// code), so only the new password is asked for. The check is spent when it
/// is sent.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.reset});

  final PendingPasswordReset reset;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  bool _loading = false;
  bool _checkUsedUp = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
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
    return AmbientBackground(
      variant: AmbientVariant.gold,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
          leading: Center(
            child: AppIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              semanticLabel: 'Буцах',
              size: 40,
              iconSize: 18,
              onPressed: () => context.pop(),
            ),
          ),
        ),
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
                  PasswordField(
                    controller: _password,
                    hintText: 'Шинэ нууц үг',
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                    validator: AuthValidators.password,
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
