import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class FirebaseSignUp {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _localStorage = LocalStorageService();

  Future<User?> signUpWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    String? phone,  // ← Telefon parametresi eklendi
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
      String? phone,  // ← Telefon parametresi
      ) async {
    final userData = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),  // ← Telefon eklendi
      'role': 'mentor',
      'profileImage': '',
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final mentorData = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),  // ← Telefon eklendi
      'subscriptionTier': 'free',
      'subscriptionStartDate': FieldValue.serverTimestamp(),
      'subscriptionEndDate': null,
      'classCount': 0,
      'studentCount': 0,
      'maxClasses': 1,
      'maxStudentsPerClass': 30,
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(uid).set(userData);
    await _firestore.collection('mentors').doc(uid).set(mentorData);

    await _localStorage.saveUserData({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),  // ← Telefon eklendi
      'role': 'mentor',
      'profileImage': '',
      'bio': '',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _localStorage.saveMentorData({
      'subscriptionTier': 'free',
      'maxClasses': 1,
      'maxStudentsPerClass': 30,
      'classCount': 0,
      'studentCount': 0,
    });
  }

  Future<void> _registerAsStudent(
      String uid,
      String name,
      String email,
      String? phone,  // ← Telefon parametresi
      String classCode,
      ) async {
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

    final userData = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),  // ← Telefon eklendi
      'role': 'student',
      'profileImage': '',
      'bio': '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final studentData = {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),  // ← Telefon eklendi
      'mentorId': mentorId,
      'classId': classId,
      'classCode': classCode,
      'enrolledAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('users').doc(uid).set(userData);
    await _firestore.collection('students').doc(uid).set(studentData);

    await _firestore
        .collection('classes')
        .doc(classId)
        .collection('students')
        .doc(uid)
        .set({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),  // ← Telefon eklendi
      'enrolledAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('classes').doc(classId).update({
      'studentCount': FieldValue.increment(1),
    });

    await _firestore.collection('mentors').doc(mentorId).update({
      'studentCount': FieldValue.increment(1),
    });

    await _localStorage.saveUserData({
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone?.trim(),  // ← Telefon eklendi
      'role': 'student',
      'profileImage': '',
      'bio': '',
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _localStorage.saveStudentData({
      'mentorId': mentorId,
      'classId': classId,
      'classCode': classCode,
    });
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