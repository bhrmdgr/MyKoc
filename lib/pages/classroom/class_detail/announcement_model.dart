import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementModel {
  final String id;
  final String classId;
  final String mentorId;
  final String title;
  final String description;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AnnouncementModel({
    required this.id,
    required this.classId,
    required this.mentorId,
    required this.title,
    required this.description,
    required this.createdAt,
    this.updatedAt,
  });

  // Firestore'dan model oluştur
  factory AnnouncementModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AnnouncementModel(
      id: doc.id,
      classId: data['classId'] ?? '',
      mentorId: data['mentorId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Firestore'a kaydet için Map
  Map<String, dynamic> toMap() {
    return {
      'classId': classId,
      'mentorId': mentorId,
      'title': title,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Local storage için Map (Timestamp olmadan)
  Map<String, dynamic> toLocalMap() {
    return {
      'id': id,
      'classId': classId,
      'mentorId': mentorId,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Local storage'dan model oluştur
  factory AnnouncementModel.fromLocalMap(Map<String, dynamic> map) {
    return AnnouncementModel(
      id: map['id'] ?? '',
      classId: map['classId'] ?? '',
      mentorId: map['mentorId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
    );
  }

  // Copy with method
  AnnouncementModel copyWith({
    String? id,
    String? classId,
    String? mentorId,
    String? title,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      mentorId: mentorId ?? this.mentorId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}