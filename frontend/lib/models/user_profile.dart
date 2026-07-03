class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? university;

  const UserProfile({
    required this.id,
    required this.email,
    this.fullName,
    this.university,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      university: json['university'] as String?,
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
