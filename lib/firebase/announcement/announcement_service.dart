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

      // Local cache'i güncelle
      await _refreshLocalCache(classId);

      // 🔔 BİLDİRİM GÖNDER
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

  /// Bildirim gönder
  Future<void> _sendAnnouncementNotification({
    required String classId,
    required String announcementId,
    required String title,
    required String description,
  }) async {
    try {
      // Sınıf bilgilerini al
      final classDoc = await _firestore.collection('classes').doc(classId).get();
      if (!classDoc.exists) {
        debugPrint('⚠️ Class not found for notification');
        return;
      }

      final className = classDoc.data()?['className'] ?? 'Your Class';

      debugPrint('📤 Sending announcement notification...');

      // FCM Service ile bildirim gönder
      final success = await _fcmService.sendAnnouncementNotification(
        classId: classId,
        className: className,
        title: title,
        description: description,
        announcementId: announcementId,
      );

      if (success) {
        debugPrint('✅ Announcement notification sent successfully');
      } else {
        debugPrint('⚠️ Failed to send announcement notification');
      }
    } catch (e) {
      debugPrint('❌ Error sending announcement notification: $e');
    }
  }

  /// Sınıfın duyurularını çek
  Future<List<AnnouncementModel>> getClassAnnouncements(String classId) async {
    try {
      debugPrint('🔍 Fetching announcements for class: $classId');

      final snapshot = await _firestore
          .collection('announcements')
          .where('classId', isEqualTo: classId)
          .orderBy('createdAt', descending: true)
          .get();

      debugPrint('📊 Firestore query result: ${snapshot.docs.length} announcements');

      final announcements = snapshot.docs
          .map((doc) => AnnouncementModel.fromFirestore(doc))
          .toList();

      // Cache'e kaydet
      await _localStorage.saveClassAnnouncements(
        classId,
        announcements.map((a) => a.toLocalMap()).toList(),
      );
      debugPrint('💾 Announcements cached locally');

      return announcements;
    } catch (e) {
      debugPrint('❌ Error fetching class announcements: $e');
      return [];
    }
  }

  /// Tek bir duyuruyu ID'ye göre çek
  Future<AnnouncementModel?> getAnnouncementById(String announcementId) async {
    try {
      final doc = await _firestore.collection('announcements').doc(announcementId).get();

      if (!doc.exists) return null;

      return AnnouncementModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ Error fetching announcement: $e');
      return null;
    }
  }

  /// Duyuruyu güncelle
  Future<bool> updateAnnouncement({
    required String announcementId,
    required String classId,
    String? title,
    String? description,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;

      await _firestore.collection('announcements').doc(announcementId).update(updates);

      debugPrint('✅ Announcement updated successfully');

      // Local cache'i güncelle
      await _refreshLocalCache(classId);

      return true;
    } catch (e) {
      debugPrint('❌ Error updating announcement: $e');
      return false;
    }
  }

  /// Duyuruyu sil
  Future<bool> deleteAnnouncement(String announcementId, String classId) async {
    try {
      await _firestore.collection('announcements').doc(announcementId).delete();

      debugPrint('✅ Announcement deleted successfully');

      // Local cache'i güncelle
      await _refreshLocalCache(classId);

      return true;
    } catch (e) {
      debugPrint('❌ Error deleting announcement: $e');
      return false;
    }
  }

  /// Local cache'i güncelle
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

  /// Stream: Duyuruları gerçek zamanlı dinle
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