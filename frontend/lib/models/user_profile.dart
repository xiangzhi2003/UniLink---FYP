// Programmer Name : Mr. Chiang Xiang Zhi, Student, APU, Technology Park Malaysia
// Program Name    : user_profile.dart
// Description     : Data model for a UserProfile -- a student or admin account.
// First Written on: Friday,03-Jul-2026
// Edited on       : Friday,17-Jul-2026

class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? university;
  final String role; // student | admin (granted manually in the database)
  final bool suspended;

  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.university,
    this.role = 'student',
    this.suspended = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      university: json['university'] as String?,
      role: json['role'] as String? ?? 'student',
      suspended: json['suspended'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'university': university,
    };
  }
}
