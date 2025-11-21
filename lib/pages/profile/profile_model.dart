import 'package:flutter/foundation.dart';

class ProfileModel {
  final String userName;
  final String userInitials;
  final String userRole;
  final String? profileImageUrl;
  final String email;

  // Student specific
  final int? totalClasses; // Toplam sınıf sayısı
  final int? totalTasks; // Toplam task sayısı
  final int? completedTasks; // Tamamlanan task sayısı
  final int? completionPercentage; // Tamamlama yüzdesi

  final int? badges;
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
    required this.email,
    // Student fields
    this.totalClasses,
    this.totalTasks,
    this.completedTasks,
    this.completionPercentage,
    this.badges,
    this.dayStreak,
    this.currentLevel,
    this.currentXP,
    this.xpToNextLevel,
    this.recentBadges,
    // Mentor fields
    this.classCount,
    this.studentCount,
    this.activeTasks,
    this.avgCompletion,
  });

  bool get isMentor => userRole == 'mentor';
  bool get isStudent => userRole == 'student';

  // Completion percentage hesaplama helper
  int get calculatedCompletionPercentage {
    if (totalTasks == null || totalTasks == 0) return 0;
    if (completedTasks == null) return 0;
    return ((completedTasks! / totalTasks!) * 100).round();
  }

  // copyWith metodu buraya eklendi
  ProfileModel copyWith({
    String? userName,
    String? userInitials,
    String? userRole,
    String? profileImageUrl,
    String? email,
    int? totalClasses,
    int? totalTasks,
    int? completedTasks,
    int? completionPercentage,
    int? badges,
    int? dayStreak,
    int? currentLevel,
    int? currentXP,
    int? xpToNextLevel,
    List<String>? recentBadges,
    int? classCount,
    int? studentCount,
    int? activeTasks,
    int? avgCompletion,
  }) {
    return ProfileModel(
      userName: userName ?? this.userName,
      userInitials: userInitials ?? this.userInitials,
      userRole: userRole ?? this.userRole,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      email: email ?? this.email,
      totalClasses: totalClasses ?? this.totalClasses,
      totalTasks: totalTasks ?? this.totalTasks,
      completedTasks: completedTasks ?? this.completedTasks,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      badges: badges ?? this.badges,
      dayStreak: dayStreak ?? this.dayStreak,
      currentLevel: currentLevel ?? this.currentLevel,
      currentXP: currentXP ?? this.currentXP,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      recentBadges: recentBadges ?? this.recentBadges,
      classCount: classCount ?? this.classCount,
      studentCount: studentCount ?? this.studentCount,
      activeTasks: activeTasks ?? this.activeTasks,
      avgCompletion: avgCompletion ?? this.avgCompletion,
    );
  }
}