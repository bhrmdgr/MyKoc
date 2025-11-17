class HomeModel {
  final String userName;
  final String userInitials;
  final String userRole;
  final String? profileImageUrl;
  final int completedTasks;
  final int totalTasks;
  final List<SessionModel> upcomingSessions;

  HomeModel({
    required this.userName,
    required this.userInitials,
    required this.userRole,
    this.profileImageUrl,
    this.completedTasks = 0,
    this.totalTasks = 5,
    this.upcomingSessions = const [],
  });

  double get progressPercentage {
    if (totalTasks == 0) return 0;
    return (completedTasks / totalTasks) * 100;
  }

  bool get isMentor => userRole == 'mentor';
  bool get isStudent => userRole == 'student';

  HomeModel copyWith({
    String? userName,
    String? userInitials,
    String? userRole,
    String? profileImageUrl,
    int? completedTasks,
    int? totalTasks,
    List<SessionModel>? upcomingSessions,
  }) {
    return HomeModel(
      userName: userName ?? this.userName,
      userInitials: userInitials ?? this.userInitials,
      userRole: userRole ?? this.userRole,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      completedTasks: completedTasks ?? this.completedTasks,
      totalTasks: totalTasks ?? this.totalTasks,
      upcomingSessions: upcomingSessions ?? this.upcomingSessions,
    );
  }
}

class SessionModel {
  final String id;
  final String mentorName;
  final String subject;
  final DateTime dateTime;
  final String avatar;
  final String status;

  SessionModel({
    required this.id,
    required this.mentorName,
    required this.subject,
    required this.dateTime,
    required this.avatar,
    this.status = 'upcoming',
  });

  String get formattedDate {
    final day = dateTime.day;
    final month = _getMonthName(dateTime.month);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day $month, $hour:$minute';
  }

  String _getMonthName(int month) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return months[month - 1];
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] ?? '',
      mentorName: json['mentorName'] ?? '',
      subject: json['subject'] ?? '',
      dateTime: DateTime.parse(json['dateTime']),
      avatar: json['avatar'] ?? '',
      status: json['status'] ?? 'upcoming',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mentorName': mentorName,
      'subject': subject,
      'dateTime': dateTime.toIso8601String(),
      'avatar': avatar,
      'status': status,
    };
  }
}