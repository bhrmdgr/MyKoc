// lib/firebase/messaging/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

// Background message handler (global scope'ta olmalı)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📲 Background: ${message.notification?.title}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  // Local notifications (foreground'da bildirim göstermek için)
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    debugPrint('🔔 FCM Service initializing...');

    // İzin iste
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('⚠️ Notification permission denied');
      return;
    }

    debugPrint('✅ Notification permission granted');

    // Local notifications başlat
    await _initializeLocalNotifications();

    // FCM token al
    _fcmToken = await _fcm.getToken();
    debugPrint('🔑 FCM Token: $_fcmToken');

    // Token'ı kaydet
    final userId = _localStorage.getUid();
    if (userId != null && _fcmToken != null) {
      await saveToken(userId);
    }

    // Token yenilendiğinde
    _fcm.onTokenRefresh.listen((token) {
      _fcmToken = token;
      debugPrint('🔄 Token refreshed');
      final userId = _localStorage.getUid();
      if (userId != null) {
        saveToken(userId);
      }
    });

    // Foreground mesajları (uygulama açıkken)
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('📲 Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Bildirime tıklandığında (background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('🔔 Notification tapped: ${message.data}');
      _handleNotificationTap(message);
    });

    // Uygulama kapalıyken gelen bildirime tıklandıysa
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 App opened from notification');
      _handleNotificationTap(initialMessage);
    }

    debugPrint('✅ FCM Service initialized');
  }

  /// Local notifications başlat
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('🔔 Local notification tapped: ${details.payload}');
      },
    );

    debugPrint('✅ Local notifications initialized');
  }

  /// Foreground'da local notification göster
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'mykoc_channel',
      'MyKoc Notifications',
      channelDescription: 'Notifications for MyKoc app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title ?? 'MyKoc',
      message.notification?.body ?? '',
      details,
      payload: message.data.toString(),
    );
  }

  /// Bildirime tıklandığında
  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];

    debugPrint('🔔 Notification type: $type');

    // Navigation için implementation eklenecek
    // Örnek:
    // if (type == 'announcement') {
    //   final announcementId = message.data['announcementId'];
    //   NavigationService.navigateTo('/announcement/$announcementId');
    // }
  }

  /// Token'ı Firestore'a kaydet
  Future<void> saveToken(String userId) async {
    if (_fcmToken == null) return;

    try {
      await _firestore.collection('fcmTokens').doc(userId).set({
        'token': _fcmToken,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      }, SetOptions(merge: true));

      debugPrint('✅ Token saved to Firestore');
    } catch (e) {
      debugPrint('❌ Token save error: $e');
    }
  }

  /// Token'ı sil (logout'ta)
  Future<void> deleteToken(String userId) async {
    try {
      await _fcm.deleteToken();
      await _firestore.collection('fcmTokens').doc(userId).delete();
      debugPrint('✅ Token deleted');
    } catch (e) {
      debugPrint('❌ Token delete error: $e');
    }
  }

  /// Sınıftaki tüm öğrencilere duyuru bildirimi gönder
  Future<bool> sendAnnouncementNotification({
    required String classId,
    required String className,
    required String title,
    required String description,
    required String announcementId,
  }) async {
    try {
      debugPrint('📤 Sending announcement notification to class: $classId');

      // Sınıftaki öğrencileri al
      final studentsSnapshot = await _firestore
          .collection('students')
          .where('classId', isEqualTo: classId)
          .get();

      if (studentsSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No students in class');
        return false;
      }

      final studentIds = studentsSnapshot.docs
          .map((doc) => doc.data()['userId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      debugPrint('👥 Found ${studentIds.length} students');

      // Öğrencilerin FCM token'larını al
      final tokens = await _getTokensForUsers(studentIds);

      if (tokens.isEmpty) {
        debugPrint('⚠️ No FCM tokens found');
        return false;
      }

      debugPrint('📲 Found ${tokens.length} FCM tokens');

      // ⚠️ PRODUCTION'DA CLOUD FUNCTIONS KULLANILMALI
      // Şimdilik sadece log'layalım
      debugPrint('✅ Notification data prepared:');
      debugPrint('   Title: $title');
      debugPrint('   Description: $description');
      debugPrint('   Class: $className');
      debugPrint('   Recipients: ${tokens.length}');
      debugPrint('⚠️ Cloud Functions ile gerçek bildirim gönderilecek');

      return true;
    } catch (e) {
      debugPrint('❌ Error sending announcement notification: $e');
      return false;
    }
  }

  /// Kullanıcıların FCM token'larını al
  Future<List<String>> _getTokensForUsers(List<String> userIds) async {
    try {
      final tokens = <String>[];

      for (final userId in userIds) {
        final doc = await _firestore.collection('fcmTokens').doc(userId).get();
        if (doc.exists) {
          final token = doc.data()?['token'] as String?;
          if (token != null) {
            tokens.add(token);
          }
        }
      }

      return tokens;
    } catch (e) {
      debugPrint('❌ Error getting tokens: $e');
      return [];
    }
  }
}