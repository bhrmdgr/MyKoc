class SettingsModel {
  final String userName;
  final String userEmail;
  final String userRole;
  final String? profileImageUrl;
  final String appVersion;
  final String currentLanguage;

  SettingsModel({
    required this.userName,
    required this.userEmail,
    required this.userRole,
    this.profileImageUrl,
    required this.appVersion,
    required this.currentLanguage,
  });

  String get userInitials {
    final names = userName.trim().split(' ');
    if (names.isEmpty) return 'U';
    if (names.length == 1) return names[0][0].toUpperCase();
    return '${names[0][0]}${names[names.length - 1][0]}'.toUpperCase();
  }

  String get roleDisplayName {
    switch (userRole.toLowerCase()) {
      case 'mentor':
        return 'Mentor';
      case 'student':
        return 'Student';
      default:
        return 'User';
    }
  }
}

class DeleteAccountReason {
  final String reason;
  final String? additionalInfo;
  final DateTime timestamp;

  DeleteAccountReason({
    required this.reason,
    this.additionalInfo,
  }) : timestamp = DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'reason': reason,
      'additionalInfo': additionalInfo,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}