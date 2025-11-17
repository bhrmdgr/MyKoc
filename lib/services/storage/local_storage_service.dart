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
    await _prefs?.clear();

    if (kDebugMode) {
      print('🗑️ Tüm veriler silindi: ${Platform.operatingSystem}');
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