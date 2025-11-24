import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mykoc/pages/profile/profile_model.dart';
import 'package:mykoc/pages/classroom/class_model.dart';
import 'package:mykoc/pages/tasks/task_model.dart';
import 'package:mykoc/firebase/classroom/classroom_service.dart';
import 'package:mykoc/firebase/tasks/task_service.dart';
import 'package:mykoc/firebase/profile/profile_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:mykoc/routers/appRouter.dart';
import 'package:mykoc/pages/auth/sign_in/signIn.dart';
import 'package:mykoc/firebase/messaging/fcm_service.dart';



class ProfileViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalStorageService _localStorage = LocalStorageService();
  final ClassroomService _classroomService = ClassroomService();
  final TaskService _taskService = TaskService();
  final ProfileService _profileService = ProfileService();

  ProfileModel? _profileData;
  ProfileModel? get profileData => _profileData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Tab kontrolü (Student View için)
  String _selectedTab = 'classes';
  String get selectedTab => _selectedTab;

  // Mentör Filtreleme (Default: 'classes')
  String _mentorFilter = 'classes';
  String get mentorFilter => _mentorFilter;

  // Veri Listeleri
  List<ClassModel> _classes = [];
  List<ClassModel> get classes => _classes;

  List<TaskModel> _tasks = [];
  List<TaskModel> get tasks => _tasks;

  // Mentör için Unique Öğrenci Listesi
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> get allStudents => _allStudents;

  // Görüntüleme modu
  bool _isMentorViewing = false;
  bool get isMentorViewing => _isMentorViewing;

  String? _viewedStudentId;
  String? get viewedStudentId => _viewedStudentId;

  bool _isDisposed = false;

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------------
  // TAB & FILTER MANAGEMENT
  // ------------------------------------------------------------------------

  /// Student View için Tab Değiştirme (Eksik olan metod buydu)
  void switchTab(String tab) {
    if (_selectedTab != tab) {
      _selectedTab = tab;
      _safeNotifyListeners();
    }
  }

  /// Mentor View için Filtre Değiştirme
  void setMentorFilter(String filter) {
    if (filter == 'tasks') return; // Task kartına tıklamayı engelle
    if (_mentorFilter == filter) return;

    _mentorFilter = filter;

    // Eğer öğrenciler seçildiyse Local'den derle
    if (filter == 'students') {
      if (_allStudents.isEmpty) {
        _compileUniqueStudentsFromLocal();
      }
    }

    _safeNotifyListeners();
  }

  /// Local cache'den benzersiz öğrenci listesini oluşturur
  void _compileUniqueStudentsFromLocal() {
    final Map<String, Map<String, dynamic>> uniqueStudentsMap = {};

    for (var classItem in _classes) {
      final classStudents = _localStorage.getClassStudents(classItem.id);
      if (classStudents != null) {
        for (var student in classStudents) {
          final uid = student['uid'] ?? student['id'];
          if (uid != null && !uniqueStudentsMap.containsKey(uid)) {
            final studentData = Map<String, dynamic>.from(student);
            studentData['displayClassName'] = classItem.className;
            uniqueStudentsMap[uid] = studentData;
          }
        }
      }
    }

    _allStudents = uniqueStudentsMap.values.toList();
    debugPrint('📦 Local derleme sonucu: ${_allStudents.length} benzersiz öğrenci');
  }

  // ------------------------------------------------------------------------
  // INITIALIZATION
  // ------------------------------------------------------------------------

  Future<void> initialize() async {
    _isLoading = true;
    _isMentorViewing = false;
    _viewedStudentId = null;
    _mentorFilter = 'classes';
    _safeNotifyListeners();

    try {
      await _loadFromLocalStorage();
      _safeNotifyListeners();
      await _loadFromFirestore();
    } catch (e) {
      debugPrint('❌ ProfileViewModel Error: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> initializeForStudent(String studentId) async {
    _isLoading = true;
    _isMentorViewing = true;
    _viewedStudentId = studentId;
    _safeNotifyListeners();

    try {
      await _loadStudentProfile(studentId);
    } catch (e) {
      debugPrint('❌ ProfileViewModel Error: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> initializeForMentor(String mentorId) async {
    _isLoading = true;
    _isMentorViewing = true; // Mentor başkasının profilini görüyor
    _viewedStudentId = null;
    _safeNotifyListeners();

    try {
      await _loadMentorProfile(mentorId);
    } catch (e) {
      debugPrint('❌ ProfileViewModel Error: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }


  // ------------------------------------------------------------------------
  // LOCAL STORAGE LOAD
  // ------------------------------------------------------------------------

  Future<void> _loadFromLocalStorage() async {
    final userData = _localStorage.getUserData();
    if (userData == null) return;

    final name = userData['name'] ?? 'User';
    final role = userData['role'] ?? 'student';
    final email = userData['email'] ?? '';

    if (role == 'student') {
      final localClasses = _localStorage.getStudentClasses() ?? [];
      _classes = localClasses.map((data) => ClassModel.fromMap(data)).toList();

      _profileData = ProfileModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: role,
        email: email,
        profileImageUrl: userData['profileImage'],
        totalClasses: _classes.length,
        totalTasks: 0,
        completedTasks: 0,
        completionPercentage: 0,
      );
    } else {
      // MENTOR LOCAL
      final localClasses = _localStorage.getClassesList() ?? [];
      _classes = localClasses.map((data) => ClassModel.fromMap(data)).toList();

      int localTaskCount = 0;
      for (var c in localClasses) {
        localTaskCount += (c['taskCount'] as int?) ?? 0;
      }

      // Local'deki unique öğrenci sayısını kabaca bulmaya çalış
      final uniqueIds = <String>{};
      for (var c in localClasses) {
        final s = _localStorage.getClassStudents(c['id']);
        if (s != null) {
          for(var stud in s) {
            if (stud['uid'] != null) uniqueIds.add(stud['uid']);
          }
        }
      }
      int localUniqueStudentCount = uniqueIds.isNotEmpty ? uniqueIds.length : 0;

      _profileData = ProfileModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: role,
        email: email,
        profileImageUrl: userData['profileImage'],
        classCount: _classes.length,
        studentCount: localUniqueStudentCount,
        activeTasks: localTaskCount,
      );
    }
  }

  // ------------------------------------------------------------------------
  // FIRESTORE LOAD & SYNC
  // ------------------------------------------------------------------------

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
        _classes = await _classroomService.getStudentClasses(uid);
        _tasks = await _taskService.getStudentTasks(uid);
        final completedTasks = _tasks.where((t) => t.status == 'completed').length;

        if (_classes.isNotEmpty) {
          await _localStorage.saveStudentClasses(
            _classes.map((c) => c.toMap()).toList(),
          );
        }

        _profileData = ProfileModel(
          userName: name,
          userInitials: _getInitials(name),
          userRole: role,
          email: email,
          profileImageUrl: userData['profileImage'],
          totalClasses: _classes.length,
          totalTasks: _tasks.length,
          completedTasks: completedTasks,
          completionPercentage: _tasks.isEmpty ? 0 : ((completedTasks / _tasks.length) * 100).round(),
        );
      } else {
        // MENTOR SYNC
        debugPrint('🔥 Fetching mentor data from Firestore...');

        // 1. Sınıfları çek
        _classes = await _profileService.getMentorClassesDetailed(uid);

        // 2. Task sayısını sınıfların içinden topla (daha güvenilir)
        int calculatedTaskCount = 0;
        for (var classItem in _classes) {
          calculatedTaskCount += classItem.taskCount;
        }

        // 3. UNIQUE ÖĞRENCİ SYNC İŞLEMİ
        // Firestore'dan tüm öğrencileri çekip local'e dağıtıyoruz ve unique sayıyı alıyoruz
        int uniqueStudentCount = await _syncAndCountUniqueStudents(uid);

        // 4. Sınıfları Local'e kaydet
        if (_classes.isNotEmpty) {
          await _localStorage.saveClassesList(
            _classes.map((c) => c.toMap()).toList(),
          );
        }

        // 5. Profili güncelle
        _profileData = ProfileModel(
          userName: name,
          userInitials: _getInitials(name),
          userRole: role,
          email: email,
          profileImageUrl: userData['profileImage'],
          classCount: _classes.length,
          studentCount: uniqueStudentCount, // Doğru sayı
          activeTasks: calculatedTaskCount,
        );

        // Eğer o an öğrenci sekmesi açıksa listeyi yenile
        if (_mentorFilter == 'students') {
          _compileUniqueStudentsFromLocal();
        }
      }

      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading from Firestore: $e');
    }
  }

  /// Firestore'dan öğrencileri çekip Local Storage'a sınıf bazlı kaydeder
  /// ve Unique sayıyı döndürür.
  Future<int> _syncAndCountUniqueStudents(String mentorId) async {
    try {
      debugPrint('🔄 Syncing students from Firebase to Local...');

      // 1. Veriyi çek
      final allEnrollments = await _profileService.getMentorAllStudents(mentorId);

      if (allEnrollments.isEmpty) return 0;

      // === DÜZELTME BURADA BAŞLIYOR ===
      // Firestore verisini Local Storage uyumlu hale getir (Timestamp -> String)
      final List<Map<String, dynamic>> processedEnrollments = allEnrollments.map((doc) {
        // Verinin kopyasını alıyoruz (immutable hatası almamak için)
        final data = Map<String, dynamic>.from(doc);

        // 'enrolledAt' alanı Timestamp ise String'e çevir
        if (data['enrolledAt'] is Timestamp) {
          data['enrolledAt'] = (data['enrolledAt'] as Timestamp).toDate().toIso8601String();
        }

        // Eğer başka tarih alanları varsa (createdAt vb.) onları da buraya ekleyin:
        // if (data['createdAt'] is Timestamp) ...

        return data;
      }).toList();
      // === DÜZELTME SONU ===

      // 2. Unique sayıyı hesapla (processedEnrollments kullanarak)
      final uniqueIds = processedEnrollments.map((e) => e['uid'] as String).toSet();
      final uniqueCount = uniqueIds.length;

      // 3. Verileri sınıflara göre grupla
      final Map<String, List<Map<String, dynamic>>> studentsByClass = {};

      for (var studentDoc in processedEnrollments) {
        final classId = studentDoc['classId'];
        if (classId != null) {
          if (!studentsByClass.containsKey(classId)) {
            studentsByClass[classId] = [];
          }
          studentsByClass[classId]!.add(studentDoc);
        }
      }

      // 4. Local Storage'a kaydet
      for (var classId in studentsByClass.keys) {
        await _localStorage.saveClassStudents(classId, studentsByClass[classId]!);
      }

      debugPrint('✅ Sync Complete: $uniqueCount unique students distributed.');
      return uniqueCount;

    } catch (e) {
      debugPrint('❌ Error syncing students: $e');
      // Hata olduğunda 0 döndürmek yerine, mevcut sayıyı korumak daha güvenli olabilir
      // ama şimdilik hatayı çözdüğümüz için 0 kalabilir.
      return 0;
    }
  }

  // ------------------------------------------------------------------------
  // HELPER METHODS
  // ------------------------------------------------------------------------

  Future<void> _loadMentorProfile(String mentorId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(mentorId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final name = userData['name'] ?? 'Mentor';
      final email = userData['email'] ?? '';

      // Mentor sınıflarını çek
      _classes = await _profileService.getMentorClassesDetailed(mentorId);

      // Task sayısını hesapla
      int calculatedTaskCount = 0;
      for (var classItem in _classes) {
        calculatedTaskCount += classItem.taskCount;
      }

      // Unique öğrenci sayısını hesapla
      int uniqueStudentCount = await _syncAndCountUniqueStudents(mentorId);

      _profileData = ProfileModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: 'mentor',
        email: email,
        profileImageUrl: userData['profileImage'],
        classCount: _classes.length,
        studentCount: uniqueStudentCount,
        activeTasks: calculatedTaskCount,
      );

      _safeNotifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading mentor profile: $e');
    }
  }

  Future<void> _loadStudentProfile(String studentId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(studentId).get();
      if (!userDoc.exists) return;
      final userData = userDoc.data()!;
      final name = userData['name'] ?? 'Student';
      final email = userData['email'] ?? '';
      _classes = await _classroomService.getStudentClasses(studentId);
      _tasks = await _taskService.getStudentTasks(studentId);
      final completedTasks = _tasks.where((t) => t.status == 'completed').length;
      _profileData = ProfileModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: 'student',
        email: email,
        profileImageUrl: userData['profileImage'],
        totalClasses: _classes.length,
        totalTasks: _tasks.length,
        completedTasks: completedTasks,
        completionPercentage: _tasks.isEmpty ? 0 : ((completedTasks / _tasks.length) * 100).round(),
      );
      _safeNotifyListeners();
    } catch (e) { debugPrint('Error: $e'); }
  }

  Future<bool> joinClass(String classCode) async {
    try {
      final uid = _localStorage.getUid();
      final userData = _localStorage.getUserData();
      if (uid == null || userData == null) return false;
      final name = userData['name'] ?? 'Student';
      final email = userData['email'] ?? '';
      final classModel = await _classroomService.getClassByCode(classCode);
      if (classModel == null) return false;
      final success = await _classroomService.addStudentToClass(
        classId: classModel.id,
        studentId: uid,
        studentName: name,
        studentEmail: email,
      );
      if (success) { await _loadFromFirestore(); return true; }
      return false;
    } catch (e) { return false; }
  }

  Future<bool> leaveClass(String classId) async {
    try {
      final uid = _localStorage.getUid();
      if (uid == null) return false;
      final success = await _classroomService.removeStudentFromClass(classId: classId, studentId: uid);
      if (success) {
        _classes.removeWhere((c) => c.id == classId);
        _tasks.removeWhere((t) => t.classId == classId);
        final completedTasks = _tasks.where((t) => t.status == 'completed').length;
        _profileData = _profileData?.copyWith(
          totalClasses: _classes.length,
          totalTasks: _tasks.length,
          completedTasks: completedTasks,
        );
        await _localStorage.saveStudentClasses(_classes.map((c) => c.toMap()).toList());
        _safeNotifyListeners();
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  Future<bool> deleteClass(String classId) async {
    try {
      final uid = _localStorage.getUid();
      if (uid == null) return false;
      final success = await _classroomService.deleteClass(classId, uid);
      if (success) {
        _classes.removeWhere((c) => c.id == classId);
        await _localStorage.removeClass(classId);
        await _loadFromFirestore();
        return true;
      }
      return false;
    } catch (e) { return false; }
  }

  Future<void> logout(BuildContext context) async {
    try {
      debugPrint('🚪 Starting logout process...');

      // Token sil
      final uid = _localStorage.getUid();
      if (uid != null) {
        await FCMService().deleteToken(uid); // ← YENİ
      }

      await _auth.signOut();
      debugPrint('✅ Firebase logout successful');

      await _localStorage.clearAll();
      debugPrint('✅ Local storage cleared');

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Signin()),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error during logout: $e');
      await _localStorage.clearAll();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Signin()),
              (route) => false,
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
    _isDisposed = true;
    super.dispose();
  }
}