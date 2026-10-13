/// Proving the phone before registering (backend `/auth/phone-verifications`,
/// provider verify.mn): the viewer texts [PhoneVerification.smsText] from
/// their own phone to [PhoneVerification.shortcode].
library;

/// Backend `PhoneVerificationStatus`. An unknown value counts as [pending],
/// so the app keeps polling instead of failing.
enum PhoneVerificationStatus {
  pending('PENDING'),
  verified('VERIFIED'),
  expired('EXPIRED');

  const PhoneVerificationStatus(this.wire);
  final String wire;

  static PhoneVerificationStatus fromWire(Object? value) =>
      values.firstWhere((s) => s.wire == value, orElse: () => pending);
}

/// A freshly opened check (`POST /auth/phone-verifications`).
class PhoneVerification {
  const PhoneVerification({
    required this.id,
    required this.phone,
    required this.shortcode,
    required this.smsText,
    required this.smsUri,
    required this.displayInstruction,
    required this.expiresAt,
  });

  factory PhoneVerification.fromJson(Map<String, dynamic> json) =>
      PhoneVerification(
        id: json['verificationId'] as String,
        phone: json['phoneNumber'] as String? ?? '',
        shortcode: json['shortcode'] as String? ?? '',
        smsText: json['smsText'] as String? ?? '',
        smsUri: json['smsUri'] as String? ?? '',
        displayInstruction: json['displayInstruction'] as String? ?? '',
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );

  /// Ours, not the provider's: polled with, then sent with the form.
  final String id;
  final String phone;
  final String shortcode;
  final String smsText;

  /// `sms:` link that opens the SMS app with everything filled in.
  final String smsUri;

  /// The provider's own wording; shown unchanged (it names the phone to
  /// send from, which matters on dual-SIM phones).
  final String displayInstruction;
  final DateTime expiresAt;
}

/// `GET /auth/phone-verifications/{id}`.
class PhoneVerificationState {
  const PhoneVerificationState({required this.status, required this.expiresAt});

  factory PhoneVerificationState.fromJson(Map<String, dynamic> json) =>
      PhoneVerificationState(
        status: PhoneVerificationStatus.fromWire(json['status']),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );

  final PhoneVerificationStatus status;
  final DateTime expiresAt;
}
