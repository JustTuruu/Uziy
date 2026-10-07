import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/register_draft.dart';
import '../../routes/auth_gate.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';
import 'otp_logic.dart';
import 'otp_widgets.dart';

/// Second step of registration: the code texted to the phone. The account is
/// created only now, by sending the form together with the code; a full code
/// submits itself.
class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key, required this.draft, this.next});

  final RegisterDraft draft;

  /// Page to open after registering (see `auth_gate.dart`).
  final String? next;

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen>
    with ResendCooldown<OtpVerifyScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // The previous screen has just sent the first code.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) startResendCooldown();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text;
    if (_loading) return;
    if (!isCompleteCode(code)) {
      setState(() => _error = kOtpIncomplete);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final d = widget.draft;
    try {
      await AuthService.instance.register(
        phone: d.phone,
        password: d.password,
        gender: d.gender,
        birthDate: d.birthDate,
        city: d.city,
        district: d.district,
        otpCode: code,
      );
      if (!mounted) return;
      await finishAuth(context, widget.next);
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
        phone: widget.draft.phone,
        purpose: OtpPurpose.register,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OtpHeader(
                  icon: AppIcons.otp,
                  title: kOtpTitle,
                  subtitle: otpSubtitle(formatPhoneMn(widget.draft.phone)),
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
                  onCompleted: (_) {
                    HapticFeedback.selectionClick();
                    _submit();
                  },
                ),
                OtpErrorText(message: _error),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: kOtpConfirmLabel,
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
    );
  }
}
