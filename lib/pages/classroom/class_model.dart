import 'package:cloud_firestore/cloud_firestore.dart';

class ClassModel {
  final String id;
  final String mentorId;
  final String mentorName;
  final String className;
  final String classType; // 'Mathematics', 'Science', 'Literature', vs.
  final String? emoji; // Emoji avatar
  final String? imageUrl; // Veya resim URL
  final String classCode; // Benzersiz sınıf kodu
  final int studentCount;
  final int taskCount;
  final DateTime createdAt;

  ClassModel({
    required this.id,
    required this.mentorId,
    required this.mentorName,
    required this.className,
    required this.classType,
    this.emoji,
    this.imageUrl,
    required this.classCode,
    this.studentCount = 0,
    this.taskCount = 0,
    required this.createdAt,
  });

  // Firestore'dan model oluştur
  factory ClassModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassModel(
      id: doc.id,
      mentorId: data['mentorId'] ?? '',
      mentorName: data['mentorName'] ?? '',
      className: data['className'] ?? '',
      classType: data['classType'] ?? '',
      emoji: data['emoji'],
      imageUrl: data['imageUrl'],
      classCode: data['classCode'] ?? '',
      studentCount: data['studentCount'] ?? 0,
      taskCount: data['taskCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Firestore'a kaydet
  // Map'e çevir (local storage için)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mentorId': mentorId,
      'mentorName': mentorName,
      'className': className,
      'classType': classType,
      'emoji': emoji,
      'imageUrl': imageUrl,
      'classCode': classCode,
      'studentCount': studentCount,
      'taskCount': taskCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Map'ten oluştur (local storage için)
  factory ClassModel.fromMap(Map<String, dynamic> map) {
    return ClassModel(
      id: map['id'] ?? '',
      mentorId: map['mentorId'] ?? '',
      mentorName: map['mentorName'] ?? '',
      className: map['className'] ?? '',
      classType: map['classType'] ?? '',
      emoji: map['emoji'],
      imageUrl: map['imageUrl'],
      classCode: map['classCode'] ?? '',
      studentCount: map['studentCount'] ?? 0,
      taskCount: map['taskCount'] ?? 0,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
  // Background color class type'a göre
  int getColorFromType() {
    switch (classType.toLowerCase()) {
      case 'mathematics':
      case 'math':
        return 0xFF3B82F6; // Blue
      case 'science':
        return 0xFF10B981; // Green
      case 'literature':
      case 'english':
        return 0xFF8B5CF6; // Purple
      case 'history':
        return 0xFFF59E0B; // Orange
      case 'art':
      case 'design':
        return 0xFFEC4899; // Pink
      case 'music':
        return 0xFF6366F1; // Indigo
      case 'programming':
      case 'coding':
        return 0xFF14B8A6; // Teal
      default:
        return 0xFF6366F1; // Default purple
    }
  }
}