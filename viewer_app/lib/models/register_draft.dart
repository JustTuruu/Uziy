import 'user.dart';

/// The registration form, validated and waiting for the one-time code.
/// Registration is only sent to the backend together with that code.
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
