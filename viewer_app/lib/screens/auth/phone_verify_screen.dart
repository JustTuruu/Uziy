import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/password_reset.dart';
import '../../models/phone_verification.dart';
import '../../models/register_draft.dart';
import '../../routes/app_router.dart' show Routes;
import '../../routes/auth_gate.dart';
import '../../services/api_error.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui.dart';
import 'auth_widgets.dart';
import 'login_fields.dart';
import 'otp_widgets.dart';
import 'phone_verify_logic.dart';

/// Opens [uri] in another app; false when nothing could open it.
typedef SmsLauncher = Future<bool> Function(Uri uri);

Future<bool> _openSmsApp(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// What a phone check on [PhoneVerifyScreen] is for, and what happens once
/// the SMS has arrived.
///
/// Pattern: Strategy (sealed) — registration creates the account right
/// here; a password reset moves on to the new-password page.
sealed class PhoneCheckGoal {
  const PhoneCheckGoal();

  String get phone;
  PhoneCheckPurpose get purpose;
  String get subtitle;

  /// Shown while the page finishes after the SMS arrived.
  String get finishingLabel;
}

class RegisterGoal extends PhoneCheckGoal {
  const RegisterGoal(this.pending, {this.next});

  final PendingRegistration pending;

  /// Page to open after registering (see `auth_gate.dart`).
  final String? next;

  @override
  String get phone => pending.draft.phone;
  @override
  PhoneCheckPurpose get purpose => PhoneCheckPurpose.register;
  @override
  String get subtitle => kPhoneVerifySubtitle;
  @override
  String get finishingLabel => kCreatingAccount;
}

class PasswordResetGoal extends PhoneCheckGoal {
  const PasswordResetGoal(this.phone);

  @override
  final String phone;
  @override
  PhoneCheckPurpose get purpose => PhoneCheckPurpose.passwordReset;
  @override
  String get subtitle => kResetVerifySubtitle;
  @override
  String get finishingLabel => kPhoneConfirmed;
}

/// The viewer proves their phone by texting the shown code from it to
/// 144773 (verify.mn) — to register, or to reset a forgotten password. The
/// page polls the backend every [kPhoneVerifyPollInterval]; once the SMS has
/// arrived the [goal] decides what happens next.
class PhoneVerifyScreen extends StatefulWidget {
  /// Second step of registration: creates the account once verified.
  PhoneVerifyScreen({
    super.key,
    required PendingRegistration pending,
    String? next,
    this.launchSms = _openSmsApp,
    this.now = DateTime.now,
  })  : goal = RegisterGoal(pending, next: next),
        verification = pending.verification;

  /// Second step of a password reset: opens the new-password page once
  /// verified.
  PhoneVerifyScreen.passwordReset({
    super.key,
    required PendingPasswordReset reset,
    this.launchSms = _openSmsApp,
    this.now = DateTime.now,
  })  : goal = PasswordResetGoal(reset.phone),
        verification = reset.verification;

  final PhoneCheckGoal goal;
  final PhoneVerification verification;

  /// Injected so tests need no platform plugin.
  final SmsLauncher launchSms;
  final DateTime Function() now;

  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen>
    with WidgetsBindingObserver {
  late PhoneVerification _check = widget.verification;
  PhoneVerifyPhase _phase = PhoneVerifyPhase.waiting;
  Timer? _poller;
  bool _polling = false;
  bool _restarting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poller?.cancel();
    super.dispose();
  }

  /// Back from the SMS app: look straight away instead of up to 3 s later.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _poll();
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(kPhoneVerifyPollInterval, (_) => _poll());
  }

  void _stopPolling() {
    _poller?.cancel();
    _poller = null;
  }

  Future<void> _poll() async {
    if (_polling || _phase != PhoneVerifyPhase.waiting) return;
    _polling = true;
    try {
      final state =
          await AuthService.instance.phoneVerificationState(_check.id);
      if (!mounted || _phase != PhoneVerifyPhase.waiting) return;
      final next = phaseAfterPoll(
        state.status,
        expiresAt: _check.expiresAt,
        now: widget.now(),
      );
      if (next == PhoneVerifyPhase.waiting) return;
      _stopPolling();
      setState(() => _phase = next);
      if (next == PhoneVerifyPhase.registering) await _finish();
    } catch (_) {
      // A missed poll is harmless: the next tick asks again.
    } finally {
      _polling = false;
    }
  }

  Future<void> _finish() async {
    switch (widget.goal) {
      case RegisterGoal goal:
        await _register(goal);
      case PasswordResetGoal goal:
        _openNewPassword(goal);
    }
  }

  /// The check is confirmed; it is spent only when the new password is sent.
  void _openNewPassword(PasswordResetGoal goal) {
    HapticFeedback.mediumImpact();
    context.pushReplacement(
      Routes.resetPassword,
      extra: PendingPasswordReset(phone: goal.phone, verification: _check),
    );
  }

  Future<void> _register(RegisterGoal goal) async {
    setState(() {
      _phase = PhoneVerifyPhase.registering;
      _error = null;
    });
    final d = goal.pending.draft;
    try {
      await AuthService.instance.register(
        phone: d.phone,
        password: d.password,
        lastName: d.lastName,
        firstName: d.firstName,
        gender: d.gender,
        birthDate: d.birthDate,
        city: d.city,
        district: d.district,
        verificationId: _check.id,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      await finishAuth(context, goal.next);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = needsNewCode(e.statusCode)
            ? PhoneVerifyPhase.expired
            : PhoneVerifyPhase.failed;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _phase = PhoneVerifyPhase.failed;
        _error = kUnexpectedError;
      });
    }
  }

  Future<void> _restart() async {
    setState(() {
      _restarting = true;
      _error = null;
    });
    try {
      final fresh = await AuthService.instance.startPhoneVerification(
        widget.goal.phone,
        purpose: widget.goal.purpose,
      );
      if (!mounted) return;
      setState(() {
        _check = fresh;
        _phase = PhoneVerifyPhase.waiting;
      });
      _startPolling();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(kNewCodeReady)));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _restarting = false);
    }
  }

  Future<void> _sendSms() async {
    final uri = Uri.tryParse(_check.smsUri);
    final opened = uri != null && await widget.launchSms(uri);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(kSmsAppFailed)));
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OtpHeader(
                  icon: AppIcons.otp,
                  title: kPhoneVerifyTitle,
                  subtitle: widget.goal.subtitle,
                ),
                const SizedBox(height: AppSpacing.xxl),
                SmsCodeCard(
                  shortcode: _check.shortcode,
                  smsText: _check.smsText,
                ),
                const SizedBox(height: AppSpacing.lg),
                StatusBanner(
                  tone: BannerTone.info,
                  message: _check.displayInstruction,
                ),
                const SizedBox(height: AppSpacing.xxl),
                ..._actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions() {
    switch (_phase) {
      case PhoneVerifyPhase.waiting:
        return [
          AppButton(
            label: kSendSmsLabel,
            icon: AppIcons.otp,
            haptic: true,
            onPressed: _sendSms,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            kSmsCostNote,
            textAlign: TextAlign.center,
            style: context.textStyles.bodySmall
                .copyWith(color: context.colors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.xl),
          const ProgressNote(label: kWaitingForSms),
        ];
      case PhoneVerifyPhase.registering:
        return [ProgressNote(label: widget.goal.finishingLabel)];
      case PhoneVerifyPhase.expired:
        return [
          StatusBanner(
            tone: BannerTone.warning,
            title: kCodeExpiredTitle,
            message: _error ?? kCodeExpiredMessage,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: kNewCodeLabel,
            loading: _restarting,
            onPressed: _restart,
          ),
        ];
      case PhoneVerifyPhase.failed:
        return [
          OtpErrorText(message: _error),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: kRetryLabel, onPressed: _finish),
        ];
    }
  }
}

/// Where to send what: the short code and the code, large enough to copy
/// by hand if the SMS app does not open.
class SmsCodeCard extends StatelessWidget {
  const SmsCodeCard(
      {super.key, required this.shortcode, required this.smsText});

  final String shortcode;
  final String smsText;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Expanded(child: _Field(label: kSmsToLabel, value: shortcode)),
          Expanded(
            child: _Field(label: kSmsTextLabel, value: smsText, emphasis: true),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textStyles.bodySmall
              .copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(
          value,
          style: context.textStyles.display.copyWith(
            color:
                emphasis ? context.colors.primary : context.colors.textPrimary,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

/// Small spinner with a one-line explanation.
class ProgressNote extends StatelessWidget {
  const ProgressNote({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              label,
              style: context.textStyles.body
                  .copyWith(color: context.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
