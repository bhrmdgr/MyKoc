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
  bool _isInitialized = false;

  HomeModel? _homeData;
  HomeModel? get homeData => _homeData;

  List<ClassModel> _classes = [];
  List<ClassModel> get classes => _classes;

  ClassModel? _activeClass;
  ClassModel? get activeClass => _activeClass;

  List<TaskModel> _studentTasks = [];
  List<TaskModel> get studentTasks => _studentTasks;

  List<AnnouncementModel> _studentAnnouncements = [];
  List<AnnouncementModel> get studentAnnouncements => _studentAnnouncements;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSwitchingClass = false;
  bool get isSwitchingClass => _isSwitchingClass;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final Map<String, List<TaskModel>> _tasksCache = {};
  final Map<String, List<AnnouncementModel>> _announcementsCache = {};

  Future<void> initialize() async {
    if (_isDisposed) return;
    if (_isInitialized && _homeData != null) return;

    _errorMessage = null;
    _setLoading(true);

    try {
      bool hasLocalData = await _loadFromLocalStorage();

      if (hasLocalData) {
        _isInitialized = true;
        _setLoading(false); // UI hemen açılsın
        _safeNotifyListeners();

        // AMA Firestore güncel verisini mutlaka arkada çekmeye devam et
        // return; <-- BU SATIRI KALDIRIN veya kontrol ekleyin.
      }

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        debugPrint('🌐 Fetching latest data from Firestore...');
        await _loadFromFirestore();
      } else {
        _errorMessage = 'Oturum bilgisi bulunamadı.';
      }
    } catch (e) {
      _errorMessage = 'Veri yüklenirken bir hata oluştu';
      debugPrint('❌ HomeViewModel Error: $e');
    } finally {
      _setLoading(false);
      _isInitialized = true;
      _safeNotifyListeners();
    }
  }

  Future<void> _loadFromFirestore() async {
    String? uid = _localStorage.getUid() ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _isDisposed) return;

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final name = userData['name'] ?? 'User';
      final role = userData['role'] ?? 'student';

      await _localStorage.saveUid(uid);
      await _localStorage.saveUserData({
        'uid': uid,
        'name': name,
        'role': role,
        'profileImage': userData['profileImage'],
      });

      if (role == 'mentor') {
        _classes = await _classroomService.getMentorClasses(uid);
        await _localStorage.saveClassesList(_classes.map((c) => c.toMap()).toList());
      } else {
        _classes = await _classroomService.getStudentClasses(uid);
        if (_classes.isNotEmpty) {
          await _localStorage.saveStudentClasses(_classes.map((c) => c.toMap()).toList());

          final activeClassId = _localStorage.getActiveClassId();
          _activeClass = _classes.firstWhere(
                (c) => c.id == activeClassId,
            orElse: () => _classes.first,
          );

          if (_localStorage.getActiveClassId() == null) {
            await _localStorage.saveActiveClassId(_activeClass!.id);
          }

          await _loadStudentTasksAndAnnouncements(uid, _activeClass!.id);
        }
      }

      final sessions = await _fetchUpcomingSessions(uid, role);

      _homeData = HomeModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: role,
        profileImageUrl: userData['profileImage'],
        completedTasks: _studentTasks.where((t) => t.status == 'completed').length,
        totalTasks: _studentTasks.length,
        upcomingSessions: sessions,
      );

      debugPrint('✅ Firestore sync completed and UI updated');
      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Firestore load failed: $e');
    }
  }

  Future<bool> _loadFromLocalStorage() async {
    if (_isDisposed) return false;
    final userData = _localStorage.getUserData();
    if (userData == null) return false;

    try {
      final name = userData['name'] ?? 'User';
      final role = userData['role'] ?? 'student';

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

            final localTasks = _localStorage.getStudentTasks();
            if (localTasks != null) {
              _studentTasks = localTasks.map((t) => TaskModel.fromMap(t)).toList();
            }

            final localAnnouncements = _localStorage.getLocalAnnouncements();
            if (localAnnouncements != null) {
              _studentAnnouncements = localAnnouncements.map((a) => AnnouncementModel.fromLocalMap(a)).toList();
            }
          }
        }
      }

      _homeData = HomeModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: role,
        profileImageUrl: userData['profileImage'],
        completedTasks: _studentTasks.where((t) => t.status == 'completed').length,
        totalTasks: _studentTasks.length,
        upcomingSessions: _getDummySessions(),
      );

      return true;
    } catch (e) {
      debugPrint('⚠️ Local load failed: $e');
      return false;
    }
  }

  Future<void> _loadStudentTasksAndAnnouncements(String studentId, String classId) async {
    try {
      if (_isDisposed) return;

      final allTasks = await _taskService.getStudentTasks(studentId);
      _studentTasks = allTasks.where((task) => task.classId == classId).toList();
      _studentTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      _tasksCache[classId] = List.from(_studentTasks);
      await _localStorage.saveStudentTasks(_studentTasks.map((t) => t.toMap()).toList());

      final announcements = await _announcementService.getClassAnnouncements(classId);
      _studentAnnouncements = announcements.take(5).toList();
      _announcementsCache[classId] = List.from(_studentAnnouncements);

      // ✅ DÜZELTME: toMap() yerine toLocalMap() kullanıldı.
      // SharedPreferences'a Timestamp içeren veri gönderilemez.
      await _localStorage.saveLocalAnnouncements(
          _studentAnnouncements.map((a) => a.toLocalMap()).toList()
      );

      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading tasks and announcements: $e');
    }
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
      if (_tasksCache.containsKey(classId)) {
        _studentTasks = _tasksCache[classId]!;
        _studentAnnouncements = _announcementsCache[classId] ?? [];
      } else {
        final uid = _localStorage.getUid();
        if (uid != null) {
          await _loadStudentTasksAndAnnouncements(uid, classId);
        }
      }

      _homeData = HomeModel(
        userName: _homeData?.userName ?? "",
        userInitials: _homeData?.userInitials ?? "",
        userRole: _homeData?.userRole ?? "",
        profileImageUrl: _homeData?.profileImageUrl,
        completedTasks: _studentTasks.where((t) => t.status == 'completed').length,
        totalTasks: _studentTasks.length,
        upcomingSessions: _getDummySessions(),
      );
    } finally {
      _isSwitchingClass = false;
      _safeNotifyListeners();
    }
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) notifyListeners();
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
    _isInitialized = false;
    clearCache();
    await _loadFromFirestore();
    _isInitialized = true;
    _safeNotifyListeners();
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