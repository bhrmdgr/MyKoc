// lib/firebase/classroom/classroom_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mykoc/pages/classroom/class_model.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:mykoc/firebase/messaging/messaging_service.dart';

class ClassroomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService();
  final MessagingService _messagingService = MessagingService();

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

      await _messagingService.createClassChatRoom(
        classId: docRef.id,
        className: className,
        mentorId: mentorId,
        mentorName: mentorName,
        emoji: emoji,
        imageUrl: imageUrl,
      );

      await _firestore.collection('mentors').doc(mentorId).update({
        'classCount': FieldValue.increment(1),
      });

      return docRef.id;
    } catch (e) {
      return null;
    }
  }

  Future<List<ClassModel>> getMentorClasses(String mentorId) async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('mentorId', isEqualTo: mentorId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => ClassModel.fromFirestore(doc)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<ClassModel>> getStudentClasses(String studentId) async {
    try {
      final studentSnapshot = await _firestore
          .collection('students')
          .where('uid', isEqualTo: studentId)
          .get();

      if (studentSnapshot.docs.isEmpty) return [];

      final classIds = studentSnapshot.docs
          .map((doc) => doc.data()['classId'] as String?)
          .where((id) => id != null)
          .toSet().toList();

      final classes = <ClassModel>[];
      for (var classId in classIds) {
        final classDoc = await _firestore.collection('classes').doc(classId).get();
        if (classDoc.exists) classes.add(ClassModel.fromFirestore(classDoc));
      }

      await _localStorage.saveStudentClasses(classes.map((c) => c.toMap()).toList());
      return classes;
    } catch (e) {
      return [];
    }
  }

  Future<ClassModel?> getClassById(String classId) async {
    try {
      final doc = await _firestore.collection('classes').doc(classId).get();
      return doc.exists ? ClassModel.fromFirestore(doc) : null;
    } catch (e) {
      return null;
    }
  }

  Future<ClassModel?> getClassByCode(String classCode) async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('classCode', isEqualTo: classCode.trim().toUpperCase())
          .limit(1).get();
      return snapshot.docs.isEmpty ? null : ClassModel.fromFirestore(snapshot.docs.first);
    } catch (e) {
      return null;
    }
  }

  Future<bool> addStudentToClass({
    required String classId,
    required String studentId,
    required String studentName,
    required String studentEmail,
  }) async {
    try {
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (!classDoc.exists) throw 'Class not found';

      final mentorId = classDoc.data()?['mentorId'];
      final classCode = classDoc.data()?['classCode'];

      await _firestore.collection('classes').doc(classId).collection('students').doc(studentId).set({
        'uid': studentId, 'name': studentName, 'email': studentEmail, 'enrolledAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('students').add({
        'uid': studentId, 'name': studentName, 'email': studentEmail, 'mentorId': mentorId, 'classId': classId, 'classCode': classCode, 'enrolledAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('classes').doc(classId).update({'studentCount': FieldValue.increment(1)});
      await _firestore.collection('mentors').doc(mentorId).update({'studentCount': FieldValue.increment(1)});

      final chatRoomId = await _messagingService.getChatRoomIdByClassId(classId);
      if (chatRoomId != null) {
        final userData = await _firestore.collection('users').doc(studentId).get();
        await _messagingService.addStudentToChatRoom(
          chatRoomId: chatRoomId,
          studentId: studentId,
          studentName: studentName,
          studentImageUrl: userData.data()?['profileImage'],
        );
      }

      final localStudents = _localStorage.getClassStudents(classId) ?? [];
      localStudents.add({'uid': studentId, 'name': studentName, 'email': studentEmail, 'enrolledAt': DateTime.now().toIso8601String()});
      await _localStorage.saveClassStudents(classId, localStudents);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeStudentFromClass({required String classId, required String studentId}) async {
    try {
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (!classDoc.exists) throw 'Class not found';
      final mentorId = classDoc.data()?['mentorId'];

      await _firestore.collection('classes').doc(classId).collection('students').doc(studentId).delete();
      final studentRecords = await _firestore.collection('students').where('uid', isEqualTo: studentId).where('classId', isEqualTo: classId).get();
      for (var doc in studentRecords.docs) { await doc.reference.delete(); }

      await _firestore.collection('classes').doc(classId).update({'studentCount': FieldValue.increment(-1)});
      await _firestore.collection('mentors').doc(mentorId).update({'studentCount': FieldValue.increment(-1)});

      final studentClasses = _localStorage.getStudentClasses() ?? [];
      studentClasses.removeWhere((c) => c['id'] == classId);
      await _localStorage.saveStudentClasses(studentClasses);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateClass({required String classId, String? className, String? classType, String? emoji, String? imageUrl}) async {
    try {
      final updates = <String, dynamic>{};
      if (className != null) updates['className'] = className;
      if (classType != null) updates['classType'] = classType;
      if (emoji != null) updates['emoji'] = emoji;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
      if (updates.isEmpty) return false;
      await _firestore.collection('classes').doc(classId).update(updates);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getClassStudents(String classId) async {
    try {
      final snapshot = await _firestore.collection('classes').doc(classId).collection('students').get();
      final students = snapshot.docs.map((doc) {
        final data = doc.data();
        if (data['enrolledAt'] is Timestamp) data['enrolledAt'] = (data['enrolledAt'] as Timestamp).toDate().toIso8601String();
        return data;
      }).toList();
      await _localStorage.saveClassStudents(classId, students);
      return students;
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteClass(String classId, String mentorId) async {
    try {
      final studentsSnapshot = await _firestore.collection('classes').doc(classId).collection('students').get();
      final batch = _firestore.batch();
      final studentRecords = await _firestore.collection('students').where('classId', isEqualTo: classId).get();
      for (var doc in studentRecords.docs) { batch.delete(doc.reference); }
      for (var doc in studentsSnapshot.docs) { batch.delete(doc.reference); }
      batch.delete(_firestore.collection('classes').doc(classId));
      batch.update(_firestore.collection('mentors').doc(mentorId), {'classCount': FieldValue.increment(-1), 'studentCount': FieldValue.increment(-studentsSnapshot.docs.length)});
      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  String _generateClassCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(6, (index) => chars[DateTime.now().microsecondsSinceEpoch % chars.length]).join();
  }

  Stream<List<ClassModel>> watchMentorClasses(String mentorId) {
    return _firestore.collection('classes').where('mentorId', isEqualTo: mentorId).orderBy('createdAt', descending: true).snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ClassModel.fromFirestore(doc)).toList());
  }

  Stream<ClassModel?> watchClass(String classId) {
    return _firestore.collection('classes').doc(classId).snapshots().map((doc) => doc.exists ? ClassModel.fromFirestore(doc) : null);
  }
}