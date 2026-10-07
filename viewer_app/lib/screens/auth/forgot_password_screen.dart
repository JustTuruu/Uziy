import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_router.dart' show Routes;
import '../../services/auth_service.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';
import 'otp_widgets.dart';

const String kForgotTitle = 'Нууц үг сэргээх';
const String kForgotSubtitle =
    'Бүртгэлтэй утасны дугаараа оруулбал 6 оронтой код илгээнэ';
const String kForgotSendLabel = 'Код авах';

/// Step 1 of a password reset: the phone number. The backend answers the
/// same whether or not the number has an account, so this always moves on to
/// the code screen.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final phone = _phone.text.trim();
    try {
      await AuthService.instance.requestOtp(
        phone: phone,
        purpose: OtpPurpose.passwordReset,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      await context.push(Routes.resetPassword, extra: phone);
    } on AuthException catch (e) {
      if (!mounted) return;
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
                    title: kForgotTitle,
                    subtitle: kForgotSubtitle,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  PhonePrefixField(
                    controller: _phone,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => AuthValidators.phone(
                      v,
                      message: 'Утасны дугаараа шалгана уу',
                    ),
                  ),
                  OtpErrorText(message: _error),
                  const SizedBox(height: AppSpacing.xxl),
                  AppButton(
                    label: kForgotSendLabel,
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
