import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:flutter/foundation.dart';

class FirebaseSignIn {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  /// SADECE GİRİŞ YAP - Başka hiçbir şey yapma
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 [1/3] Giriş denemesi başladı: $email');

      // ADIM 1: Sadece Firebase Auth'a giriş yap
      final userCredential = await _auth
          .signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      )
          .timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw 'TIMEOUT: Firebase sunucusuna ulaşılamadı';
        },
      );

      debugPrint('✅ [2/3] Firebase Auth başarılı');

      final user = userCredential.user;
      if (user == null) {
        throw 'Kullanıcı bilgisi alınamadı';
      }

      // ADIM 2: Sadece UID ve Email kaydet (Hızlı işlem)
      await _localStorage.saveUid(user.uid);
      await _localStorage.saveEmail(email.trim());

      debugPrint('✅ [3/3] Local storage kaydedildi');

      // ADIM 3: Arka planda diğer işlemleri yap (UI'ı bloklamaz)
      _loadUserDataInBackground(user.uid, email.trim());

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ FirebaseAuth hatası: ${e.code}');
      throw _getErrorMessage(e.code);
    } catch (e) {
      debugPrint('❌ Genel hata: $e');
      throw e.toString();
    }
  }

  /// Arka planda kullanıcı verilerini yükle
  void _loadUserDataInBackground(String uid, String email) async {
    try {
      debugPrint('📦 Arka planda veri yükleniyor...');

      // Firestore'dan kullanıcı verisini al
      final userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!userDoc.exists) {
        debugPrint('⚠️ Kullanıcı kaydı Firestore\'da bulunamadı');
        return;
      }

      final userData = userDoc.data()!;
      final role = userData['role'];

      // Timestamp'leri kaldır
      final cleanUserData = Map<String, dynamic>.from(userData);
      cleanUserData.removeWhere((key, value) => value is Timestamp);

      await _localStorage.saveUserData(cleanUserData);

      // Role göre ek veri yükle
      if (role == 'mentor') {
        final mentorDoc = await _firestore
            .collection('mentors')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 10));

        if (mentorDoc.exists) {
          final mentorData = Map<String, dynamic>.from(mentorDoc.data()!);
          mentorData.removeWhere((key, value) => value is Timestamp);
          await _localStorage.saveMentorData(mentorData);
        }
      } else if (role == 'student') {
        final studentDoc = await _firestore
            .collection('students')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 10));

        if (studentDoc.exists) {
          final studentData = Map<String, dynamic>.from(studentDoc.data()!);
          studentData.removeWhere((key, value) => value is Timestamp);
          await _localStorage.saveStudentData(studentData);
        }
      }

      debugPrint('✅ Arka plan veri yükleme tamamlandı');
    } catch (e) {
      debugPrint('⚠️ Arka plan veri yükleme hatası: $e');
      // Hata olsa bile kullanıcı zaten giriş yapmış durumda
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _localStorage.clearAll();
      debugPrint('✅ Çıkış başarılı');
    } catch (e) {
      debugPrint('❌ Çıkış hatası: $e');
      await _localStorage.clearAll();
      throw 'Çıkış yapılırken bir hata oluştu';
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      debugPrint('✅ Şifre sıfırlama emaili gönderildi');
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Şifre sıfırlama hatası: ${e.code}');
      throw _getErrorMessage(e.code);
    }
  }

  User? getCurrentUser() => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı';
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
      default:
        return 'Giriş yapılırken bir hata oluştu (Hata: $code)';
    }
  }
}