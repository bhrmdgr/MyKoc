// lib/pages/settings/settings_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsModel {
  final String userName;
  final String userEmail;
  final String userRole;
  final String? profileImageUrl;
  final String appVersion;
  final String currentLanguage;
  final bool isNotificationsEnabled; // ✅ EKLENDİ

  SettingsModel({
    required this.userName,
    required this.userEmail,
    required this.userRole,
    this.profileImageUrl,
    required this.appVersion,
    required this.currentLanguage,
    required this.isNotificationsEnabled, // ✅ EKLENDİ
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

// Delete Reason Enum ve Delete Account Reason Class olduğu gibi kaldı...
enum DeleteReason { notUseful, foundAlternative, privacyConcerns, tooManyNotifications, technicalIssues, other }
class DeleteAccountReason {
  final DeleteReason reason;
  final String? additionalFeedback;
  DeleteAccountReason({required this.reason, this.additionalFeedback});
  Map<String, dynamic> toMap() {
    return {
      'reason': reason.toString().split('.').last,
      'additionalFeedback': additionalFeedback,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}