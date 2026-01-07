import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mykoc/pages/auth/sign_in/signIn.dart';
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
  // settings_view_model.dart içindeki ilgili kısmı şu şekilde güncelle:

  Future<void> _loadUserData() async {
    final uid = _localStorage.getUid();
    final userData = _localStorage.getUserData();
    final bool notificationsEnabled = _localStorage.getNotificationsEnabled() ?? true;

    if (uid == null || userData == null) return;

    try {
      final mentorDoc = await _firestore.collection('mentors').doc(uid).get();

      String tier = 'free';
      if (mentorDoc.exists) {
        final data = Map<String, dynamic>.from(mentorDoc.data()!);

        // --- Timestamp DÜZELTMESİ BAŞLANGIÇ ---
        // Firebase'den gelen dökümandaki tüm Timestamp alanlarını String'e çeviriyoruz
        data.forEach((key, value) {
          if (value is Timestamp) {
            data[key] = value.toDate().toIso8601String();
          }
        });
        // --- Timestamp DÜZELTMESİ BİTİŞ ---

        tier = data['subscriptionTier'] ?? 'free';
        await _localStorage.saveMentorData(data); // Artık hata vermeyecek
      }

      _settingsData = SettingsModel(
        userName: userData['name'] ?? 'User',
        userEmail: userData['email'] ?? '',
        userRole: userData['role'] ?? 'student',
        profileImageUrl: userData['profileImage'],
        appVersion: '1.0.0',
        currentLanguage: 'English',
        isNotificationsEnabled: notificationsEnabled,
        subscriptionTier: tier,
      );

      debugPrint('✅ Settings data synced successfully.');
    } catch (e) {
      debugPrint('❌ Error syncing settings from Firestore: $e');
      // Hata durumunda local veriden devam et
      final mentorData = _localStorage.getMentorData();
      _settingsData = SettingsModel(
        userName: userData['name'] ?? 'User',
        userEmail: userData['email'] ?? '',
        userRole: userData['role'] ?? 'student',
        profileImageUrl: userData['profileImage'],
        appVersion: '1.0.0',
        currentLanguage: 'English',
        isNotificationsEnabled: notificationsEnabled,
        subscriptionTier: mentorData?['subscriptionTier'] ?? 'free',
      );
    }
    _safeNotifyListeners();
  }

  /// Bildirimleri Aç/Kapat
  Future<void> toggleNotifications(bool value) async {
    try {
      await _localStorage.saveNotificationsEnabled(value);
      if (_settingsData != null) {
        _settingsData = SettingsModel(
          userName: _settingsData!.userName,
          userEmail: _settingsData!.userEmail,
          userRole: _settingsData!.userRole,
          profileImageUrl: _settingsData!.profileImageUrl,
          appVersion: _settingsData!.appVersion,
          currentLanguage: _settingsData!.currentLanguage,
          isNotificationsEnabled: value,
          subscriptionTier: _settingsData!.subscriptionTier, // Durum korundu
        );

        if (value) {
          await FCMService().getToken(); // Bildirim açıldıysa token yenile
        }
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error toggling notifications: $e');
    }
  }

  /// Dil değiştir (Easy Localization ile uyumlu hale getirildi)
  Future<void> changeLanguage(String language) async {
    try {
      debugPrint('🌐 Language internal state updated to: $language');

      if (_settingsData != null) {
        _settingsData = SettingsModel(
          userName: _settingsData!.userName,
          userEmail: _settingsData!.userEmail,
          userRole: _settingsData!.userRole,
          profileImageUrl: _settingsData!.profileImageUrl,
          appVersion: _settingsData!.appVersion,
          currentLanguage: language,
          isNotificationsEnabled: _settingsData!.isNotificationsEnabled,
          subscriptionTier: _settingsData!.subscriptionTier, // Durum korundu
        );
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating language state: $e');
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

  Future<void> logout(BuildContext context) async {
    try {
      debugPrint('🚪 Logout süreci başladı...');
      final uid = _localStorage.getUid();

      // 1. FCM Token Temizliği
      if (uid != null) {
        try {
          await FCMService().deleteToken(uid);
        } catch (e) {
          debugPrint('⚠️ Token silme hatası (atlanıyor): $e');
        }
      }

      // 2. Firebase Oturumu Kapatma
      await _auth.signOut();

      // 3. Yerel Veri Temizliği
      await _localStorage.clearAll();

      // 4. Uygulamayı Sıfırla ve Login'e Yönlendir
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Signin()),
              (route) => false, // Tüm sayfaları stackten atar
        );
      }
    } catch (e) {
      debugPrint('❌ Logout hatası: $e');
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


  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}