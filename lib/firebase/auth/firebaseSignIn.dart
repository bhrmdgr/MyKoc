import 'package:firebase_auth/firebase_auth.dart';

class FirebaseSignIn {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Email ve şifre ile giriş yapma
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Beklenmeyen bir hata oluştu';
    }
  }

  // Şifremi unuttum
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Şifre sıfırlama e-postası gönderilemedi';
    }
  }

  // Çıkış yapma
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw 'Çıkış yapılırken bir hata oluştu';
    }
  }

  // Mevcut kullanıcıyı al
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Kullanıcı oturum durumu stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Firebase Auth hatalarını Türkçe mesajlara çevirme
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
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
        return 'Giriş yapılırken bir hata oluştu: ${e.message}';
    }
  }
}