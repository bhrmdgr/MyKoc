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
    };
  }
}