enum UserRole { viewer, company, admin }

enum Gender { male, female }

/// Client-side view of the backend's `Me` DTO (see AuthController.kt).
/// Fields match the JSON exactly (camelCase). `birthDate` is captured
/// during registration but the server never echoes it back — only the
/// computed `age`.
class AppUser {
  final int id;
  final String phoneNumber;
  final UserRole role;
  final Gender? gender;
  final int? age;
  final String? city;
  final String? district;
  final double balance;
  final bool isVerified;
  final String? companyName;

  const AppUser({
    required this.id,
    required this.phoneNumber,
    required this.role,
    this.gender,
    this.age,
    this.city,
    this.district,
    this.balance = 0.0,
    this.isVerified = false,
    this.companyName,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: (json['id'] as num).toInt(),
      phoneNumber: json['phoneNumber'] as String,
      role: UserRole.values.firstWhere(
        (r) => r.name.toUpperCase() == (json['role'] as String).toUpperCase(),
        orElse: () => UserRole.viewer,
      ),
      gender: json['gender'] == null
          ? null
          : Gender.values.firstWhere(
              (g) =>
                  g.name.toUpperCase() ==
                  (json['gender'] as String).toUpperCase(),
              orElse: () => Gender.male,
            ),
      age: (json['age'] as num?)?.toInt(),
      city: json['city'] as String?,
      district: json['district'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      isVerified: json['isVerified'] as bool? ?? false,
      companyName: json['companyName'] as String?,
    );
  }
}
