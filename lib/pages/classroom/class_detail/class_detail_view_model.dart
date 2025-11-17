import 'package:flutter/material.dart';
import 'package:mykoc/firebase/classroom/classroom_service.dart';
import 'package:mykoc/firebase/tasks/task_service.dart';
import 'package:mykoc/pages/classroom/class_model.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class ClassDetailViewModel extends ChangeNotifier {
  final String classId;
  final ClassroomService _classroomService = ClassroomService();
  final TaskService _taskService = TaskService();
  final LocalStorageService _localStorage = LocalStorageService();

  ClassModel? _classData;
  ClassModel? get classData => _classData;

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> get students => _students;

  List<TaskModel> _tasks = [];
  List<TaskModel> get tasks => _tasks;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ClassDetailViewModel({required this.classId});

  Future<void> initialize() async {
    _isLoading = false;

    try {
      // Önce local'den yükle (hızlı gösterim)
      await _loadFromLocal();
      notifyListeners();

      // Sonra Firestore'dan güncelle (arka planda)
      _isLoading = true;
      notifyListeners();

      await _loadFromFirestore();
    } catch (e) {
      debugPrint('Error loading class details: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadFromLocal() async {
    try {
      // Class bilgisini local'den yükle
      final localClass = _localStorage.getClass(classId);
      if (localClass != null) {
        _classData = ClassModel.fromMap(localClass);
        debugPrint('📦 Class bilgisi local\'den yüklendi: ${_classData?.className}');
      }

      // Öğrencileri local'den yükle
      final localStudents = _localStorage.getClassStudents(classId);
      debugPrint('🔍 Local students check for classId: $classId');
      debugPrint('🔍 Local students result: $localStudents');

      if (localStudents != null && localStudents.isNotEmpty) {
        _students = localStudents;
        debugPrint('📦 ${_students.length} öğrenci local\'den yüklendi');
      } else {
        debugPrint('⚠️ Local\'de öğrenci bulunamadı');
      }

      // TODO: Tasks'ı local'den yükle (implement later)
    } catch (e) {
      debugPrint('❌ Error loading from local: $e');
    }
  }

  Future<void> _loadFromFirestore() async {
    try {
      debugPrint('🔥 Firestore\'dan class bilgisi çekiliyor: $classId');

      // Class bilgisini Firestore'dan güncelle
      _classData = await _classroomService.getClassById(classId);

      if (_classData != null) {
        debugPrint('✅ Class bulundu: ${_classData?.className}');
        await _localStorage.saveClass(classId, _classData!.toMap());
      }

      // Öğrencileri Firestore'dan güncelle
      debugPrint('🔥 Firestore\'dan öğrenciler çekiliyor...');
      _students = await _classroomService.getClassStudents(classId);

      debugPrint('✅ Firestore\'dan ${_students.length} öğrenci yüklendi');

      if (_students.isNotEmpty) {
        await _localStorage.saveClassStudents(classId, _students);
        debugPrint('💾 Öğrenciler local\'e kaydedildi');
      }

      // Tasks'ları Firestore'dan yükle
      debugPrint('🔥 Firestore\'dan görevler çekiliyor...');
      _tasks = await _taskService.getClassTasks(classId);
      debugPrint('✅ Firestore\'dan ${_tasks.length} görev yüklendi');

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading from Firestore: $e');
    }
  }

  Future<void> refresh() async {
    await _loadFromFirestore();
  }

  @override
  void dispose() {
    super.dispose();
  }
}