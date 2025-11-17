import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:flutter/foundation.dart';

class FirebaseSignIn {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  // Email ve şifre ile giriş
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw 'Kullanıcı bulunamadı';

      // ✅ Firestore'dan kullanıcı bilgilerini çek ve local storage'a kaydet
      await _fetchAndSaveUserData(user.uid, email);

      return user;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) print('FirebaseAuth Error: ${e.code}');
      throw _getErrorMessage(e.code);
    } catch (e) {
      if (kDebugMode) print('SignIn Error: $e');
      throw e.toString();
    }
  }

  // Firestore'dan kullanıcı bilgilerini çek ve kaydet
  Future<void> _fetchAndSaveUserData(String uid, String email) async {
    try {
      // ✅ UID ve Email'i hemen kaydet
      await _localStorage.saveUid(uid);
      await _localStorage.saveEmail(email);

      // User bilgilerini çek
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        throw 'Kullanıcı kaydı bulunamadı';
      }

      final userData = userDoc.data()!;
      final role = userData['role'];

      // ✅ Timestamp'i String'e çevir
      final userDataToSave = Map<String, dynamic>.from(userData);
      if (userDataToSave['createdAt'] is Timestamp) {
        userDataToSave['createdAt'] =
            (userDataToSave['createdAt'] as Timestamp).toDate().toIso8601String();
      }

      await _localStorage.saveUserData(userDataToSave);

      // ✅ Role göre ek bilgileri kaydet
      if (role == 'mentor') {
        final mentorDoc = await _firestore.collection('mentors').doc(uid).get();
        if (mentorDoc.exists) {
          final mentorData = Map<String, dynamic>.from(mentorDoc.data()!);

          // Timestamp'leri temizle
          mentorData.remove('createdAt');
          mentorData.remove('subscriptionStartDate');
          mentorData.remove('subscriptionEndDate');

          await _localStorage.saveMentorData(mentorData);
        }
      } else if (role == 'student') {
        final studentDoc = await _firestore.collection('students').doc(uid).get();
        if (studentDoc.exists) {
          final studentData = Map<String, dynamic>.from(studentDoc.data()!);

          // Timestamp'leri temizle
          studentData.remove('enrolledAt');

          await _localStorage.saveStudentData(studentData);
        }
      }

      if (kDebugMode) print('✅ User data loaded successfully');
    } catch (e) {
      if (kDebugMode) print('Error fetching user data: $e');
      throw 'Kullanıcı bilgileri yüklenemedi';
    }
  }

  // Çıkış yapma
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _localStorage.clearAllUserData();
    } catch (e) {
      throw 'Çıkış yapılırken bir hata oluştu';
    }
  }

  // Şifre sıfırlama
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _getErrorMessage(e.code);
    } catch (e) {
      throw 'Şifre sıfırlama e-postası gönderilemedi';
    }
  }

  // Mevcut kullanıcıyı al
  User? getCurrentUser() => _auth.currentUser;

  // Oturum durumu stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı';
      case 'wrong-password':
        return 'Hatalı şifre girdiniz';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış';
      case 'too-many-requests':
        return 'Çok fazla deneme yaptınız. Lütfen daha sonra tekrar deneyin';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin';
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı';
      default:
        return 'Giriş yapılırken bir hata oluştu';
    }
  }
}