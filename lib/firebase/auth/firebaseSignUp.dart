import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseSignUp {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ana kayıt fonksiyonu
  Future<User?> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    String? classCode,
  }) async {
    try {
      // 1. Firebase Auth ile kullanıcı oluştur
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) return null;

      // 2. Kullanıcı adını güncelle
      await user.updateDisplayName(name);

      // 3. Kod varsa öğrenci, yoksa mentör olarak kaydet
      if (classCode != null && classCode.isNotEmpty) {
        await _registerAsStudent(user.uid, name, email, classCode);
      } else {
        await _registerAsMentor(user.uid, name, email);
      }

      // 4. E-posta doğrulama gönder
      await user.sendEmailVerification();

      return user;
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    } catch (e) {
      throw e.toString();
    }
  }

  // Mentör olarak kayıt
  Future<void> _registerAsMentor(String uid, String name, String email) async {
    // Users koleksiyonuna ekle
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'role': 'mentor',
      'profileImage': '',
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Mentors koleksiyonuna ekle
    await _firestore.collection('mentors').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'classCount': 0,
      'studentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Öğrenci olarak kayıt
  Future<void> _registerAsStudent(
      String uid,
      String name,
      String email,
      String classCode,
      ) async {
    // Sınıf kodunu kontrol et ve sınıf bilgilerini al
    final classDoc = await _firestore
        .collection('classes')
        .where('classCode', isEqualTo: classCode.trim())
        .get();

    if (classDoc.docs.isEmpty) {
      throw 'Geçersiz sınıf kodu';
    }

    final classData = classDoc.docs.first.data();
    final classId = classDoc.docs.first.id;
    final mentorId = classData['mentorId'];

    // Users koleksiyonuna ekle
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'role': 'student',
      'profileImage': '',
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Students koleksiyonuna ekle
    await _firestore.collection('students').doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'mentorId': mentorId,
      'classId': classId,
      'classCode': classCode,
      'enrolledAt': FieldValue.serverTimestamp(),
    });

    // Sınıfın students koleksiyonuna ekle
    await _firestore
        .collection('classes')
        .doc(classId)
        .collection('students')
        .doc(uid)
        .set({
      'uid': uid,
      'name': name,
      'email': email,
      'enrolledAt': FieldValue.serverTimestamp(),
    });

    // Sayaçları güncelle
    await _firestore.collection('classes').doc(classId).update({
      'studentCount': FieldValue.increment(1),
    });

    await _firestore.collection('mentors').doc(mentorId).update({
      'studentCount': FieldValue.increment(1),
    });
  }

  // Hata mesajlarını Türkçeleştir
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
      default:
        return 'Kayıt sırasında bir hata oluştu';
    }
  }
}