import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mykoc/firebase/classroom/classroom_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:mykoc/firebase/messaging/fcm_service.dart';
import 'package:mykoc/firebase/messaging/messaging_service.dart';

class FirebaseSignUp {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService();
  final MessagingService _messagingService = MessagingService();
  final ClassroomService _classroomService = ClassroomService();

  Future<User?> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? classCode,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw 'Kullanıcı oluşturulamadı';

      await user.updateDisplayName(name);
      await _saveToLocalStorage(user.uid, email);

      if (classCode != null && classCode.isNotEmpty) {
        await _registerAsStudent(user.uid, name, email, phone, classCode);
      } else {
        await _registerAsMentor(user.uid, name, email, phone);
      }

      // FCM token kaydet
      await FCMService().saveToken(user.uid);
      debugPrint('✅ FCM token saved');

      return user;
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    } catch (e) {
      throw e.toString();
    }
  }

  Future<void> _registerAsMentor(
      String uid,
      String name,
      String email,
      String? phone,
      ) async {
    final userData = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),
      'role': 'mentor',
      'profileImage': '',
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final mentorData = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),
      'subscriptionTier': 'free',
      'subscriptionStartDate': FieldValue.serverTimestamp(),
      'subscriptionEndDate': null,
      'classCount': 0,
      'studentCount': 0,
      'maxClasses': 1,
      'maxStudentsPerClass': 10,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(uid).set(userData);
    await _firestore.collection('mentors').doc(uid).set(mentorData);

    await _localStorage.saveUserData({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),
      'role': 'mentor',
      'profileImage': '',
      'bio': '',
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _localStorage.saveMentorData({
      'subscriptionTier': 'free',
      'maxClasses': 1,
      'maxStudentsPerClass': 10,
      'classCount': 0,
      'studentCount': 0,
    });
  }

  Future<void> _registerAsStudent(
      String uid,
      String name,
      String email,
      String? phone,
      String classCode,
      ) async {
    // 1. Sınıfı kod ile bul
    final classSnapshot = await _firestore
        .collection('classes')
        .where('classCode', isEqualTo: classCode.trim().toUpperCase())
        .get();

    if (classSnapshot.docs.isEmpty) {
      throw 'Geçersiz sınıf kodu';
    }

    final classDoc = classSnapshot.docs.first;
    final classId = classDoc.id;
    final classData = classDoc.data();
    final String mentorId = classData['mentorId'] ?? '';

    // --- KRİTİK LİMİT KONTROLÜ BAŞLANGIÇ ---
    // ClassroomService üzerindeki merkezi kontrol metodunu kullanıyoruz
    final bool canJoin = await _classroomService.checkStudentLimit(classId);

    if (!canJoin) {
      // Eğer limit dolmuşsa hata fırlat ve kaydı durdur
      throw 'STUDENT_LIMIT_REACHED';
    }
    // --- KRİTİK LİMİT KONTROLÜ BİTİŞ ---

    // 2. Users koleksiyonuna temel kullanıcı verilerini kaydet
    final userData = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),
      'role': 'student',
      'profileImage': '',
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    // 3. Students koleksiyonuna öğrenci-mentör eşleşmesini kaydet
    final studentData = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),
      'mentorId': mentorId,
      'classId': classId,
      'classCode': classCode.toUpperCase(),
      'enrolledAt': FieldValue.serverTimestamp(),
    };

    // İşlemleri toplu (batch) yapmak veri tutarlılığı için daha iyidir
    final batch = _firestore.batch();

    batch.set(_firestore.collection('users').doc(uid), userData);
    batch.set(_firestore.collection('students').doc(uid), studentData);

    // 4. Sınıfın altındaki 'students' koleksiyonuna ekle
    batch.set(
      _firestore.collection('classes').doc(classId).collection('students').doc(uid),
      {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone?.trim(),
        'enrolledAt': FieldValue.serverTimestamp(),
      },
    );

    // 5. Sayaçları (studentCount) artır
    batch.update(_firestore.collection('classes').doc(classId), {
      'studentCount': FieldValue.increment(1),
    });

    batch.update(_firestore.collection('mentors').doc(mentorId), {
      'studentCount': FieldValue.increment(1),
    });

    // Batch işlemini tamamla
    await batch.commit();

    // 6. Mesajlaşma (Chat Room) entegrasyonu
    try {
      final chatRoomId = await _messagingService.getChatRoomIdByClassId(classId);

      if (chatRoomId != null) {
        await _messagingService.addStudentToChatRoom(
          chatRoomId: chatRoomId,
          studentId: uid,
          studentName: name,
          studentImageUrl: null,
        );
        debugPrint('✅ Student added to chat room: $chatRoomId');
      }
    } catch (e) {
      debugPrint('❌ Error adding student to chat room: $e');
      // Chat hatası kaydı tamamen durdurmamalı, sadece logluyoruz.
    }

    // 7. Local Storage güncellemeleri
    await _localStorage.saveUserData({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),
      'role': 'student',
      'profileImage': '',
      'bio': '',
      'createdAt': DateTime.now().toIso8601String(),
    });

    await _localStorage.saveStudentData({
      'mentorId': mentorId,
      'classId': classId,
      'classCode': classCode.toUpperCase(),
    });

    await _localStorage.saveActiveClassId(classId);
  }

  Future<void> _saveToLocalStorage(String uid, String email) async {
    await _localStorage.saveUid(uid);
    await _localStorage.saveEmail(email);
  }

  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin';
      case 'operation-not-allowed':
        return 'E-posta/Şifre girişi aktif değil';
      default:
        return 'Kayıt sırasında bir hata oluştu';
    }
  }
}