import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mykoc/pages/classroom/class_model.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Mentörün tüm öğrencilerini getir (Unique öğrenci sayısı hesabı için)
  Future<List<Map<String, dynamic>>> getMentorAllStudents(String mentorId) async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('mentorId', isEqualTo: mentorId)
          .orderBy('enrolledAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('❌ Error fetching all mentor students: $e');
      return [];
    }
  }

  /// Mentörün tüm sınıflarını detaylı şekilde getir
  Future<List<ClassModel>> getMentorClassesDetailed(String mentorId) async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('mentorId', isEqualTo: mentorId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ClassModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error fetching mentor classes: $e');
      return [];
    }
  }

  /// Öğrencinin sınıftan ayrılması
  Future<bool> leaveClass({
    required String studentId,
    required String classId,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Sınıfın students listesinden öğrenciyi kaldır
      final classRef = _firestore.collection('classes').doc(classId);
      batch.update(classRef, {
        'students': FieldValue.arrayRemove([studentId]),
        'studentCount': FieldValue.increment(-1),
      });

      // 2. Öğrencinin users/classes listesinden sınıfı kaldır
      final userRef = _firestore.collection('users').doc(studentId);
      batch.update(userRef, {
        'classes': FieldValue.arrayRemove([classId]),
      });

      await batch.commit();

      debugPrint('✅ Student removed from class successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error leaving class: $e');
      return false;
    }
  }

  /// Mentörün sınıfı silmesi (Detaylı temizlik)
  Future<bool> deleteClass({
    required String classId,
    required String mentorId,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Sınıfı bul
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (!classDoc.exists) {
        debugPrint('❌ Class not found');
        return false;
      }

      final classData = classDoc.data()!;
      final students = List<String>.from(classData['students'] ?? []);

      // 2. Her öğrencinin kullanıcı kaydından bu sınıfı sil
      for (final studentId in students) {
        final userRef = _firestore.collection('users').doc(studentId);
        batch.update(userRef, {
          'classes': FieldValue.arrayRemove([classId]),
        });
      }

      // 3. Mentörün kayıtlarından sınıfı sil
      final mentorRef = _firestore.collection('users').doc(mentorId);
      batch.update(mentorRef, {
        'classes': FieldValue.arrayRemove([classId]),
      });

      // 4. Sınıf dokümanını sil
      final classRef = _firestore.collection('classes').doc(classId);
      batch.delete(classRef);

      // 5. Sınıfa ait taskları sil
      final tasksSnapshot = await _firestore
          .collection('tasks')
          .where('classId', isEqualTo: classId)
          .get();

      for (final taskDoc in tasksSnapshot.docs) {
        batch.delete(taskDoc.reference);
      }

      // 6. Sınıfa ait duyuruları sil
      final announcementsSnapshot = await _firestore
          .collection('announcements')
          .where('classId', isEqualTo: classId)
          .get();

      for (final announcementDoc in announcementsSnapshot.docs) {
        batch.delete(announcementDoc.reference);
      }

      // 7. Students koleksiyonundaki kayıtları sil
      final studentRecords = await _firestore
          .collection('students')
          .where('classId', isEqualTo: classId)
          .get();

      for(final doc in studentRecords.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      debugPrint('✅ Class and related data deleted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting class: $e');
      return false;
    }
  }

  // Helper metodlar (Gerekirse kullanılabilir)
  Future<int> getMentorTotalStudentCount(String mentorId) async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('mentorId', isEqualTo: mentorId)
          .get();
      int totalStudents = 0;
      for (final doc in snapshot.docs) {
        totalStudents += (doc.data()['studentCount'] as int?) ?? 0;
      }
      return totalStudents;
    } catch (e) {
      return 0;
    }
  }
}