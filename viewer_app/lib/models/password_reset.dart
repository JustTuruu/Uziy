import 'phone_verification.dart';

/// A password reset in progress: the account's phone and the check that
/// proves it (opened with purpose PASSWORD_RESET). Travels between the
/// forgot-password, verify and new-password pages.
class PendingPasswordReset {
  const PendingPasswordReset({required this.phone, required this.verification});

  final String phone;
  final PhoneVerification verification;
}
