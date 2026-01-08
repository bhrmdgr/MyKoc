import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:email_validator/email_validator.dart';
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
      final String trimmedEmail = email.trim();

      if (!EmailValidator.validate(trimmedEmail)) {
        throw 'INVALID_FORMAT';
      }

      final String? normalizedPhone = phone?.replaceAll(RegExp(r'\s+'), '');

      // 1. ADIM: Firebase Auth Kaydı
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw 'Kullanıcı oluşturulamadı';

      // 2. ADIM: Profil Bilgileri Güncelleme
      await user.updateDisplayName(name);
      await _saveToLocalStorage(user.uid, trimmedEmail);

      // 3. ADIM: Rol Bazlı Veritabanı Kaydı
      // Buradaki Firestore kayıtları kritik olduğu için 'await' ile bekliyoruz.
      if (classCode != null && classCode.isNotEmpty) {
        await _registerAsStudent(user.uid, name, trimmedEmail, normalizedPhone, classCode);
      } else {
        await _registerAsMentor(user.uid, name, trimmedEmail, normalizedPhone);
      }

      // --- GÜNCELLEME BURADA ---
      // FCM token alma işlemi 36 saniye süren o 'contention' hatasına neden oluyor.
      // Unawaited (beklemesiz) yaparak bu bloktan hemen kurtuluyoruz.
      FCMService().saveToken(user.uid).then((_) {
        debugPrint('✅ FCM token saved');
      }).catchError((e) {
        debugPrint('⚠️ FCM token hatası (Kayıt etkilenmedi): $e');
      });

      return user; // Kullanıcı hemen ana sayfaya yönlendirilir.
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    } catch (e) {
      if (e == 'INVALID_FORMAT') {
        throw 'Lütfen geçerli bir e-posta adresi girdiğinizden emin olun.';
      }
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
      'phone': phone,
      'role': 'mentor',
      'profileImage': '',
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final mentorData = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
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
      'phone': phone,
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

    final bool canJoin = await _classroomService.checkStudentLimit(classId);
    if (!canJoin) {
      throw 'STUDENT_LIMIT_REACHED';
    }

    final userData = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': 'student',
      'profileImage': '',
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final studentData = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'mentorId': mentorId,
      'classId': classId,
      'classCode': classCode.toUpperCase(),
      'enrolledAt': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    batch.set(_firestore.collection('users').doc(uid), userData);
    batch.set(_firestore.collection('students').doc(uid), studentData);
    batch.set(
      _firestore.collection('classes').doc(classId).collection('students').doc(uid),
      {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'enrolledAt': FieldValue.serverTimestamp(),
      },
    );

    batch.update(_firestore.collection('classes').doc(classId), {'studentCount': FieldValue.increment(1)});
    batch.update(_firestore.collection('mentors').doc(mentorId), {'studentCount': FieldValue.increment(1)});

    await batch.commit();

    // --- GÜNCELLEME BURADA ---
    // Mesajlaşma entegrasyonu tamamen arka plana alındı.
    // .then() kullanarak asenkron çalıştırıyoruz, 'await' yapmıyoruz.
    _messagingService.getChatRoomIdByClassId(classId).then((chatRoomId) {
      if (chatRoomId != null) {
        _messagingService.addStudentToChatRoom(
          chatRoomId: chatRoomId,
          studentId: uid,
          studentName: name,
          studentImageUrl: null,
        );
      }
    }).catchError((e) {
      debugPrint('❌ Sohbet odasına ekleme hatası: $e');
    });

    await _localStorage.saveUserData({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
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
        return 'E-posta adresi geçersiz veya sunucusu bulunamadı';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin';
      case 'operation-not-allowed':
        return 'E-posta/Şifre girişi aktif değil';
      default:
        return 'Kayıt sırasında bir hata oluştu (Hata: $code)';
    }
  }
}