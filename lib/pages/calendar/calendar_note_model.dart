import 'package:cloud_firestore/cloud_firestore.dart';

class CalendarNoteModel {
  final String id;
  final String userId;
  final DateTime date;
  final String content;
  final DateTime updatedAt;

  CalendarNoteModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.content,
    required this.updatedAt,
  });

  // Firebase'den veri çekerken
  factory CalendarNoteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarNoteModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      content: data['content'] ?? '',
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // LocalStorage'dan (Map) veri çekerken
  factory CalendarNoteModel.fromMap(Map<String, dynamic> map) {
    return CalendarNoteModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      date: DateTime.parse(map['date']),
      content: map['content'] ?? '',
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  // Firebase ve LocalStorage'a kaydederken
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(), // Local için String, Firebase servisinde Timestamp'e çevrilecek
      'content': content,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}