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

  // Android Kanal Tanımı
  final AndroidNotificationChannel _channel = const AndroidNotificationChannel(
    'mykoc_channel', // ID: Cloud Functions veya Manuel gönderimle aynı olmalı
    'MyKoc Bildirimleri', // İsim: Ayarlarda görünür
    description: 'Mesaj ve duyuru bildirimleri.', // Açıklama
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    debugPrint('🔔 FCM Service initializing...');

    try {
      // 1. İzin İste
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission granted');
      }

      // 2. Yerel Bildirimleri ve Kanalı Başlat (Android için kritik)
      await _initializeLocalNotifications();

      // 3. iOS için ön planda bildirim görünürlüğü ayarı
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Dinleyicileri Kur
      _setupMessageListeners();

      debugPrint('✅ FCM Service basic setup complete.');
    } catch (e) {
      debugPrint('❌ FCM Service initialize error: $e');
    }
  }

  void _setupMessageListeners() {
    // Ön planda mesaj gelirse
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📲 Foreground message received: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Bildirime tıklanırsa
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationTap(message);
    });

    // Token yenilenirse
    _fcm.onTokenRefresh.listen((token) {
      _fcmToken = token;
      final userId = _localStorage.getUid();
      if (userId != null) {
        saveToken(userId);
      }
    });
  }

  /// Token al ve gerekiyorsa kaydet
  Future<String?> getToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      final userId = _localStorage.getUid();
      if (userId != null && _fcmToken != null) {
        await saveToken(userId);
      }
      return _fcmToken;
    } catch (e) {
      debugPrint('❌ Error getting token: $e');
      return null;
    }
  }

  /// Local notifications ve Kanal kurulumu
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

    // Kanalı Android sistemine kaydet (Kritik!)
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('🔔 Local notification tapped: ${details.payload}');
      },
    );

    debugPrint('✅ Local notifications & Channel initialized');
  }

  /// Foreground'da local notification göster
  Future<void> _showLocalNotification(RemoteMessage message) async {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: _channel.importance,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'];
    debugPrint('🔔 Notification type: $type');
  }

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

  Future<void> deleteToken(String userId) async {
    try {
      await _fcm.deleteToken();
      await _firestore.collection('fcmTokens').doc(userId).delete();
      debugPrint('✅ Token deleted');
    } catch (e) {
      debugPrint('❌ Token delete error: $e');
    }
  }

  Future<bool> sendAnnouncementNotification({
    required String classId,
    required String className,
    required String title,
    required String description,
    required String announcementId,
  }) async {
    try {
      debugPrint('📤 Sending announcement notification to class: $classId');

      final studentsSnapshot = await _firestore
          .collection('students')
          .where('classId', isEqualTo: classId)
          .get();

      if (studentsSnapshot.docs.isEmpty) return false;

      final studentIds = studentsSnapshot.docs
          .map((doc) => doc.data()['userId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toList();

      final tokens = await _getTokensForUsers(studentIds);
      if (tokens.isEmpty) return false;

      debugPrint('✅ Found ${tokens.length} FCM tokens. Production: Use Cloud Functions.');
      return true;
    } catch (e) {
      debugPrint('❌ Error: $e');
      return false;
    }
  }

  Future<List<String>> _getTokensForUsers(List<String> userIds) async {
    try {
      final tokens = <String>[];
      for (final userId in userIds) {
        final doc = await _firestore.collection('fcmTokens').doc(userId).get();
        if (doc.exists) {
          final token = doc.data()?['token'] as String?;
          if (token != null) tokens.add(token);
        }
      }
      return tokens;
    } catch (e) {
      return [];
    }
  }
}