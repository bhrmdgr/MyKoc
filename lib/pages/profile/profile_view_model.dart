import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mykoc/pages/profile/profile_model.dart';
import 'package:mykoc/firebase/classroom/classroom_service.dart';
import 'package:mykoc/firebase/tasks/task_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:mykoc/routers/appRouter.dart';

class ProfileViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalStorageService _localStorage = LocalStorageService();
  final ClassroomService _classroomService = ClassroomService();
  final TaskService _taskService = TaskService();

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

    if (role == 'student') {
      // Local'den sınıf ve task sayılarını al
      final classes = _localStorage.getStudentClasses() ?? [];

      _profileData = ProfileModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: role,
        email: email,
        profileImageUrl: userData['profileImage'],
        totalClasses: classes.length,
        totalTasks: 0, // Firestore'dan güncellenecek
        completedTasks: 0, // Firestore'dan güncellenecek
        completionPercentage: 0,
        badges: 12,
        dayStreak: 15,
        currentLevel: 8,
        currentXP: 650,
        xpToNextLevel: 1000,
        recentBadges: ['🏆', '⭐', '🎯', '🔥'],
      );
    } else {
      _profileData = ProfileModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: role,
        email: email,
        profileImageUrl: userData['profileImage'],
        classCount: 4,
        studentCount: 89,
        activeTasks: 11,
        avgCompletion: 92,
      );
    }
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

      if (role == 'student') {
        // Öğrencinin gerçek verilerini çek
        final classes = await _classroomService.getStudentClasses(uid);
        final tasks = await _taskService.getStudentTasks(uid);
        final completedTasks = tasks.where((t) => t.status == 'completed').length;

        _profileData = ProfileModel(
          userName: name,
          userInitials: _getInitials(name),
          userRole: role,
          email: email,
          profileImageUrl: userData['profileImage'],
          totalClasses: classes.length,
          totalTasks: tasks.length,
          completedTasks: completedTasks,
          completionPercentage: tasks.isEmpty ? 0 : ((completedTasks / tasks.length) * 100).round(),
          badges: 12,
          dayStreak: 15,
          currentLevel: 8,
          currentXP: 650,
          xpToNextLevel: 1000,
          recentBadges: ['🏆', '⭐', '🎯', '🔥'],
        );
      } else {
        // Mentor verileri
        _profileData = ProfileModel(
          userName: name,
          userInitials: _getInitials(name),
          userRole: role,
          email: email,
          profileImageUrl: userData['profileImage'],
          classCount: 4,
          studentCount: 89,
          activeTasks: 11,
          avgCompletion: 92,
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  /// Sınıfa katıl
  Future<bool> joinClass(String classCode) async {
    try {
      final uid = _localStorage.getUid();
      final userData = _localStorage.getUserData();

      if (uid == null || userData == null) {
        debugPrint('❌ User not found');
        return false;
      }

      final name = userData['name'] ?? 'Student';
      final email = userData['email'] ?? '';

      // Sınıf koduna göre sınıfı bul
      debugPrint('🔍 Searching for class with code: $classCode');
      final classModel = await _classroomService.getClassByCode(classCode);

      if (classModel == null) {
        debugPrint('❌ Class not found');
        return false;
      }

      debugPrint('✅ Class found: ${classModel.className}');

      // Öğrenciyi sınıfa ekle
      final success = await _classroomService.addStudentToClass(
        classId: classModel.id,
        studentId: uid,
        studentName: name,
        studentEmail: email,
      );

      if (success) {
        debugPrint('✅ Student added to class successfully');

        // Profil verilerini yeniden yükle
        await _loadFromFirestore();

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error joining class: $e');
      return false;
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