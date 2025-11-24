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

  // YENİ: Sınıf değiştirme loading state'i
  bool _isSwitchingClass = false;
  bool get isSwitchingClass => _isSwitchingClass;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // YENİ: Her sınıf için task ve announcement cache'i
  final Map<String, List<TaskModel>> _tasksCache = {};
  final Map<String, List<AnnouncementModel>> _announcementsCache = {};

  Future<void> initialize() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _loadFromLocalStorage();
      notifyListeners();
      await _loadFromFirestore();
    } catch (e) {
      _errorMessage = 'Veri yüklenirken bir hata oluştu';
      debugPrint('HomeViewModel Error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadFromLocalStorage() async {
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

    // Local'den sınıfları yükle
    if (role == 'mentor') {
      final localClasses = _localStorage.getClassesList();
      if (localClasses != null && localClasses.isNotEmpty) {
        _classes = localClasses
            .map((data) => ClassModel.fromMap(data))
            .toList();
        debugPrint('📦 Local\'den ${_classes.length} sınıf yüklendi');
      }
    } else {
      // Öğrenci için birden fazla sınıf
      final localClasses = _localStorage.getStudentClasses();
      if (localClasses != null && localClasses.isNotEmpty) {
        _classes = localClasses.map((data) => ClassModel.fromMap(data)).toList();
        debugPrint('📦 Local\'den ${_classes.length} öğrenci sınıfı yüklendi');

        // Aktif sınıfı belirle
        final activeClassId = _localStorage.getActiveClassId();
        if (activeClassId != null) {
          _activeClass = _classes.firstWhere(
                (c) => c.id == activeClassId,
            orElse: () => _classes.first,
          );
        } else {
          _activeClass = _classes.first;
        }
        debugPrint('🎯 Aktif sınıf: ${_activeClass?.className}');
      }
    }
  }

  Future<void> _loadFromFirestore() async {
    final uid = _localStorage.getUid();
    if (uid == null) {
      _errorMessage = 'Kullanıcı bulunamadı';
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        _errorMessage = 'Kullanıcı kaydı bulunamadı';
        return;
      }

      final userData = userDoc.data()!;
      final name = userData['name'] ?? 'User';
      final role = userData['role'] ?? 'student';

      debugPrint('👤 User: $name, Role: $role');

      if (role == 'mentor') {
        debugPrint('📚 Firestore\'dan mentör sınıfları çekiliyor...');
        _classes = await _classroomService.getMentorClasses(uid);

        final classesData = _classes.map((c) => c.toMap()).toList();
        await _localStorage.saveClassesList(classesData);

        debugPrint('✅ Firestore\'dan ${_classes.length} sınıf yüklendi');
      } else {
        debugPrint('📚 Firestore\'dan öğrenci sınıfları çekiliyor...');
        _classes = await _classroomService.getStudentClasses(uid);

        if (_classes.isNotEmpty) {
          // Sınıfları local'e kaydet
          await _localStorage.saveStudentClasses(
            _classes.map((c) => c.toMap()).toList(),
          );

          // Aktif sınıfı belirle
          final activeClassId = _localStorage.getActiveClassId();
          if (activeClassId != null) {
            _activeClass = _classes.firstWhere(
                  (c) => c.id == activeClassId,
              orElse: () => _classes.first,
            );
          } else {
            _activeClass = _classes.first;
            await _localStorage.saveActiveClassId(_activeClass!.id);
          }

          debugPrint('✅ ${_classes.length} sınıf yüklendi');
          debugPrint('🎯 Aktif sınıf: ${_activeClass?.className}');

          // Aktif sınıf için task ve duyuruları çek
          await _loadStudentTasksAndAnnouncements(uid, _activeClass!.id);
        }
      }

      final sessions = await _fetchUpcomingSessions(uid, role);

      // Completed tasks sayısını hesapla
      final completedTasksCount = _studentTasks
          .where((task) => (task.status ?? 'not_started') == 'completed')
          .length;

      _homeData = HomeModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: role,
        profileImageUrl: userData['profileImage'],
        completedTasks: completedTasksCount,
        totalTasks: _studentTasks.length > 0 ? _studentTasks.length : 5,
        upcomingSessions: sessions,
      );

      // Timestamp'leri temizle
      final userDataToSave = Map<String, dynamic>.from(userData);
      userDataToSave.removeWhere((key, value) => value is Timestamp);

      await _localStorage.saveUserData(userDataToSave);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Veri yüklenirken hata oluştu';
      debugPrint('❌ Error loading from Firestore: $e');
    }
  }

  /// Aktif sınıfı değiştir - OPTIMIZE EDİLDİ
  Future<void> switchActiveClass(String classId) async {
    // Aynı sınıfa geçiş yapılıyorsa işlem yapma
    if (_activeClass?.id == classId) {
      debugPrint('⚠️ Zaten aktif sınıf: $classId');
      return;
    }

    final targetClass = _classes.firstWhere(
          (c) => c.id == classId,
      orElse: () => _classes.first,
    );

    _activeClass = targetClass;
    await _localStorage.saveActiveClassId(classId);

    debugPrint('🔄 Sınıf değiştirildi: ${_activeClass?.className}');

    // Loading animasyonunu başlat
    _isSwitchingClass = true;
    notifyListeners();

    try {
      // CACHE KONTROLÜ: Eğer bu sınıfın verileri cache'de varsa, hemen kullan
      if (_tasksCache.containsKey(classId) && _announcementsCache.containsKey(classId)) {
        debugPrint('💨 Cache\'den yükleniyor: $classId');

        _studentTasks = _tasksCache[classId]!;
        _studentAnnouncements = _announcementsCache[classId]!;

        // Hızlı geçiş için kısa bir delay
        await Future.delayed(const Duration(milliseconds: 300));

        debugPrint('✅ Cache\'den ${_studentTasks.length} task ve ${_studentAnnouncements.length} duyuru yüklendi');
      } else {
        // Cache'de yoksa Firestore'dan çek
        debugPrint('🔥 Firestore\'dan yükleniyor: $classId');
        final uid = _localStorage.getUid();
        if (uid != null) {
          await _loadStudentTasksAndAnnouncements(uid, classId);
        }
      }
    } finally {
      _isSwitchingClass = false;
      notifyListeners();
    }
  }

  Future<void> _loadStudentTasksAndAnnouncements(String studentId, String classId) async {
    try {
      debugPrint('📋 Öğrenci task\'ları çekiliyor...');

      final allTasks = await _taskService.getStudentTasks(studentId);
      _studentTasks = allTasks.where((task) => task.classId == classId).toList();

      debugPrint('✅ ${_studentTasks.length} task yüklendi (classId: $classId)');
      _studentTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      _tasksCache[classId] = List.from(_studentTasks);

      debugPrint('📢 Sınıf duyuruları çekiliyor...');
      _studentAnnouncements = await _announcementService.getClassAnnouncements(classId);
      debugPrint('✅ ${_studentAnnouncements.length} duyuru yüklendi');

      if (_studentAnnouncements.length > 5) {
        _studentAnnouncements = _studentAnnouncements.take(5).toList();
      }

      _announcementsCache[classId] = List.from(_studentAnnouncements);

      // ← BU SATIRDA
      _safeNotifyListeners(); // notifyListeners() yerine
    } catch (e) {
      debugPrint('❌ Error loading student tasks and announcements: $e');
    }
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }
  /// Cache'i temizle - Yeni task eklendiğinde veya güncelleme yapıldığında kullanılır
  void clearCache({String? classId}) {
    if (classId != null) {
      _tasksCache.remove(classId);
      _announcementsCache.remove(classId);
      debugPrint('🗑️ Cache temizlendi: $classId');
    } else {
      _tasksCache.clear();
      _announcementsCache.clear();
      debugPrint('🗑️ Tüm cache temizlendi');
    }
  }

  /// Yenileme - Cache'i temizler ve yeniden yükler
  Future<void> refresh() async {
    clearCache();
    await _loadFromFirestore();
  }

  /// Spesifik sınıf için yenileme
  Future<void> refreshClass(String classId) async {
    clearCache(classId: classId);

    final uid = _localStorage.getUid();
    if (uid != null) {
      _isSwitchingClass = true;
      notifyListeners();

      try {
        await _loadStudentTasksAndAnnouncements(uid, classId);
      } finally {
        _isSwitchingClass = false;
        notifyListeners();
      }
    }
  }

  Future<List<SessionModel>> _fetchUpcomingSessions(String uid, String role) async {
    try {
      return _getDummySessions();
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
      return _getDummySessions();
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
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
    // Cache'i temizle
    _tasksCache.clear();
    _announcementsCache.clear();
    super.dispose();
  }
}