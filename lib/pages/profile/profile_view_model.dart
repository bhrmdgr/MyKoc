import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mykoc/pages/profile/profile_model.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:mykoc/routers/appRouter.dart';

class ProfileViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  ProfileModel? _profileData;
  ProfileModel? get profileData => _profileData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadFromLocalStorage();
      notifyListeners();
      await _loadFromFirestore();
    } catch (e) {
      debugPrint('ProfileViewModel Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromLocalStorage() async {
    final userData = _localStorage.getUserData();
    if (userData == null) return;

    final name = userData['name'] ?? 'User';
    final role = userData['role'] ?? 'student';
    final email = userData['email'] ?? '';

    _profileData = ProfileModel(
      userName: name,
      userInitials: _getInitials(name),
      userRole: role,
      email: email,
      profileImageUrl: userData['profileImage'],
      // Dummy data
      badges: role == 'student' ? 12 : null,
      completionPercentage: role == 'student' ? 87 : null,
      dayStreak: role == 'student' ? 15 : null,
      currentLevel: role == 'student' ? 8 : null,
      currentXP: role == 'student' ? 650 : null,
      xpToNextLevel: role == 'student' ? 1000 : null,
      recentBadges: role == 'student' ? ['🏆', '⭐', '🎯', '🔥'] : null,
      classCount: role == 'mentor' ? 4 : null,
      studentCount: role == 'mentor' ? 89 : null,
      activeTasks: role == 'mentor' ? 11 : null,
      avgCompletion: role == 'mentor' ? 92 : null,
    );
  }

  Future<void> _loadFromFirestore() async {
    final uid = _localStorage.getUid();
    if (uid == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final name = userData['name'] ?? 'User';
      final role = userData['role'] ?? 'student';
      final email = userData['email'] ?? '';

      // TODO: Gerçek verileri Firestore'dan çek
      _profileData = ProfileModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: role,
        email: email,
        profileImageUrl: userData['profileImage'],
        badges: role == 'student' ? 12 : null,
        completionPercentage: role == 'student' ? 87 : null,
        dayStreak: role == 'student' ? 15 : null,
        currentLevel: role == 'student' ? 8 : null,
        currentXP: role == 'student' ? 650 : null,
        xpToNextLevel: role == 'student' ? 1000 : null,
        recentBadges: role == 'student' ? ['🏆', '⭐', '🎯', '🔥'] : null,
        classCount: role == 'mentor' ? 4 : null,
        studentCount: role == 'mentor' ? 89 : null,
        activeTasks: role == 'mentor' ? 11 : null,
        avgCompletion: role == 'mentor' ? 92 : null,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> logout(BuildContext context) async {
    try {
      // Firebase'den çıkış yap
      await _auth.signOut();

      // Local storage'ı temizle
      await _localStorage.clearAll();

      debugPrint('✅ User logged out successfully');

      // Login sayfasına yönlendir
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

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  void dispose() {
    super.dispose();
  }
}