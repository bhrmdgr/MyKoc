// lib/firebase/messaging/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📲 Background: ${message.notification?.title}');
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

    _fcmToken = await _fcm.getToken();
    debugPrint('🔑 FCM Token: $_fcmToken');

    _fcm.onTokenRefresh.listen((token) {
      _fcmToken = token;
      debugPrint('🔄 Token refreshed');
    });

    // FCM otomatik bildirim gösterir, dinlemeye gerek yok
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('📲 Foreground message: ${message.notification?.title}');
    });
  }

  Future<void> saveToken(String userId) async {
    if (_fcmToken == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': _fcmToken,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Token saved');
    } catch (e) {
      debugPrint('❌ Token save error: $e');
    }
  }

  Future<void> deleteToken(String userId) async {
    try {
      await _fcm.deleteToken();
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
      debugPrint('✅ Token deleted');
    } catch (e) {
      debugPrint('❌ Token delete error: $e');
    }
  }
}