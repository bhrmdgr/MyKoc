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

  HomeModel? _homeData;
  HomeModel? get homeData => _homeData;

  List<ClassModel> _classes = [];
  List<ClassModel> get classes => _classes;

  // Öğrenci için task'lar ve duyurular
  List<TaskModel> _studentTasks = [];
  List<TaskModel> get studentTasks => _studentTasks;

  List<AnnouncementModel> _studentAnnouncements = [];
  List<AnnouncementModel> get studentAnnouncements => _studentAnnouncements;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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

    // Local'den sınıfları da yükle
    if (role == 'mentor') {
      final localClasses = _localStorage.getClassesList();
      if (localClasses != null && localClasses.isNotEmpty) {
        _classes = localClasses
            .map((data) => ClassModel.fromMap(data))
            .toList();
        debugPrint('📦 Local\'den ${_classes.length} sınıf yüklendi');
      }
    } else {
      final localClass = _localStorage.getStudentClass();
      if (localClass != null) {
        _classes = [ClassModel.fromMap(localClass)];
        debugPrint('📦 Local\'den öğrenci sınıfı yüklendi');
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

      // Firestore'dan sınıfları çek ve güncelle
      if (role == 'mentor') {
        debugPrint('📚 Firestore\'dan mentör sınıfları çekiliyor...');
        _classes = await _classroomService.getMentorClasses(uid);

        // Firestore'dan gelen verileri local'e kaydet
        final classesData = _classes.map((c) => c.toMap()).toList();
        await _localStorage.saveClassesList(classesData);

        debugPrint('✅ Firestore\'dan ${_classes.length} sınıf yüklendi ve local\'e kaydedildi');
      } else {
        debugPrint('📚 Firestore\'dan öğrenci sınıfları çekiliyor...');
        _classes = await _classroomService.getStudentClasses(uid);

        if (_classes.isNotEmpty) {
          await _localStorage.saveStudentClass(_classes.first.toMap());
          debugPrint('✅ Öğrenci sınıfı local\'e kaydedildi');

          // Öğrenci için task'ları ve duyuruları çek
          await _loadStudentTasksAndAnnouncements(uid, _classes.first.id);
        }
      }

      final sessions = await _fetchUpcomingSessions(uid, role);

      // Completed tasks sayısını hesapla (null kontrolü ile)
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

      final userDataToSave = Map<String, dynamic>.from(userData);
      if (userDataToSave['createdAt'] is Timestamp) {
        userDataToSave['createdAt'] =
            (userDataToSave['createdAt'] as Timestamp).toDate().toIso8601String();
      }

      await _localStorage.saveUserData(userDataToSave);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Veri yüklenirken hata oluştu';
      debugPrint('❌ Error loading from Firestore: $e');
    }
  }

  Future<void> _loadStudentTasksAndAnnouncements(String studentId, String classId) async {
    try {
      debugPrint('📋 Öğrenci task\'ları çekiliyor...');

      // Task'ları çek (status bilgisi ile)
      _studentTasks = await _taskService.getStudentTasks(studentId);
      debugPrint('✅ ${_studentTasks.length} task yüklendi');

      // Task'ları due date'e göre sırala (yakından uzağa)
      _studentTasks.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      // Duyuruları çek
      debugPrint('📢 Sınıf duyuruları çekiliyor...');
      _studentAnnouncements = await _announcementService.getClassAnnouncements(classId);
      debugPrint('✅ ${_studentAnnouncements.length} duyuru yüklendi');

      // En son 5 duyuruyu göster
      if (_studentAnnouncements.length > 5) {
        _studentAnnouncements = _studentAnnouncements.take(5).toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading student tasks and announcements: $e');
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

  Future<void> refresh() async {
    await _loadFromFirestore();
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
    super.dispose();
  }
}