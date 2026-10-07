import 'dart:async';

import 'package:flutter/material.dart';

import '../../widgets/ui.dart';
import 'otp_logic.dart';

/// Counts the resend lock down once a second. Mix into the State of a screen
/// that sends a code: call [startResendCooldown] right after every send.
mixin ResendCooldown<T extends StatefulWidget> on State<T> {
  Timer? _cooldownTimer;
  int resendSecondsLeft = 0;

  void startResendCooldown([int seconds = kOtpResendSeconds]) {
    _cooldownTimer?.cancel();
    setState(() => resendSecondsLeft = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => resendSecondsLeft--);
      if (resendSecondsLeft <= 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }
}

/// Icon medallion, [title] and [subtitle] at the top of a code screen.
class OtpHeader extends StatelessWidget {
  const OtpHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.28),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 26, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Semantics(
          header: true,
          child: Text(title, style: AppTextStyles.display),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Red one-line message under the code boxes; takes no space when empty.
class OtpErrorText extends StatelessWidget {
  const OtpErrorText({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        text,
        key: const ValueKey('otp-error'),
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerLight),
      ),
    );
  }
}

/// 'Дахин илгээх' — greyed with the time left while locked.
class ResendCodeButton extends StatelessWidget {
  const ResendCodeButton({
    super.key,
    required this.secondsLeft,
    required this.onPressed,
    this.busy = false,
  });

  final int secondsLeft;
  final VoidCallback onPressed;

  /// A resend request is in flight.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = secondsLeft <= 0 && !busy;
    return Center(
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textTertiary,
          minimumSize: const Size(0, AppLayout.minTapTarget),
        ),
        child: Text(resendLabel(secondsLeft)),
      ),
    );
  }
}
