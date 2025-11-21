import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mykoc/pages/classroom/class_model.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class ClassroomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  // Sınıf oluştur
  Future<String?> createClass({
    required String mentorId,
    required String mentorName,
    required String className,
    required String classType,
    required String emoji,
    String? imageUrl,
  }) async {
    try {
      final classCode = _generateClassCode();

      // Sınıf oluştur
      final docRef = await _firestore.collection('classes').add({
        'mentorId': mentorId,
        'mentorName': mentorName,
        'className': className,
        'classType': classType,
        'emoji': emoji,
        'imageUrl': imageUrl,
        'classCode': classCode,
        'studentCount': 0,
        'taskCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Mentor'un sınıf sayısını artır
      await _firestore.collection('mentors').doc(mentorId).update({
        'classCount': FieldValue.increment(1),
      });

      debugPrint('✅ Class created: ${docRef.id} with code: $classCode');
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating class: $e');
      return null;
    }
  }

  // Mentör'un tüm sınıflarını çek
  Future<List<ClassModel>> getMentorClasses(String mentorId) async {
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

  // Öğrenci'nin sınıflarını çek (GÜNCELLEND İ - birden fazla sınıf)
  Future<List<ClassModel>> getStudentClasses(String studentId) async {
    try {
      debugPrint('🔍 Fetching student classes for: $studentId');

      // Öğrencinin kayıtlı olduğu sınıfları bul
      final studentSnapshot = await _firestore
          .collection('students')
          .where('uid', isEqualTo: studentId)
          .get();

      if (studentSnapshot.docs.isEmpty) {
        debugPrint('📭 No student records found');
        return [];
      }

      // Tüm sınıf ID'lerini topla
      final classIds = studentSnapshot.docs
          .map((doc) => doc.data()['classId'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      debugPrint('📚 Found ${classIds.length} class IDs');

      if (classIds.isEmpty) return [];

      // Sınıfları çek
      final classes = <ClassModel>[];
      for (var classId in classIds) {
        try {
          final classDoc = await _firestore
              .collection('classes')
              .doc(classId)
              .get();

          if (classDoc.exists) {
            classes.add(ClassModel.fromFirestore(classDoc));
          }
        } catch (e) {
          debugPrint('❌ Error fetching class $classId: $e');
        }
      }

      // Cache'e kaydet
      await _localStorage.saveStudentClasses(
        classes.map((c) => c.toMap()).toList(),
      );

      debugPrint('✅ Fetched ${classes.length} classes for student');
      return classes;
    } catch (e) {
      debugPrint('❌ Error fetching student classes: $e');
      return [];
    }
  }

  // Sınıf detayını çek
  Future<ClassModel?> getClassById(String classId) async {
    try {
      final doc = await _firestore.collection('classes').doc(classId).get();

      if (!doc.exists) return null;

      return ClassModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error fetching class: $e');
      return null;
    }
  }

  // Sınıf koduna göre sınıf bul
  Future<ClassModel?> getClassByCode(String classCode) async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('classCode', isEqualTo: classCode.trim().toUpperCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      return ClassModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      debugPrint('❌ Error finding class by code: $e');
      return null;
    }
  }

  // Sınıfa öğrenci ekle
  Future<bool> addStudentToClass({
    required String classId,
    required String studentId,
    required String studentName,
    required String studentEmail,
  }) async {
    try {
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (!classDoc.exists) {
        throw 'Class not found';
      }

      final mentorId = classDoc.data()?['mentorId'];
      final classCode = classDoc.data()?['classCode'];

      // Student sub-collection'a ekle
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('students')
          .doc(studentId)
          .set({
        'uid': studentId,
        'name': studentName,
        'email': studentEmail,
        'enrolledAt': FieldValue.serverTimestamp(),
      });

      // Students collection'a yeni kayıt ekle (her sınıf için ayrı kayıt)
      await _firestore
          .collection('students')
          .add({
        'uid': studentId,
        'name': studentName,
        'email': studentEmail,
        'mentorId': mentorId,
        'classId': classId,
        'classCode': classCode,
        'enrolledAt': FieldValue.serverTimestamp(),
      });

      // Sınıfın öğrenci sayısını artır
      await _firestore.collection('classes').doc(classId).update({
        'studentCount': FieldValue.increment(1),
      });

      // Mentor'un toplam öğrenci sayısını artır
      await _firestore.collection('mentors').doc(mentorId).update({
        'studentCount': FieldValue.increment(1),
      });

      // Local cache'i güncelle
      final localStudents = _localStorage.getClassStudents(classId) ?? [];
      localStudents.add({
        'uid': studentId,
        'name': studentName,
        'email': studentEmail,
        'enrolledAt': DateTime.now().toIso8601String(),
      });
      await _localStorage.saveClassStudents(classId, localStudents);

      // Class'ın student count'unu güncelle
      final localClass = _localStorage.getClass(classId);
      if (localClass != null) {
        localClass['studentCount'] = (localClass['studentCount'] ?? 0) + 1;
        await _localStorage.saveClass(classId, localClass);
      }

      // Öğrencinin sınıf listesine ekle
      final studentClasses = _localStorage.getStudentClasses() ?? [];
      final classModel = ClassModel.fromFirestore(classDoc);
      if (!studentClasses.any((c) => c['id'] == classId)) {
        studentClasses.add(classModel.toMap());
        await _localStorage.saveStudentClasses(studentClasses);
      }

      debugPrint('✅ Student added to class successfully + local cache updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding student to class: $e');
      return false;
    }
  }

  // Sınıftan öğrenci çıkar
  Future<bool> removeStudentFromClass({
    required String classId,
    required String studentId,
  }) async {
    try {
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (!classDoc.exists) {
        throw 'Class not found';
      }

      final mentorId = classDoc.data()?['mentorId'];

      // Student sub-collection'dan sil
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('students')
          .doc(studentId)
          .delete();

      // Students collection'dan bu sınıfa ait kaydı sil
      final studentRecords = await _firestore
          .collection('students')
          .where('uid', isEqualTo: studentId)
          .where('classId', isEqualTo: classId)
          .get();

      for (var doc in studentRecords.docs) {
        await doc.reference.delete();
      }

      // Sınıfın öğrenci sayısını azalt
      await _firestore.collection('classes').doc(classId).update({
        'studentCount': FieldValue.increment(-1),
      });

      // Mentor'un toplam öğrenci sayısını azalt
      await _firestore.collection('mentors').doc(mentorId).update({
        'studentCount': FieldValue.increment(-1),
      });

      // Local cache'den çıkar
      final studentClasses = _localStorage.getStudentClasses() ?? [];
      studentClasses.removeWhere((c) => c['id'] == classId);
      await _localStorage.saveStudentClasses(studentClasses);

      debugPrint('✅ Student removed from class successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error removing student from class: $e');
      return false;
    }
  }

  // Sınıfı güncelle
  Future<bool> updateClass({
    required String classId,
    String? className,
    String? classType,
    String? emoji,
    String? imageUrl,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (className != null) updates['className'] = className;
      if (classType != null) updates['classType'] = classType;
      if (emoji != null) updates['emoji'] = emoji;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;

      if (updates.isEmpty) return false;

      await _firestore.collection('classes').doc(classId).update(updates);

      debugPrint('✅ Class updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating class: $e');
      return false;
    }
  }

  // Sınıftaki öğrencileri çek
  Future<List<Map<String, dynamic>>> getClassStudents(String classId) async {
    try {
      debugPrint('🔍 Fetching students for class: $classId');

      final snapshot = await _firestore
          .collection('classes')
          .doc(classId)
          .collection('students')
          .get();

      debugPrint('📊 Firestore query result: ${snapshot.docs.length} documents');

      final students = snapshot.docs.map((doc) {
        final data = doc.data();

        // Timestamp'i String'e çevir
        if (data['enrolledAt'] is Timestamp) {
          data['enrolledAt'] = (data['enrolledAt'] as Timestamp)
              .toDate()
              .toIso8601String();
        }

        debugPrint('📄 Student: ${data['name']} - ${data['email']}');
        return data;
      }).toList();

      debugPrint('✅ Parsed ${students.length} students');

      // Cache'e kaydet
      await _localStorage.saveClassStudents(classId, students);
      debugPrint('💾 Students cached locally');

      return students;
    } catch (e) {
      debugPrint('❌ Error fetching class students: $e');
      return [];
    }
  }

  // Sınıfı sil
  Future<bool> deleteClass(String classId, String mentorId) async {
    try {
      // Sınıftaki öğrencileri sil
      final studentsSnapshot = await _firestore
          .collection('classes')
          .doc(classId)
          .collection('students')
          .get();

      final batch = _firestore.batch();

      // Students collection'dan bu sınıfa ait kayıtları sil
      final studentRecords = await _firestore
          .collection('students')
          .where('classId', isEqualTo: classId)
          .get();

      for (var doc in studentRecords.docs) {
        batch.delete(doc.reference);
      }

      // Sub-collection'daki öğrencileri sil
      for (var doc in studentsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Sınıfı sil
      batch.delete(_firestore.collection('classes').doc(classId));

      // Mentor'un sınıf sayısını azalt
      batch.update(
        _firestore.collection('mentors').doc(mentorId),
        {
          'classCount': FieldValue.increment(-1),
          'studentCount': FieldValue.increment(-studentsSnapshot.docs.length),
        },
      );

      await batch.commit();

      debugPrint('✅ Class deleted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting class: $e');
      return false;
    }
  }

  // Sınıf kodu oluştur (6 karakter)
  String _generateClassCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var code = '';

    for (var i = 0; i < 6; i++) {
      code += chars[(random + i) % chars.length];
    }

    return code;
  }

  // Stream: Sınıfları gerçek zamanlı dinle
  Stream<List<ClassModel>> watchMentorClasses(String mentorId) {
    return _firestore
        .collection('classes')
        .where('mentorId', isEqualTo: mentorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ClassModel.fromFirestore(doc))
        .toList());
  }

  // Stream: Sınıf detayını gerçek zamanlı dinle
  Stream<ClassModel?> watchClass(String classId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .snapshots()
        .map((doc) => doc.exists ? ClassModel.fromFirestore(doc) : null);
  }
}