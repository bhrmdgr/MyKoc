import 'package:cloud_firestore/cloud_firestore.dart';

class TaskModel {
  final String id;
  final String classId;
  final String mentorId;
  final String title;
  final String description;
  final String priority;
  final DateTime dueDate;
  final DateTime createdAt;
  final List<String>? assignedStudents; // Atanan öğrencilerin ID'leri
  final String? status;
  final List<String>? attachments;

  // Completion details
  final DateTime? completedAt;
  final String? completionNote;
  final List<String>? completionAttachments;

  TaskModel({
    required this.id,
    required this.classId,
    required this.mentorId,
    required this.title,
    required this.description,
    required this.priority,
    required this.dueDate,
    required this.createdAt,
    this.assignedStudents,
    this.status,
    this.attachments,
    this.completedAt,
    this.completionNote,
    this.completionAttachments,
  });

  // Firestore'dan model oluştur
  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return TaskModel(
      id: doc.id,
      classId: data['classId'] ?? '',
      mentorId: data['mentorId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      priority: data['priority'] ?? 'medium',
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      assignedStudents: data['assignedStudents'] != null
          ? List<String>.from(data['assignedStudents'])
          : null,
      status: data['status'],
      attachments: data['attachments'] != null
          ? List<String>.from(data['attachments'])
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

  // Firestore'a kaydet
  Map<String, dynamic> toFirestore() {
    return {
      'classId': classId,
      'mentorId': mentorId,
      'title': title,
      'description': description,
      'priority': priority,
      'dueDate': Timestamp.fromDate(dueDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'assignedStudents': assignedStudents,
      'status': status,
      'attachments': attachments,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completionNote': completionNote,
      'completionAttachments': completionAttachments,
    };
  }

  // Map'e çevir (local storage için)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classId': classId,
      'mentorId': mentorId,
      'title': title,
      'description': description,
      'priority': priority,
      'dueDate': dueDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'assignedStudents': assignedStudents,
      'status': status,
      'attachments': attachments,
      'completedAt': completedAt?.toIso8601String(),
      'completionNote': completionNote,
      'completionAttachments': completionAttachments,
    };
  }

  // Map'ten oluştur (local storage için)
  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] ?? '',
      classId: map['classId'] ?? '',
      mentorId: map['mentorId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      priority: map['priority'] ?? 'medium',
      dueDate: DateTime.parse(map['dueDate']),
      createdAt: DateTime.parse(map['createdAt']),
      assignedStudents: map['assignedStudents'] != null
          ? List<String>.from(map['assignedStudents'])
          : null,
      status: map['status'],
      attachments: map['attachments'] != null
          ? List<String>.from(map['attachments'])
          : null,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'])
          : null,
      completionNote: map['completionNote'],
      completionAttachments: map['completionAttachments'] != null
          ? List<String>.from(map['completionAttachments'])
          : null,
    );
  }

  TaskModel copyWith({
    String? id,
    String? classId,
    String? mentorId,
    String? title,
    String? description,
    String? priority,
    DateTime? dueDate,
    DateTime? createdAt,
    List<String>? assignedStudents,
    String? status,
    List<String>? attachments,
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
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      assignedStudents: assignedStudents ?? this.assignedStudents,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      completedAt: completedAt ?? this.completedAt,
      completionNote: completionNote ?? this.completionNote,
      completionAttachments: completionAttachments ?? this.completionAttachments,
    );
  }
}