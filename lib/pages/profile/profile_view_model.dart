import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mykoc/pages/profile/profile_model.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

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

    _profileData = ProfileModel(
      userName: name,
      userInitials: _getInitials(name),
      userRole: role,
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

      // TODO: Gerçek verileri Firestore'dan çek
      _profileData = ProfileModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: role,
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
      await _auth.signOut();
      await _localStorage.clearAllUserData();

      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/signin', (route) => false);
      }
    } catch (e) {
      debugPrint('Logout error: $e');
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