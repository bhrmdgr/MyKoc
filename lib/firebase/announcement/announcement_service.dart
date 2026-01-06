// lib/firebase/announcement/announcement_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mykoc/pages/classroom/class_detail/announcement_model.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'package:mykoc/firebase/messaging/fcm_service.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService();
  final FCMService _fcmService = FCMService();

  /// Duyuru oluştur VE bildirim gönder
  Future<String?> createAnnouncement({
    required String classId,
    required String mentorId,
    required String title,
    required String description,
  }) async {
    try {
      final announcementData = {
        'classId': classId,
        'mentorId': mentorId,
        'title': title,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': null,
      };

      final docRef = await _firestore.collection('announcements').add(announcementData);

      debugPrint('✅ Announcement created: ${docRef.id}');

      await _refreshLocalCache(classId);

      // 🔔 BİLDİRİM TETİKLE (FCMService kullanılarak)
      await _sendAnnouncementNotification(
        classId: classId,
        announcementId: docRef.id,
        title: title,
        description: description,
      );

      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating announcement: $e');
      return null;
    }
  }

  /// Bildirim gönderimi koordinasyonu
  Future<void> _sendAnnouncementNotification({
    required String classId,
    required String announcementId,
    required String title,
    required String description,
  }) async {
    try {
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (!classDoc.exists) return;

      final className = classDoc.data()?['className'] ?? 'Your Class';

      // FCM Service içindeki metodun tetiklenmesi
      await _fcmService.sendAnnouncementNotification(
        classId: classId,
        className: className,
        title: title,
        description: description,
        announcementId: announcementId,
      );
    } catch (e) {
      debugPrint('❌ Error coordinating notification: $e');
    }
  }

  Future<List<AnnouncementModel>> getClassAnnouncements(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('announcements')
          .where('classId', isEqualTo: classId)
          .orderBy('createdAt', descending: true)
          .get();

      final announcements = snapshot.docs
          .map((doc) => AnnouncementModel.fromFirestore(doc))
          .toList();

      await _localStorage.saveClassAnnouncements(
        classId,
        announcements.map((a) => a.toLocalMap()).toList(),
      );

      return announcements;
    } catch (e) {
      return [];
    }
  }

  Future<AnnouncementModel?> getAnnouncementById(String announcementId) async {
    try {
      final doc = await _firestore.collection('announcements').doc(announcementId).get();
      if (!doc.exists) return null;
      return AnnouncementModel.fromFirestore(doc);
    } catch (e) {
      return null;
    }
  }

  Future<bool> updateAnnouncement({
    required String announcementId,
    required String classId,
    String? title,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;

      await _firestore.collection('announcements').doc(announcementId).update(updates);
      await _refreshLocalCache(classId);

      // 🔔 GÜNCELLEME BİLDİRİMİ
      await _sendAnnouncementNotification(
        classId: classId,
        announcementId: announcementId,
        title: 'Güncelleme: ${title ?? "Duyuru"}',
        description: description ?? 'Duyuru içeriği güncellendi.',
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteAnnouncement(String announcementId, String classId) async {
    try {
      await _firestore.collection('announcements').doc(announcementId).delete();
      await _refreshLocalCache(classId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _refreshLocalCache(String classId) async {
    try {
      final announcements = await getClassAnnouncements(classId);
      await _localStorage.saveClassAnnouncements(
        classId,
        announcements.map((a) => a.toLocalMap()).toList(),
      );
    } catch (e) {
      debugPrint('❌ Error refreshing local cache: $e');
    }
  }

  Stream<List<AnnouncementModel>> watchClassAnnouncements(String classId) {
    return _firestore
        .collection('announcements')
        .where('classId', isEqualTo: classId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => AnnouncementModel.fromFirestore(doc))
        .toList());
  }
}