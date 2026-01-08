import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
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

        // Timestamp'leri String'e çevir
        data.forEach((key, value) {
          if (value is Timestamp) {
            data[key] = value.toDate().toIso8601String();
          }
        });

        tier = data['subscriptionTier'] ?? 'free';
        await _localStorage.saveMentorData(data);
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
          subscriptionTier: _settingsData!.subscriptionTier,
        );

        if (value) {
          await FCMService().getToken();
        }
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error toggling notifications: $e');
    }
  }

  /// Dil değiştir
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
          subscriptionTier: _settingsData!.subscriptionTier,
        );
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error updating language state: $e');
    }
  }

  /// Hesabı sil - Sadece işlemi yapar, dialog yönetimi UI'da
  // SettingsViewModel içindeki deleteAccount metodunu şu şekilde güncelleyin:

  Future<bool> deleteAccount({
    required DeleteAccountReason deleteReason,
  }) async {
    _isDeleting = true; // Loading durumunu başlat
    _safeNotifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final uid = user.uid;

      // 1. Verileri sil (Sıralama önemli: önce veriler, en son kullanıcı)
      await _deleteUserData(uid);

      try {
        await FirebaseMessaging.instance.deleteToken();
        await FCMService().deleteToken(uid);
      } catch (e) {
        debugPrint('⚠️ FCM Token silme hatası: $e');
      }

      await _localStorage.clearAll();

      // 2. Firebase Auth hesabını sil
      // (Bu işlem başarılı olursa kullanıcı otomatik logout olur)
      await user.delete();

      _isDeleting = false;
      _safeNotifyListeners();
      return true;

    } on FirebaseAuthException catch (e) {
      _isDeleting = false;
      _safeNotifyListeners();
      rethrow;
    } catch (e) {
      _isDeleting = false;
      _safeNotifyListeners();
      return false;
    }
  }

  /// Logout
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
              (route) => false,
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
      final userData = _localStorage.getUserData();
      final role = userData?['role'] ?? 'student';

      debugPrint('📋 Kullanıcı rolü: $role');

      // User document'ı sil
      batch.delete(_firestore.collection('users').doc(uid));
      debugPrint('🗑️ Users collection kaydı silme için işaretlendi');

      if (role == 'mentor') {
        // Mentör ise: Oluşturduğu sınıfları bul ve sil
        final mentorClasses = await _firestore
            .collection('classes')
            .where('mentorId', isEqualTo: uid)
            .get();

        debugPrint('📚 ${mentorClasses.docs.length} adet sınıf bulundu');

        for (var doc in mentorClasses.docs) {
          batch.delete(doc.reference);
          debugPrint('🗑️ Class ${doc.id} silme için işaretlendi');
        }

        // Mentör verilerini sil
        final mentorDoc = await _firestore.collection('mentors').doc(uid).get();
        if (mentorDoc.exists) {
          batch.delete(mentorDoc.reference);
          debugPrint('🗑️ Mentor collection kaydı silme için işaretlendi');
        }

      } else {
        // Öğrenci ise: Katıldığı sınıflardan çıkar
        final studentRecords = await _firestore
            .collection('students')
            .where('uid', isEqualTo: uid)
            .get();

        debugPrint('🎓 ${studentRecords.docs.length} adet öğrenci kaydı bulundu');

        for (var doc in studentRecords.docs) {
          batch.delete(doc.reference);
          debugPrint('🗑️ Student ${doc.id} silme için işaretlendi');
        }
      }

      // Batch commit
      await batch.commit();
      debugPrint('✅ Tüm Firestore verileri başarıyla silindi');

    } catch (e) {
      debugPrint('❌ Firestore veri silme hatası: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}