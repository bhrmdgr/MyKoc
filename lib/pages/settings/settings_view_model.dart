import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mykoc/pages/settings/settings_model.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:mykoc/routers/appRouter.dart';
import 'package:mykoc/firebase/messaging/fcm_service.dart';

class SettingsViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  SettingsModel? _settingsData;
  SettingsModel? get settingsData => _settingsData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isDeleting = false;
  bool get isDeleting => _isDeleting;

  bool _isDisposed = false;

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Initialize
  Future<void> initialize() async {
    _isLoading = true;
    _safeNotifyListeners();

    try {
      await _loadUserData();
    } catch (e) {
      debugPrint('❌ SettingsViewModel Error: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Kullanıcı verilerini yükle
  Future<void> _loadUserData() async {
    final userData = _localStorage.getUserData();
    if (userData == null) {
      debugPrint('⚠️ User data not found in local storage');
      return;
    }

    _settingsData = SettingsModel(
      userName: userData['name'] ?? 'User',
      userEmail: userData['email'] ?? '',
      userRole: userData['role'] ?? 'student',
      profileImageUrl: userData['profileImage'],
      appVersion: '1.0.0',
      currentLanguage: 'English',
    );

    debugPrint('✅ Settings data loaded');
    _safeNotifyListeners();
  }

  /// Dil değiştir (Gelecekte implement edilecek)
  Future<void> changeLanguage(String language) async {
    try {
      // TODO: Implement language change
      debugPrint('🌐 Language changed to: $language');

      if (_settingsData != null) {
        _settingsData = SettingsModel(
          userName: _settingsData!.userName,
          userEmail: _settingsData!.userEmail,
          userRole: _settingsData!.userRole,
          profileImageUrl: _settingsData!.profileImageUrl,
          appVersion: _settingsData!.appVersion,
          currentLanguage: language,
        );
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error changing language: $e');
    }
  }

  /// Hesabı sil
  Future<bool> deleteAccount({
    required BuildContext context,
    required DeleteAccountReason deleteReason,
  }) async {
    _isDeleting = true;
    _safeNotifyListeners();

    try {
      final uid = _localStorage.getUid();
      final role = _localStorage.getUserRole();
      final email = _localStorage.getEmail();
      final name = _localStorage.getUserName();

      if (uid == null) {
        debugPrint('❌ User ID not found');
        return false;
      }

      debugPrint('🗑️ Starting account deletion process...');

      // 1. Silme nedenini ÖNCE kaydet (detaylı bilgi ile)
      await _firestore.collection('deleted_accounts').add({
        'uid': uid,
        'email': email,
        'name': name,
        'role': role,
        'reason': deleteReason.reason.toString().split('.').last,
        'reasonText': _getReasonText(deleteReason.reason),
        'additionalFeedback': deleteReason.additionalFeedback,
        'deletedAt': FieldValue.serverTimestamp(),
        'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown'),
      });

      debugPrint('✅ Delete reason saved');

      // 2. Kullanıcının verilerini sil
      await _deleteUserData(uid);

      // 3. FCM token sil
      try {
        await FCMService().deleteToken(uid);
        debugPrint('✅ FCM token deleted');
      } catch (e) {
        debugPrint('⚠️ FCM token delete error: $e');
      }

      // 4. Firebase Auth hesabını sil
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
        debugPrint('✅ Firebase Auth account deleted');
      }

      // 5. Local storage'ı temizle
      await _localStorage.clearAll();
      debugPrint('✅ Local storage cleared');

      // 6. Login sayfasına yönlendir
      if (context.mounted) {
        navigateToSignIn(context);
      }

      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Auth error during account deletion: ${e.code}');

      if (e.code == 'requires-recent-login') {
        // Kullanıcının yeniden giriş yapması gerekiyor
        if (context.mounted) {
          _showReauthDialog(context);
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error deleting account: $e');
      return false;
    } finally {
      _isDeleting = false;
      _safeNotifyListeners();
    }
  }

  /// Kullanıcı verilerini sil
  Future<void> _deleteUserData(String uid) async {
    try {
      final batch = _firestore.batch();

      // User document'ı sil
      batch.delete(_firestore.collection('users').doc(uid));

      // Kullanıcının oluşturduğu/katıldığı sınıfları bul ve temizle
      final userData = _localStorage.getUserData();
      final role = userData?['role'] ?? 'student';

      if (role == 'mentor') {
        // Mentör ise: Oluşturduğu sınıfları sil
        final mentorClasses = await _firestore
            .collection('classes')
            .where('mentorId', isEqualTo: uid)
            .get();

        for (var doc in mentorClasses.docs) {
          batch.delete(doc.reference);
        }

        // Mentör verilerini sil
        batch.delete(_firestore.collection('mentors').doc(uid));
      } else {
        // Öğrenci ise: Katıldığı sınıflardan çıkar
        final studentRecords = await _firestore
            .collection('students')
            .where('uid', isEqualTo: uid)
            .get();

        for (var doc in studentRecords.docs) {
          batch.delete(doc.reference);
        }
      }

      await batch.commit();
      debugPrint('✅ User data deleted from Firestore');
    } catch (e) {
      debugPrint('❌ Error deleting user data: $e');
    }
  }

  /// Silme nedeni text'ini döndür
  String _getReasonText(DeleteReason reason) {
    switch (reason) {
      case DeleteReason.notUseful:
        return 'Uygulama kullanışlı değil';
      case DeleteReason.foundAlternative:
        return 'Alternatif bir uygulama buldum';
      case DeleteReason.privacyConcerns:
        return 'Gizlilik endişeleri';
      case DeleteReason.tooManyNotifications:
        return 'Çok fazla bildirim';
      case DeleteReason.technicalIssues:
        return 'Teknik sorunlar';
      case DeleteReason.other:
        return 'Diğer';
    }
  }

  /// Yeniden kimlik doğrulama dialog'u
  void _showReauthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Re-authentication Required'),
        content: const Text(
          'For security reasons, you need to log in again before deleting your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _auth.signOut();
              navigateToSignIn(context);
            },
            child: const Text('Log In Again'),
          ),
        ],
      ),
    );
  }

  /// Logout
  Future<void> logout(BuildContext context) async {
    try {
      final uid = _localStorage.getUid();

      // FCM token sil
      if (uid != null) {
        try {
          await FCMService().deleteToken(uid);
          debugPrint('✅ FCM token deleted on logout');
        } catch (e) {
          debugPrint('⚠️ FCM token delete error: $e');
        }
      }

      await _auth.signOut();
      await _localStorage.clearAll();

      debugPrint('✅ User logged out successfully');

      if (context.mounted) {
        navigateToSignIn(context);
      }
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to log out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}