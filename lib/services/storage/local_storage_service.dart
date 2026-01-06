import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cihaz hafızası yönetimi servisi
/// IOS ve Android için SharedPreferences kullanır
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  SharedPreferences? _prefs;

  // Storage Keys
  static const String _keyUid = 'user_uid';
  static const String _keyEmail = 'user_email';
  static const String _keyToken = 'auth_token';
  static const String _keyUserData = 'user_data';
  static const String _keyMentorData = 'mentor_data';
  static const String _keyStudentData = 'student_data';
  static const String _keySettings = 'app_settings';
  static const String _keyLastSync = 'last_sync_time';
  static const String _keyNotificationsEnabled = 'notifications_enabled'; // ✅ Eklendi

  /// Initialize storage
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    if (kDebugMode) {
      print('✅ LocalStorage başlatıldı: ${Platform.operatingSystem}');
    }
  }

  // ==================== HASSAS VERİLER (UID, Email, Token) ====================

  /// UID kaydet
  Future<void> saveUid(String uid) async {
    await _prefs?.setString(_keyUid, uid);
    if (kDebugMode) print('✅ UID kaydedildi: ${Platform.operatingSystem}');
  }

  /// UID oku
  String? getUid() {
    final uid = _prefs?.getString(_keyUid);
    if (kDebugMode && uid != null) {
      print('📖 UID okundu: ${Platform.operatingSystem}');
    }
    return uid;
  }

  /// Email kaydet
  Future<void> saveEmail(String email) async {
    await _prefs?.setString(_keyEmail, email);
    if (kDebugMode) print('✅ Email kaydedildi: ${Platform.operatingSystem}');
  }

  /// Email oku
  String? getEmail() {
    return _prefs?.getString(_keyEmail);
  }

  /// Token kaydet
  Future<void> saveToken(String token) async {
    await _prefs?.setString(_keyToken, token);
    if (kDebugMode) print('✅ Token kaydedildi: ${Platform.operatingSystem}');
  }

  /// Token oku
  String? getToken() {
    return _prefs?.getString(_keyToken);
  }

  // ==================== KULLANICI VERİLERİ ====================

  /// Kullanıcı verilerini kaydet
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    final jsonString = jsonEncode(userData);
    await _prefs?.setString(_keyUserData, jsonString);
    await _updateLastSyncTime();
    if (kDebugMode) print('✅ User data kaydedildi: ${Platform.operatingSystem}');
  }

  /// Kullanıcı verilerini oku
  Map<String, dynamic>? getUserData() {
    final jsonString = _prefs?.getString(_keyUserData);
    if (jsonString == null) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  // ==================== MENTÖR VERİLERİ ====================

  /// Mentör verilerini kaydet
  Future<void> saveMentorData(Map<String, dynamic> mentorData) async {
    final jsonString = jsonEncode(mentorData);
    await _prefs?.setString(_keyMentorData, jsonString);
    await _updateLastSyncTime();
    if (kDebugMode) print('✅ Mentor data kaydedildi: ${Platform.operatingSystem}');
  }

  /// Mentör verilerini oku
  Map<String, dynamic>? getMentorData() {
    final jsonString = _prefs?.getString(_keyMentorData);
    if (jsonString == null) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  // ==================== ÖĞRENCİ VERİLERİ ====================

  /// Öğrenci verilerini kaydet
  Future<void> saveStudentData(Map<String, dynamic> studentData) async {
    final jsonString = jsonEncode(studentData);
    await _prefs?.setString(_keyStudentData, jsonString);
    await _updateLastSyncTime();
    if (kDebugMode) print('✅ Student data kaydedildi: ${Platform.operatingSystem}');
  }

  /// Öğrenci verilerini oku
  Map<String, dynamic>? getStudentData() {
    final jsonString = _prefs?.getString(_keyStudentData);
    if (jsonString == null) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  // ==================== CLASS VERİLERİ ====================

  static const String _keyClassesList = 'classes_list';
  static const String _keyClassPrefix = 'class_';

  /// Tüm sınıfları kaydet (Mentör için)
  Future<void> saveClassesList(List<Map<String, dynamic>> classes) async {
    final jsonString = jsonEncode(classes);
    await _prefs?.setString(_keyClassesList, jsonString);
    await _updateLastSyncTime();
    if (kDebugMode) print('✅ Classes list kaydedildi: ${classes.length} sınıf');
  }

  /// Tüm sınıfları oku (Mentör için)
  List<Map<String, dynamic>>? getClassesList() {
    final jsonString = _prefs?.getString(_keyClassesList);
    if (jsonString == null) return null;
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Tek bir sınıfı kaydet
  Future<void> saveClass(String classId, Map<String, dynamic> classData) async {
    final jsonString = jsonEncode(classData);
    await _prefs?.setString('$_keyClassPrefix$classId', jsonString);
    if (kDebugMode) print('✅ Class kaydedildi: $classId');
  }

  /// Tek bir sınıfı oku
  Map<String, dynamic>? getClass(String classId) {
    final jsonString = _prefs?.getString('$_keyClassPrefix$classId');
    if (jsonString == null) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Bir sınıfı sil
  Future<void> removeClass(String classId) async {
    await _prefs?.remove('$_keyClassPrefix$classId');
    if (kDebugMode) print('🗑️ Class silindi: $classId');
  }

  /// Tüm sınıfları sil
  Future<void> clearAllClasses() async {
    await _prefs?.remove(_keyClassesList);
    // Tüm class_ ile başlayan key'leri sil
    final keys = _prefs?.getKeys() ?? {};
    for (var key in keys) {
      if (key.startsWith(_keyClassPrefix)) {
        await _prefs?.remove(key);
      }
    }
    if (kDebugMode) print('🗑️ Tüm classes temizlendi');
  }

  /// Öğrencinin sınıflarını kaydet (Artık birden fazla sınıf olabilir)
  Future<void> saveStudentClasses(List<Map<String, dynamic>> classes) async {
    final jsonString = jsonEncode(classes);
    await _prefs?.setString('student_classes', jsonString);
    if (kDebugMode) print('✅ Student classes kaydedildi: ${classes.length} sınıf');
  }

  /// Öğrencinin sınıflarını oku
  List<Map<String, dynamic>>? getStudentClasses() {
    final jsonString = _prefs?.getString('student_classes');
    if (jsonString == null) return null;
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Aktif sınıf ID'sini kaydet
  Future<void> saveActiveClassId(String classId) async {
    await _prefs?.setString('active_class_id', classId);
    if (kDebugMode) print('✅ Active class ID kaydedildi: $classId');
  }

  /// Aktif sınıf ID'sini oku
  String? getActiveClassId() {
    return _prefs?.getString('active_class_id');
  }

  /// Öğrencinin sınıfını kaydet (Backward compatibility için)
  Future<void> saveStudentClass(Map<String, dynamic> classData) async {
    // Tek sınıf kaydedildiğinde liste olarak kaydet
    final existingClasses = getStudentClasses() ?? [];
    // Eğer bu sınıf listede yoksa ekle
    if (!existingClasses.any((c) => c['id'] == classData['id'])) {
      existingClasses.add(classData);
      await saveStudentClasses(existingClasses);
    }
    await saveActiveClassId(classData['id']);
  }

  /// Öğrencinin sınıfını oku (Backward compatibility için)
  Map<String, dynamic>? getStudentClass() {
    final classes = getStudentClasses();
    if (classes == null || classes.isEmpty) return null;
    return classes.first;
  }

  // ==================== CLASS STUDENTS ====================

  static const String _keyClassStudentsPrefix = 'class_students_';

  /// Sınıf öğrencilerini kaydet
  Future<void> saveClassStudents(String classId, List<Map<String, dynamic>> students) async {
    final jsonString = jsonEncode(students);
    await _prefs?.setString('$_keyClassStudentsPrefix$classId', jsonString);
    if (kDebugMode) print('✅ Class students kaydedildi: $classId (${students.length} öğrenci)');
  }

  /// Sınıf öğrencilerini oku
  List<Map<String, dynamic>>? getClassStudents(String classId) {
    final jsonString = _prefs?.getString('$_keyClassStudentsPrefix$classId');
    if (jsonString == null) return null;
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Bir sınıfın öğrencilerini sil
  Future<void> removeClassStudents(String classId) async {
    await _prefs?.remove('$_keyClassStudentsPrefix$classId');
    if (kDebugMode) print('🗑️ Class students silindi: $classId');
  }

  // ==================== CLASS ANNOUNCEMENTS ====================

  static const String _keyClassAnnouncementsPrefix = 'class_announcements_';

  /// Sınıf duyurularını kaydet
  Future<void> saveClassAnnouncements(String classId, List<Map<String, dynamic>> announcements) async {
    final jsonString = jsonEncode(announcements);
    await _prefs?.setString('$_keyClassAnnouncementsPrefix$classId', jsonString);
    if (kDebugMode) print('✅ Class announcements kaydedildi: $classId (${announcements.length} duyuru)');
  }

  /// Sınıf duyurularını oku
  List<Map<String, dynamic>>? getClassAnnouncements(String classId) {
    final jsonString = _prefs?.getString('$_keyClassAnnouncementsPrefix$classId');
    if (jsonString == null) return null;
    final List<dynamic> decoded = jsonDecode(jsonString);
    return decoded.map((e) => e as Map<String, dynamic>).toList();
  }

  /// Bir sınıfın duyurularını sil
  Future<void> removeClassAnnouncements(String classId) async {
    await _prefs?.remove('$_keyClassAnnouncementsPrefix$classId');
    if (kDebugMode) print('🗑️ Class announcements silindi: $classId');
  }

  // ==================== UYGULAMA AYARLARI ====================

  /// Uygulama ayarlarını kaydet
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final jsonString = jsonEncode(settings);
    await _prefs?.setString(_keySettings, jsonString);
    if (kDebugMode) print('✅ Settings kaydedildi');
  }

  /// Uygulama ayarlarını oku
  Map<String, dynamic>? getSettings() {
    final jsonString = _prefs?.getString(_keySettings);
    if (jsonString == null) return null;
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Son senkronizasyon zamanını güncelle
  Future<void> _updateLastSyncTime() async {
    await _prefs?.setString(_keyLastSync, DateTime.now().toIso8601String());
  }

  /// Son senkronizasyon zamanını oku
  DateTime? getLastSyncTime() {
    final timeString = _prefs?.getString(_keyLastSync);
    if (timeString == null) return null;
    return DateTime.parse(timeString);
  }

  /// Bildirim tercihini kaydet (✅ Eklendi)
  Future<void> saveNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool(_keyNotificationsEnabled, enabled);
    if (kDebugMode) print('✅ Bildirim tercihi kaydedildi: $enabled');
  }

  /// Bildirim tercihini oku (✅ Eklendi)
  bool? getNotificationsEnabled() {
    return _prefs?.getBool(_keyNotificationsEnabled);
  }

  // ==================== HELPER METHODS ====================

  /// Platform kontrolü
  bool isIOS() => Platform.isIOS;
  bool isAndroid() => Platform.isAndroid;

  /// Kullanıcı giriş yapmış mı kontrolü
  bool isUserLoggedIn() {
    final uid = getUid();
    return uid != null && uid.isNotEmpty;
  }

  /// Kullanıcı rolünü al
  String? getUserRole() {
    final userData = getUserData();
    return userData?['role'];
  }

  /// Kullanıcı adını al
  String? getUserName() {
    final userData = getUserData();
    return userData?['name'];
  }

  /// Profil fotoğrafı URL'sini al
  String? getProfileImageUrl() {
    final userData = getUserData();
    return userData?['profileImage'];
  }

  /// Kullanıcı mentör mü kontrolü
  bool isMentor() {
    return getUserRole() == 'mentor';
  }

  /// Kullanıcı öğrenci mi kontrolü
  bool isStudent() {
    return getUserRole() == 'student';
  }

  /// Mentör subscription tier'ını al
  String? getMentorSubscriptionTier() {
    final mentorData = getMentorData();
    return mentorData?['subscriptionTier'];
  }

  /// Mentör maksimum sınıf sayısını al
  int? getMentorMaxClasses() {
    final mentorData = getMentorData();
    return mentorData?['maxClasses'];
  }

  /// Mentör maksimum öğrenci sayısını al
  int? getMentorMaxStudentsPerClass() {
    final mentorData = getMentorData();
    return mentorData?['maxStudentsPerClass'];
  }

  //================TAKVİM İŞLEMLERİ===================

  static const String _keyCalendarNotes = 'calendar_notes_cache';

  /// Takvim notlarını kaydet (Map olarak tüm listeyi tutar)
  Future<void> saveCalendarNotes(Map<String, dynamic> notesMap) async {
    final jsonString = jsonEncode(notesMap);
    await _prefs?.setString(_keyCalendarNotes, jsonString);
    if (kDebugMode) print('✅ Calendar notes cached locally');
  }

  /// Takvim notlarını oku
  Map<String, dynamic> getCalendarNotes() {
    final jsonString = _prefs?.getString(_keyCalendarNotes);
    if (jsonString == null) return {};
    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  // ==================== TEMİZLEME İŞLEMLERİ ====================

  /// Tüm kullanıcı verilerini temizle (Logout)
  Future<void> clearAllUserData() async {
    await _prefs?.remove(_keyUid);
    await _prefs?.remove(_keyEmail);
    await _prefs?.remove(_keyToken);
    await _prefs?.remove(_keyUserData);
    await _prefs?.remove(_keyMentorData);
    await _prefs?.remove(_keyStudentData);
    await _prefs?.remove(_keyLastSync);

    if (kDebugMode) {
      print('🗑️ Tüm kullanıcı verileri silindi: ${Platform.operatingSystem}');
    }
  }

  /// Sadece cache'i temizle (ayarlar kalır)
  Future<void> clearCache() async {
    await _prefs?.remove(_keyUserData);
    await _prefs?.remove(_keyMentorData);
    await _prefs?.remove(_keyStudentData);
    await _prefs?.remove(_keyLastSync);

    if (kDebugMode) {
      print('🗑️ Cache temizlendi: ${Platform.operatingSystem}');
    }
  }

  /// Tüm verileri temizle (Factory reset)
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      debugPrint('✅ Local storage cleared');
    } catch (e) {
      debugPrint('❌ Error clearing local storage: $e');
    }
  }

  // ==================== DEBUG ====================

  /// Tüm kayıtlı verileri logla (Debug için)
  void debugPrintAllData() {
    if (!kDebugMode) return;

    print('========== LOCAL STORAGE DEBUG ==========');
    print('Platform: ${Platform.operatingSystem}');
    print('UID: ${getUid()}');
    print('Email: ${getEmail()}');
    print('Token: ${getToken()}');
    print('User Data: ${getUserData()}');
    print('Mentor Data: ${getMentorData()}');
    print('Student Data: ${getStudentData()}');
    print('Settings: ${getSettings()}');
    print('Last Sync: ${getLastSyncTime()}');
    print('=========================================');
  }
}