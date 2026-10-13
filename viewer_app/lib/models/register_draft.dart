import 'phone_verification.dart';
import 'user.dart';

/// The registration form, validated and waiting for the phone to be proven.
/// Registration is only sent to the backend with a confirmed check.
class RegisterDraft {
  const RegisterDraft({
    required this.phone,
    required this.password,
    required this.gender,
    required this.birthDate,
    required this.city,
    this.district,
  });

  final String phone;
  final String password;
  final Gender gender;
  final DateTime birthDate;
  final String city;
  final String? district;
}

/// What the phone-verification page needs: the form and the opened check.
class PendingRegistration {
  const PendingRegistration({required this.draft, required this.verification});

  final RegisterDraft draft;
  final PhoneVerification verification;
}
