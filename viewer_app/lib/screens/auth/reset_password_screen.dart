import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart' show Routes;
import '../../services/auth_service.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';
import 'otp_logic.dart';
import 'otp_widgets.dart';

const String kResetTitle = 'Шинэ нууц үг';
const String kResetSubmitLabel = 'Нууц үг шинэчлэх';
const String kResetDone = 'Нууц үг шинэчлэгдлээ. Нэвтэрнэ үү.';

/// Step 2 of a password reset: the texted code plus the new password.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.phone});

  final String phone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with ResendCooldown<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) startResendCooldown();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!isCompleteCode(_code.text)) {
      setState(() => _error = kOtpIncomplete);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.resetPassword(
        phone: widget.phone,
        code: _code.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(kResetDone)));
      context.go(Routes.login);
    } on AuthException catch (e) {
      if (!mounted) return;
      _code.clear();
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Алдаа гарлаа. Дахин оролдоно уу.';
      });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await AuthService.instance.requestOtp(
        phone: widget.phone,
        purpose: OtpPurpose.passwordReset,
      );
      if (!mounted) return;
      _code.clear();
      startResendCooldown();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(kOtpResent)));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
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
                  OtpHeader(
                    icon: AppIcons.otp,
                    title: kResetTitle,
                    subtitle: otpSubtitle(formatPhoneMn(widget.phone)),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  OtpInput(
                    controller: _code,
                    autofocus: true,
                    enabled: !_loading,
                    hasError: _error != null,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  OtpErrorText(message: _error),
                  const SizedBox(height: AppSpacing.xl),
                  PasswordField(
                    controller: _password,
                    hintText: 'Шинэ нууц үг',
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onFieldSubmitted: (_) => _submit(),
                    validator: AuthValidators.password,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: kResetSubmitLabel,
                    loading: _loading,
                    haptic: true,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ResendCodeButton(
                    secondsLeft: resendSecondsLeft,
                    busy: _resending,
                    onPressed: _resend,
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
