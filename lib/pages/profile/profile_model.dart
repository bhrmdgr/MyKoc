class ProfileModel {
  final String userName;
  final String userInitials;
  final String userRole;
  final String? profileImageUrl;

  // Student specific
  final int? badges;
  final int? completionPercentage;
  final int? dayStreak;
  final int? currentLevel;
  final int? currentXP;
  final int? xpToNextLevel;
  final List<String>? recentBadges;

  // Mentor specific
  final int? classCount;
  final int? studentCount;
  final int? activeTasks;
  final int? avgCompletion;

  ProfileModel({
    required this.userName,
    required this.userInitials,
    required this.userRole,
    this.profileImageUrl,
    this.badges,
    this.completionPercentage,
    this.dayStreak,
    this.currentLevel,
    this.currentXP,
    this.xpToNextLevel,
    this.recentBadges,
    this.classCount,
    this.studentCount,
    this.activeTasks,
    this.avgCompletion,
  });

  bool get isMentor => userRole == 'mentor';
  bool get isStudent => userRole == 'student';
}