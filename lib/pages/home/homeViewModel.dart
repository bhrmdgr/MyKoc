import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mykoc/pages/home/homeModel.dart';
import 'package:mykoc/pages/classroom/class_model.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:mykoc/pages/classroom/class_detail/announcement_model.dart';
import 'package:mykoc/firebase/classroom/classroom_service.dart';
import 'package:mykoc/firebase/tasks/task_service.dart';
import 'package:mykoc/firebase/announcement/announcement_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class HomeViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ClassroomService _classroomService = ClassroomService();
  final TaskService _taskService = TaskService();
  final AnnouncementService _announcementService = AnnouncementService();
  final LocalStorageService _localStorage = LocalStorageService();

  bool _isDisposed = false;

  HomeModel? _homeData;
  HomeModel? get homeData => _homeData;

  List<ClassModel> _classes = [];
  List<ClassModel> get classes => _classes;

  // Aktif sınıf (öğrenci için)
  ClassModel? _activeClass;
  ClassModel? get activeClass => _activeClass;

  // Öğrenci için task'lar ve duyurular (aktif sınıfa göre)
  List<TaskModel> _studentTasks = [];
  List<TaskModel> get studentTasks => _studentTasks;

  List<AnnouncementModel> _studentAnnouncements = [];
  List<AnnouncementModel> get studentAnnouncements => _studentAnnouncements;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Sınıf değiştirme loading state'i
  bool _isSwitchingClass = false;
  bool get isSwitchingClass => _isSwitchingClass;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Her sınıf için task ve announcement cache'i
  final Map<String, List<TaskModel>> _tasksCache = {};
  final Map<String, List<AnnouncementModel>> _announcementsCache = {};

  Future<void> initialize() async {
    if (_isDisposed) return;
    _errorMessage = null;
    _setLoading(true);

    try {
      // 1. SharedPreferences'ın diske yazılma süresi için kısa bir bekleme
      await Future.delayed(const Duration(milliseconds: 300));

      // 2. Önce local'den yüklemeyi dene (Hızlı tepki için)
      await _loadFromLocalStorage();

      // 3. UID Kontrolü ve Firestore Senkronizasyonu
      String? uid = _localStorage.getUid();

      // Eğer SharedPreferences'ta yoksa Auth'dan alıp kaydet
      if (uid == null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          uid = currentUser.uid;
          await _localStorage.saveUid(uid);
        }
      }

      if (uid != null) {
        debugPrint('🚀 HomeViewModel: Syncing for UID: $uid');
        await _loadFromFirestore();
      } else {
        _errorMessage = 'Oturum bilgisi bulunamadı.';
      }
    } catch (e) {
      _errorMessage = 'Veri yüklenirken bir hata oluştu';
      debugPrint('❌ HomeViewModel Error: $e');
    } finally {
      _setLoading(false);
      _safeNotifyListeners();
    }
  }

  Future<void> _loadFromFirestore() async {
    final uid = _localStorage.getUid();
    if (uid == null || _isDisposed) return;

    try {
      // 1. Kullanıcı dökümanını taze olarak çek
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        debugPrint('⚠️ User doc not found in Firestore');
        return;
      }

      final userData = userDoc.data()!;
      final name = userData['name'] ?? 'User';
      final role = userData['role'] ?? 'student';

      // 2. Veriyi hemen yerel depolamaya yaz (Yarış durumunu önlemek için)
      await _localStorage.saveUserData({
        'uid': uid,
        'name': name,
        'role': role,
        'profileImage': userData['profileImage'],
      });

      // 3. Rol bazlı sınıf verilerini çek
      if (role == 'mentor') {
        _classes = await _classroomService.getMentorClasses(uid);
        final classesData = _classes.map((c) => c.toMap()).toList();
        await _localStorage.saveClassesList(classesData);
      } else {
        _classes = await _classroomService.getStudentClasses(uid);
        if (_classes.isNotEmpty) {
          await _localStorage.saveStudentClasses(
            _classes.map((c) => c.toMap()).toList(),
          );

          // Aktif sınıfı belirle
          final activeClassId = _localStorage.getActiveClassId();
          _activeClass = _classes.firstWhere(
                (c) => c.id == activeClassId,
            orElse: () => _classes.first,
          );

          if (_localStorage.getActiveClassId() == null) {
            await _localStorage.saveActiveClassId(_activeClass!.id);
          }

          // Görevleri ve duyuruları yükle
          await _loadStudentTasksAndAnnouncements(uid, _activeClass!.id);
        }
      }

      // 4. İstatistikleri ve HomeModel'i güncelle
      final sessions = await _fetchUpcomingSessions(uid, role);
      final completedTasksCount = _studentTasks
          .where((task) => (task.status ?? 'not_started') == 'completed')
          .length;

      _homeData = HomeModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: role,
        profileImageUrl: userData['profileImage'],
        completedTasks: completedTasksCount,
        totalTasks: _studentTasks.isNotEmpty ? _studentTasks.length : 5,
        upcomingSessions: sessions,
      );

      debugPrint('✅ Firestore sync completed');
      _safeNotifyListeners();

    } catch (e) {
      debugPrint('❌ Firestore load failed: $e');
      rethrow;
    }
  }

  Future<void> _loadFromLocalStorage() async {
    if (_isDisposed) return;
    final userData = _localStorage.getUserData();
    if (userData == null) return;

    final name = userData['name'] ?? 'User';
    final role = userData['role'] ?? 'student';

    _homeData = HomeModel(
      userName: name,
      userInitials: _getInitials(name),
      userRole: role,
      profileImageUrl: userData['profileImage'],
      completedTasks: 0,
      totalTasks: 5,
      upcomingSessions: _getDummySessions(),
    );

    if (role == 'mentor') {
      final localClasses = _localStorage.getClassesList();
      if (localClasses != null) {
        _classes = localClasses.map((data) => ClassModel.fromMap(data)).toList();
      }
    } else {
      final localClasses = _localStorage.getStudentClasses();
      if (localClasses != null) {
        _classes = localClasses.map((data) => ClassModel.fromMap(data)).toList();
        final activeClassId = _localStorage.getActiveClassId();
        if (_classes.isNotEmpty) {
          _activeClass = _classes.firstWhere(
                (c) => c.id == activeClassId,
            orElse: () => _classes.first,
          );
        }
      }
    }
    _safeNotifyListeners();
  }

  Future<void> switchActiveClass(String classId) async {
    if (_activeClass?.id == classId || _isDisposed) return;

    _activeClass = _classes.firstWhere(
          (c) => c.id == classId,
      orElse: () => _classes.first,
    );
    await _localStorage.saveActiveClassId(classId);

    _isSwitchingClass = true;
    _safeNotifyListeners();

    try {
      if (_tasksCache.containsKey(classId) && _announcementsCache.containsKey(classId)) {
        _studentTasks = _tasksCache[classId]!;
        _studentAnnouncements = _announcementsCache[classId]!;
        await Future.delayed(const Duration(milliseconds: 200));
      } else {
        final uid = _localStorage.getUid();
        if (uid != null) {
          await _loadStudentTasksAndAnnouncements(uid, classId);
        }
      }
    } finally {
      _isSwitchingClass = false;
      _safeNotifyListeners();
    }
  }

  Future<void> _loadStudentTasksAndAnnouncements(String studentId, String classId) async {
    try {
      if (_isDisposed) return;

      final allTasks = await _taskService.getStudentTasks(studentId);
      _studentTasks = allTasks.where((task) => task.classId == classId).toList();
      _studentTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      _tasksCache[classId] = List.from(_studentTasks);

      final announcements = await _announcementService.getClassAnnouncements(classId);
      _studentAnnouncements = announcements.take(5).toList();
      _announcementsCache[classId] = List.from(_studentAnnouncements);

      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading tasks and announcements: $e');
    }
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void clearCache({String? classId}) {
    if (classId != null) {
      _tasksCache.remove(classId);
      _announcementsCache.remove(classId);
    } else {
      _tasksCache.clear();
      _announcementsCache.clear();
    }
  }

  Future<void> refresh() async {
    clearCache();
    await _loadFromFirestore();
  }

  Future<void> refreshClass(String classId) async {
    clearCache(classId: classId);
    final uid = _localStorage.getUid();
    if (uid != null) {
      _isSwitchingClass = true;
      _safeNotifyListeners();
      try {
        await _loadStudentTasksAndAnnouncements(uid, classId);
      } finally {
        _isSwitchingClass = false;
        _safeNotifyListeners();
      }
    }
  }

  Future<List<SessionModel>> _fetchUpcomingSessions(String uid, String role) async {
    try {
      return _getDummySessions();
    } catch (e) {
      return _getDummySessions();
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    _safeNotifyListeners();
  }

  List<SessionModel> _getDummySessions() {
    return [
      SessionModel(
        id: '1',
        mentorName: 'Dr. Sarah Johnson',
        subject: 'Flutter Development',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        avatar: 'SJ',
      ),
      SessionModel(
        id: '2',
        mentorName: 'Prof. Michael Chen',
        subject: 'Career Guidance',
        dateTime: DateTime.now().add(const Duration(days: 3)),
        avatar: 'MC',
      ),
    ];
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tasksCache.clear();
    _announcementsCache.clear();
    super.dispose();
  }
}