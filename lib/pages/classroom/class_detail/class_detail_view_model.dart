import 'package:flutter/material.dart';
import 'package:mykoc/firebase/classroom/classroom_service.dart';
import 'package:mykoc/firebase/tasks/task_service.dart';
import 'package:mykoc/pages/classroom/class_detail/announcement_model.dart';
import 'package:mykoc/firebase/announcement/announcement_service.dart';  // ← YENİ: FCM destekli service
import 'package:mykoc/pages/classroom/class_model.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class ClassDetailViewModel extends ChangeNotifier {
  final String classId;
  final ClassroomService _classroomService = ClassroomService();
  final TaskService _taskService = TaskService();
  final AnnouncementService _announcementService = AnnouncementService();  // ← Bu artık FCM destekli
  final LocalStorageService _localStorage = LocalStorageService();

  ClassModel? _classData;
  ClassModel? get classData => _classData;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> get students => _students;

  List<TaskModel> _tasks = [];
  List<TaskModel> get tasks => _tasks;

  List<AnnouncementModel> _announcements = [];
  List<AnnouncementModel> get announcements => _announcements;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ==================== YENİ: GÖREV DETAYLARI VE İSTATİSTİK MAP'İ ====================
  // Her görevin (taskId) detaylı durumlarını (StudentTaskStatus listesi) tutar.
  Map<String, TaskDetailWithStudents> _taskDetails = {};
  Map<String, TaskDetailWithStudents> get taskDetails => _taskDetails;
  // =================================================================================

  // Mentörün premium olup olmadığını kontrol eder
  bool get isPremium {
    final mentorData = _localStorage.getMentorData();
    return mentorData?['subscriptionTier'] == 'premium';
  }

  // Sınıf başına maksimum öğrenci limitini döner
  int get maxStudentLimit {
    final mentorData = _localStorage.getMentorData();
    return mentorData?['maxStudentsPerClass'] ?? 10;
  }

  // ==================== EKLEME: ORAN VE İSTATİSTİKLER ====================

  /// Sınıftaki mevcut öğrenci sayısı
  int get currentStudentCount => _students.length;

  /// Öğrenci doluluk oranı (0.0 ile 1.0 arasında)
  double get enrollmentRatio {
    if (maxStudentLimit == 0) return 0.0;
    double ratio = currentStudentCount / maxStudentLimit;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  /// UI'da gösterilecek metin (Örn: "8 / 10")
  String get enrollmentText => '$currentStudentCount / $maxStudentLimit';

  /// Doluluk yüzdesi metni (Örn: "%80")
  String get enrollmentPercentage => '${(enrollmentRatio * 100).toInt()}%';

  /// Sınıfın dolup dolmadığını kontrol eder
  bool get isClassFull => currentStudentCount >= maxStudentLimit;

  /// Toplam görev sayısı
  int get totalTaskCount => _tasks.length;

  /// Sınıfın genel ödev tamamlama oranı (0.0 - 1.0)
  double get overallCompletionRatio {
    if (_tasks.isEmpty || _taskDetails.isEmpty) return 0.0;

    int totalAssignments = 0; // Toplam atanan ödev sayısı (Görev Sayısı * Öğrenci Sayısı gibi)
    int totalCompleted = 0;   // Toplam tamamlanan ödev sayısı

    for (var detail in _taskDetails.values) {
      totalAssignments += detail.totalStudents;
      totalCompleted += detail.completedCount;
    }

    if (totalAssignments == 0) return 0.0;
    return totalCompleted / totalAssignments;
  }

  /// UI'da gösterilecek genel başarı yüzdesi (Örn: "%75")
  String get overallCompletionPercentage => '${(overallCompletionRatio * 100).toInt()}%';

  // ======================================================================

  ClassDetailViewModel({required this.classId});

  bool _isProcessing = false; // Metodun meşgul olup olmadığını tutar

  Future<void> initialize() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      _isLoading = true;
      await _loadFromLocal();
      notifyListeners();

      await _loadFromFirestore();
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      _isLoading = false;
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Öğrenci ekleme limitini servisten kontrol eder
  Future<bool> checkStudentLimit() async {
    try {
      final bool canAdd = await _classroomService.checkStudentLimit(classId);
      if (!canAdd) {
        await refresh();
      }
      return canAdd;
    } catch (e) {
      debugPrint('Limit kontrol hatası: $e');
      return false;
    }
  }

  Future<void> _loadFromLocal() async {
    try {
      final localClass = _localStorage.getClass(classId);
      if (localClass != null) {
        _classData = ClassModel.fromMap(localClass);
      }

      final localStudents = _localStorage.getClassStudents(classId);
      if (localStudents != null && localStudents.isNotEmpty) {
        _students = localStudents;
      }

      final localAnnouncements = _localStorage.getClassAnnouncements(classId);
      if (localAnnouncements != null && localAnnouncements.isNotEmpty) {
        _announcements = localAnnouncements
            .map((a) => AnnouncementModel.fromLocalMap(a))
            .toList();
      }

      final localTasks = _localStorage.getStudentTasks();
      if (localTasks != null && localTasks.isNotEmpty) {
        _tasks = localTasks.map((t) => TaskModel.fromMap(t)).toList();
      }
    } catch (e) {
      debugPrint('❌ Error loading from local: $e');
    }
  }

  Future<void> _loadFromFirestore() async {
    try {
      debugPrint('🔥 Firestore\'dan class bilgisi çekiliyor: $classId');

      _classData = await _classroomService.getClassById(classId);
      if (_classData != null) {
        await _localStorage.saveClass(classId, _classData!.toMap());
      }

      _students = await _classroomService.getClassStudents(classId);
      if (_students.isNotEmpty) {
        await _localStorage.saveClassStudents(classId, _students);
      }

      _tasks = await _taskService.getClassTasks(classId);
      if (_tasks.isNotEmpty) {
        await _localStorage.saveStudentTasks(_tasks.map((t) => t.toMap()).toList());

        // ==================== YENİ: GÖREV İSTATİSTİKLERİNİ ÇEK ====================
        await _fetchAllTaskDetails();
        // =========================================================================
      }

      _announcements = await _announcementService.getClassAnnouncements(classId);
      if (_announcements.isNotEmpty) {
        await _localStorage.saveClassAnnouncements(
            classId,
            _announcements.map((a) => a.toLocalMap()).toList()
        );
      }

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading from Firestore: $e');
    }
  }

  /// Tüm görevlerin istatistiklerini (kim yaptı, kim yapmadı) arka arkaya çeker.
  Future<void> _fetchAllTaskDetails() async {
    if (_tasks.isEmpty) return;

    Map<String, TaskDetailWithStudents> tempDetails = {};

    for (var task in _tasks) {
      final detail = await _taskService.getTaskDetailWithStudents(taskId: task.id);
      if (detail != null) {
        tempDetails[task.id] = detail;
      }
    }

    _taskDetails = tempDetails;
    notifyListeners();
  }

  Future<void> refresh() async {
    await _loadFromFirestore();
  }

  // ==================== ANNOUNCEMENT İŞLEMLERİ ====================

  Future<bool> createAnnouncement({
    required String mentorId,
    required String title,
    required String description,
  }) async {
    try {
      final announcementId = await _announcementService.createAnnouncement(
        classId: classId,
        mentorId: mentorId,
        title: title,
        description: description,
      );

      if (announcementId != null) {
        final newAnnouncement = AnnouncementModel(
          id: announcementId,
          classId: classId,
          mentorId: mentorId,
          title: title,
          description: description,
          createdAt: DateTime.now(),
        );
        _announcements.insert(0, newAnnouncement);
        notifyListeners();
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error creating announcement: $e');
      return false;
    }
  }

  Future<bool> updateAnnouncement({
    required String announcementId,
    required String title,
    required String description,
  }) async {
    try {
      final success = await _announcementService.updateAnnouncement(
        announcementId: announcementId,
        classId: classId,
        title: title,
        description: description,
      );

      if (success) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error updating announcement: $e');
      return false;
    }
  }

  Future<bool> deleteAnnouncement(String announcementId) async {
    try {
      final success = await _announcementService.deleteAnnouncement(
        announcementId,
        classId,
      );

      if (success) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting announcement: $e');
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}