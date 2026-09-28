enum UserRole { viewer, company, admin }

enum Gender { male, female }

class AppUser {
  final int id;
  final String phoneNumber;
  final UserRole role;
  final Gender? gender;
  final DateTime? birthDate;
  final String? city;
  final String? district;
  final double balance;
  final bool isVerified;

  const AppUser({
    required this.id,
    required this.phoneNumber,
    required this.role,
    this.gender,
    this.birthDate,
    this.city,
    this.district,
    this.balance = 0.0,
    this.isVerified = false,
  });

  int? get age {
    if (birthDate == null) return null;
    final now = DateTime.now();
    var years = now.year - birthDate!.year;
    if (now.month < birthDate!.month ||
        (now.month == birthDate!.month && now.day < birthDate!.day)) {
      years -= 1;
    }
    return years;
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      phoneNumber: json['phone_number'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name.toUpperCase() == (json['role'] as String).toUpperCase(),
        orElse: () => UserRole.viewer,
      ),
      gender: json['gender'] == null
          ? null
          : Gender.values.firstWhere(
              (g) =>
                  g.name.toUpperCase() == (json['gender'] as String).toUpperCase(),
              orElse: () => Gender.male,
            ),
      birthDate: json['birth_date'] == null
          ? null
          : DateTime.parse(json['birth_date'] as String),
      city: json['city'] as String?,
      district: json['district'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}
