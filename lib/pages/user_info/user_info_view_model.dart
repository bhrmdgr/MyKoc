import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mykoc/pages/user_info/user_info_model.dart';
import 'package:mykoc/pages/user_info/user_info_view_model.dart';

import 'package:mykoc/services/storage/local_storage_service.dart';
import 'dart:io';
import 'package:mykoc/firebase/storage/storage_service.dart';

class UserInfoViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalStorageService _localStorage = LocalStorageService();
  final StorageService _storageService = StorageService();

  UserInfoModel? _userInfo;
  UserInfoModel? get userInfo => _userInfo;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

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
      await _loadUserInfo();
    } catch (e) {
      debugPrint('❌ UserInfoViewModel Error: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  /// Kullanıcı bilgilerini yükle
  Future<void> _loadUserInfo() async {
    final uid = _localStorage.getUid();
    if (uid == null) {
      debugPrint('⚠️ User ID not found');
      return;
    }

    // Local storage'dan yükle
    final userData = _localStorage.getUserData();
    if (userData != null) {
      _userInfo = UserInfoModel(
        name: userData['name'] ?? '',
        email: userData['email'] ?? '',
        phone: userData['phone'],
        bio: userData['bio'],
        profileImageUrl: userData['profileImage'],
        createdAt: userData['createdAt'] != null
            ? DateTime.parse(userData['createdAt'])
            : null,
      );
      _safeNotifyListeners();
    }

    // Firebase'den güncel verileri çek
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _userInfo = UserInfoModel(
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          phone: data['phone'],
          bio: data['bio'],
          profileImageUrl: data['profileImage'],
          createdAt: data['createdAt'] is Timestamp
              ? (data['createdAt'] as Timestamp).toDate()
              : null,
        );

        // Local storage'ı güncelle
        final updatedUserData = Map<String, dynamic>.from(userData ?? {});
        updatedUserData['name'] = _userInfo!.name;
        updatedUserData['email'] = _userInfo!.email;
        updatedUserData['phone'] = _userInfo!.phone;
        updatedUserData['bio'] = _userInfo!.bio;
        updatedUserData['profileImage'] = _userInfo!.profileImageUrl;

        await _localStorage.saveUserData(updatedUserData);

        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading user info from Firebase: $e');
    }
  }

  /// Kullanıcı bilgilerini güncelle
  /// Kullanıcı bilgilerini güncelle
  Future<bool> updateUserInfo({
    required String name,
    String? phone,
    String? bio,
  }) async {
    _isSaving = true;
    _safeNotifyListeners();

    try {
      final uid = _localStorage.getUid();
      if (uid == null) return false;

      final updateData = {
        'name': name.trim(),
        'phone': phone?.trim(),
        'bio': bio?.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Firebase users collection'ı güncelle
      await _firestore.collection('users').doc(uid).update(updateData);

      // Kullanıcı rolünü kontrol et
      final userData = _localStorage.getUserData();
      final role = userData?['role'];

      // Eğer mentor ise mentors collection'ı da güncelle
      if (role == 'mentor') {
        await _firestore.collection('mentors').doc(uid).update({
          'name': name.trim(),
          'phone': phone?.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Mentors collection updated');
      }

      // Eğer student ise students collection'ı da güncelle
      if (role == 'student') {
        await _firestore.collection('students').doc(uid).update({
          'name': name.trim(),
          'phone': phone?.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('✅ Students collection updated');
      }

      // Local storage'ı güncelle
      final localUserData = userData ?? {};
      localUserData['name'] = name.trim();
      localUserData['phone'] = phone?.trim();
      localUserData['bio'] = bio?.trim();
      await _localStorage.saveUserData(localUserData);

      // Model'i güncelle
      _userInfo = UserInfoModel(
        name: name.trim(),
        email: _userInfo!.email,
        phone: phone?.trim(),
        bio: bio?.trim(),
        profileImageUrl: _userInfo!.profileImageUrl,
        createdAt: _userInfo!.createdAt,
      );

      debugPrint('✅ User info updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating user info: $e');
      return false;
    } finally {
      _isSaving = false;
      _safeNotifyListeners();
    }
  }

  /// Profil fotoğrafı güncelle
  Future<bool> updateProfileImage(File imageFile) async {
    _isSaving = true;
    _safeNotifyListeners();

    try {
      final uid = _localStorage.getUid();
      if (uid == null) return false;

      // Eski fotoğrafı sil (eğer varsa)
      if (_userInfo?.profileImageUrl != null && _userInfo!.profileImageUrl!.isNotEmpty) {
        try {
          await _storageService.deleteFile(_userInfo!.profileImageUrl!);
        } catch (e) {
          debugPrint('⚠️ Could not delete old image: $e');
        }
      }

      // Yeni fotoğrafı yükle
      final imageUrl = await _storageService.uploadFile(
        file: imageFile,
        path: 'profile_images/$uid',
      );

      if (imageUrl == null) return false;

      // Firebase users collection'ı güncelle
      await _firestore.collection('users').doc(uid).update({
        'profileImage': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Kullanıcı rolünü kontrol et
      final userData = _localStorage.getUserData();
      final role = userData?['role'];

      // Mentor ise mentors collection'ı da güncelle
      if (role == 'mentor') {
        await _firestore.collection('mentors').doc(uid).update({
          'profileImage': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Local storage'ı güncelle
      final localUserData = userData ?? {};
      localUserData['profileImage'] = imageUrl;
      await _localStorage.saveUserData(localUserData);

      // Model'i güncelle
      _userInfo = UserInfoModel(
        name: _userInfo!.name,
        email: _userInfo!.email,
        phone: _userInfo!.phone,
        bio: _userInfo!.bio,
        profileImageUrl: imageUrl,
        createdAt: _userInfo!.createdAt,
      );

      debugPrint('✅ Profile image updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating profile image: $e');
      return false;
    } finally {
      _isSaving = false;
      _safeNotifyListeners();
    }
  }


  /// Şifre değiştir
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      // Önce mevcut şifreyi doğrula
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Yeni şifreyi güncelle
      await user.updatePassword(newPassword);

      debugPrint('✅ Password changed successfully');
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ Error changing password: ${e.code}');
      throw _getPasswordErrorMessage(e.code);
    } catch (e) {
      debugPrint('❌ Error changing password: $e');
      return false;
    }
  }

  String _getPasswordErrorMessage(String code) {
    switch (code) {
      case 'wrong-password':
        return 'Mevcut şifre yanlış';
      case 'weak-password':
        return 'Yeni şifre çok zayıf';
      case 'requires-recent-login':
        return 'Güvenlik nedeniyle yeniden giriş yapmanız gerekiyor';
      default:
        return 'Şifre değiştirilemedi';
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}