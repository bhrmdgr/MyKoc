class UserInfoModel {
  final String name;
  final String email;
  final String? phone;
  final String? bio;
  final String? profileImageUrl;
  final DateTime? createdAt;

  UserInfoModel({
    required this.name,
    required this.email,
    this.phone,
    this.bio,
    this.profileImageUrl,
    this.createdAt,
  });

  String get userInitials {
    final names = name.trim().split(' ');
    if (names.isEmpty) return 'U';
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'bio': bio,
      'profileImage': profileImageUrl,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}