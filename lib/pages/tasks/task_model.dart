import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String classId;
  final String mentorId;
  final String title;
  final String description;
  final DateTime dueDate;
  final String priority; // 'low', 'medium', 'high'
  final List<String> assignedStudents; // student IDs
  final List<String>? attachments; // file URLs
  final DateTime createdAt;

  // Yeni alanlar - öğrenci bazlı durum bilgisi
  final String? status; // 'not_started', 'in_progress', 'completed'
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? completionNote;
  final List<String>? completionAttachments;

  TaskModel({
    required this.id,
    required this.classId,
    required this.mentorId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.assignedStudents,
    this.attachments,
    required this.createdAt,
    this.status,
    this.startedAt,
    this.completedAt,
    this.completionNote,
    this.completionAttachments,
  });

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      classId: data['classId'] ?? '',
      mentorId: data['mentorId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      priority: data['priority'] ?? 'medium',
      assignedStudents: List<String>.from(data['assignedStudents'] ?? []),
      attachments: data['attachments'] != null
          ? List<String>.from(data['attachments'])
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'],
      startedAt: data['startedAt'] != null
          ? (data['startedAt'] as Timestamp).toDate()
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      completionNote: data['completionNote'],
      completionAttachments: data['completionAttachments'] != null
          ? List<String>.from(data['completionAttachments'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'mentorId': mentorId,
      'title': title,
      'description': description,
      'dueDate': Timestamp.fromDate(dueDate),
      'priority': priority,
      'assignedStudents': assignedStudents,
      'attachments': attachments,
      'createdAt': Timestamp.fromDate(createdAt),
      if (status != null) 'status': status,
      if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
      if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
      if (completionNote != null) 'completionNote': completionNote,
      if (completionAttachments != null) 'completionAttachments': completionAttachments,
    };
  }

  TaskModel copyWith({
    String? id,
    String? classId,
    String? mentorId,
    String? title,
    String? description,
    DateTime? dueDate,
    String? priority,
    List<String>? assignedStudents,
    List<String>? attachments,
    DateTime? createdAt,
    String? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? completionNote,
    List<String>? completionAttachments,
  }) {
    return TaskModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      mentorId: mentorId ?? this.mentorId,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      assignedStudents: assignedStudents ?? this.assignedStudents,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      completionNote: completionNote ?? this.completionNote,
      completionAttachments: completionAttachments ?? this.completionAttachments,
    );
  }
}