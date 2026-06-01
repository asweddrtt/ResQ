class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? role;
  final String? status;

  UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.role,
    this.status,
  });

  // This factory takes the raw JSON from your Supabase database
  // and neatly turns it into a Dart object you can use in your app!
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? 'Unknown User',
      email: json['email'] ?? '',
      phone: json['phone'],
      role: json['role'],
      status: json['status'],
    );
  }
}