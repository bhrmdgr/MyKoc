// lib/firebase/messaging/messaging_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mykoc/pages/communication/messages/message_model.dart';
import 'dart:io';
import 'package:mykoc/firebase/storage/storage_service.dart';

class MessagingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StorageService _storageService = StorageService();

  /// Sınıf grubu oluştur (sınıf oluşturulduğunda otomatik çağrılacak)
  Future<String?> createClassChatRoom({
    required String classId,
    required String className,
    required String mentorId,
    required String mentorName,
    String? emoji,
    String? imageUrl,
  }) async {
    try {
      final chatRoom = await _firestore.collection('chatRooms').add({
        'name': className,
        'emoji': emoji,
        'imageUrl': imageUrl,
        'type': 'class_group',
        'classId': classId,
        'participantIds': [mentorId],
        'participantDetails': {
          mentorId: {
            'name': mentorName,
            'imageUrl': null,
            'role': 'mentor',
          }
        },
        'lastMessage': 'Chat room created',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': mentorId,
        'unreadCount': {},
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Class chat room created: ${chatRoom.id}');
      return chatRoom.id;
    } catch (e) {
      debugPrint('❌ Error creating class chat room: $e');
      return null;
    }
  }

  /// Öğrenciyi sınıf grubuna ekle
  Future<bool> addStudentToChatRoom({
    required String chatRoomId,
    required String studentId,
    required String studentName,
    String? studentImageUrl,
  }) async {
    try {
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'participantIds': FieldValue.arrayUnion([studentId]),
        'participantDetails.$studentId': {
          'name': studentName,
          'imageUrl': studentImageUrl,
          'role': 'student',
        },
      });

      debugPrint('✅ Student added to chat room');
      return true;
    } catch (e) {
      debugPrint('❌ Error adding student to chat room: $e');
      return false;
    }
  }

  /// Direkt mesajlaşma odası oluştur (mentor-student)
  /// NOT: Bu sadece chat room ID'sini döndürür, gerçek oluşturma ilk mesajda olur
  Future<String?> getOrCreateDirectChatRoomId({
    required String mentorId,
    required String studentId,
  }) async {
    try {
      // Önce var olan odayı kontrol et
      final existingRoom = await _firestore
          .collection('chatRooms')
          .where('type', isEqualTo: 'direct')
          .where('participantIds', arrayContains: mentorId)
          .get();

      for (var doc in existingRoom.docs) {
        final participants = List<String>.from(doc.data()['participantIds']);
        if (participants.contains(studentId)) {
          debugPrint('✅ Direct chat room already exists: ${doc.id}');
          return doc.id;
        }
      }

      // Yeni bir temporary ID oluştur (gerçek oluşturma ilk mesajda olacak)
      // Format: direct_{mentorId}_{studentId}
      final tempChatRoomId = 'direct_${mentorId}_$studentId';
      debugPrint('✅ Temporary chat room ID created: $tempChatRoomId');
      return tempChatRoomId;
    } catch (e) {
      debugPrint('❌ Error getting/creating direct chat room: $e');
      return null;
    }
  }

  /// Chat room'u gerçekten oluştur (ilk mesaj gönderilirken)
  Future<String?> _ensureDirectChatRoomExists({
    required String chatRoomId,
    required String mentorId,
    required String mentorName,
    String? mentorImageUrl,
    required String studentId,
    required String studentName,
    String? studentImageUrl,
  }) async {
    try {
      // Eğer temporary ID ise gerçek chat room oluştur
      if (chatRoomId.startsWith('direct_')) {
        // ÖNCE VAR OLAN CHAT ROOM'U KONTROL ET
        final existingRoom = await _firestore
            .collection('chatRooms')
            .where('type', isEqualTo: 'direct')
            .where('participantIds', arrayContains: mentorId)
            .get();

        for (var doc in existingRoom.docs) {
          final participants = List<String>.from(doc.data()['participantIds']);
          if (participants.contains(studentId)) {
            debugPrint('✅ Found existing direct chat room: ${doc.id}');
            return doc.id;
          }
        }

        // Yoksa yeni oluştur
        final chatRoom = await _firestore.collection('chatRooms').add({
          'name': '$mentorName & $studentName',
          'type': 'direct',
          'participantIds': [mentorId, studentId],
          'participantDetails': {
            mentorId: {
              'name': mentorName,
              'imageUrl': mentorImageUrl,
              'role': 'mentor',
            },
            studentId: {
              'name': studentName,
              'imageUrl': studentImageUrl,
              'role': 'student',
            },
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': '',
          'unreadCount': {mentorId: 0, studentId: 0},
          'createdAt': FieldValue.serverTimestamp(),
          'hiddenFor': [], // Silinme kontrolü için
          'deletedAt': {}, // WhatsApp tarzı silme için
        });

        debugPrint('✅ Direct chat room created: ${chatRoom.id}');
        return chatRoom.id;
      }

      // Zaten gerçek bir ID ise doğrudan döndür
      return chatRoomId;
    } catch (e) {
      debugPrint('❌ Error ensuring chat room exists: $e');
      return null;
    }
  }

  /// Mesaj gönder (WhatsApp tarzı deletedAt temizleme ile)
  /// Gerçek chat room ID'sini döndürür (temporary ID'den farklı olabilir)
  Future<String?> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    String? senderImageUrl,
    required String messageText,
    File? file,
    String? mentorId,
    String? mentorName,
    String? mentorImageUrl,
    String? studentId,
    String? studentName,
    String? studentImageUrl,
  }) async {
    try {
      String? fileUrl;
      String? fileName;
      String? fileType;

      // Dosya varsa yükle
      if (file != null) {
        final extension = file.path.split('.').last.toLowerCase();
        fileType = _getFileType(extension);
        fileName = file.path.split('/').last;

        fileUrl = await _storageService.uploadFile(
          file: file,
          path: 'chat_files/$chatRoomId',
        );

        if (fileUrl == null) {
          debugPrint('❌ File upload failed');
          return null;
        }
      }

      // Eğer temporary chat room ise gerçek chat room oluştur
      String? realChatRoomId = chatRoomId;
      if (chatRoomId.startsWith('direct_') &&
          mentorId != null && studentId != null &&
          mentorName != null && studentName != null) {
        realChatRoomId = await _ensureDirectChatRoomExists(
          chatRoomId: chatRoomId,
          mentorId: mentorId,
          mentorName: mentorName,
          mentorImageUrl: mentorImageUrl,
          studentId: studentId,
          studentName: studentName,
          studentImageUrl: studentImageUrl,
        );

        if (realChatRoomId == null) {
          debugPrint('❌ Failed to create chat room');
          return null;
        }

        debugPrint('✅ Temporary ID: $chatRoomId → Real ID: $realChatRoomId');
      }

      // Mesajı kaydet
      await _firestore
          .collection('chatRooms')
          .doc(realChatRoomId)
          .collection('messages')
          .add({
        'chatRoomId': realChatRoomId,
        'senderId': senderId,
        'senderName': senderName,
        'senderImageUrl': senderImageUrl,
        'messageText': messageText,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileType': fileType,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [senderId],
        'isDeleted': false,
      });

      // Chat room'u güncelle
      final chatRoomDoc = await _firestore
          .collection('chatRooms')
          .doc(realChatRoomId)
          .get();

      final participants = List<String>.from(
          chatRoomDoc.data()?['participantIds'] ?? []
      );

      final unreadCount = Map<String, int>.from(
          chatRoomDoc.data()?['unreadCount'] ?? {}
      );

      // Gönderen hariç herkesin unread count'unu artır
      for (var participantId in participants) {
        if (participantId != senderId) {
          unreadCount[participantId] = (unreadCount[participantId] ?? 0) + 1;
        }
      }

      final lastMessagePreview = fileUrl != null
          ? '📎 ${fileName ?? 'File'}'
          : messageText;

      // Chat room güncelleme
      final updateData = {
        'lastMessage': lastMessagePreview,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount': unreadCount,
        'hiddenFor': FieldValue.arrayRemove([senderId]), // Gönderen için tekrar görünür yap
        'deletedAt.$senderId': FieldValue.delete(), // ← YENİ: Gönderenin timestamp'ini sil
      };

      await _firestore.collection('chatRooms').doc(realChatRoomId).update(updateData);

      debugPrint('✅ Message sent and deletedAt cleared for sender');
      return realChatRoomId; // ← YENİ: Gerçek chat room ID'sini döndür
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return null;
    }
  }

  /// Mesajları okundu olarak işaretle
  Future<void> markMessagesAsRead(String chatRoomId, String userId) async {
    try {
      final unreadMessages = await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('senderId', isNotEqualTo: userId)
          .get();

      final batch = _firestore.batch();

      for (var doc in unreadMessages.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(userId)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([userId]),
          });
        }
      }

      // Unread count'u sıfırla
      batch.update(_firestore.collection('chatRooms').doc(chatRoomId), {
        'unreadCount.$userId': 0,
      });

      await batch.commit();
      debugPrint('✅ Messages marked as read');
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
    }
  }

  /// Kullanıcının chat roomlarını getir (hiddenFor kontrolü ile)
  Stream<List<ChatRoomModel>> getUserChatRooms(String userId) {
    return _firestore
        .collection('chatRooms')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      // hiddenFor listesinde olmayan chat room'ları filtrele
      return snapshot.docs
          .where((doc) {
        final data = doc.data();
        final hiddenFor = List<String>.from(data['hiddenFor'] ?? []);
        return !hiddenFor.contains(userId);
      })
          .map((doc) => ChatRoomModel.fromFirestore(doc))
          .toList();
    });
  }

  /// Chat room mesajlarını getir (WhatsApp tarzı deletedAt filtresi ile)
  Stream<List<MessageModel>> getChatMessages(String chatRoomId, String userId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .snapshots()
        .asyncExpand((chatRoomSnapshot) {
      if (!chatRoomSnapshot.exists) {
        return Stream.value([]);
      }

      final chatRoomData = chatRoomSnapshot.data()!;
      final deletedAtMap = chatRoomData['deletedAt'] as Map<String, dynamic>?;

      // Kullanıcının silme timestamp'ini al
      Timestamp? deletedAtTimestamp;
      if (deletedAtMap != null && deletedAtMap.containsKey(userId)) {
        deletedAtTimestamp = deletedAtMap[userId] as Timestamp?;
      }

      // Mesajları çek
      Query query = _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(50);

      // Eğer kullanıcı silme yapmışsa, sadece o tarihten sonraki mesajları getir
      if (deletedAtTimestamp != null) {
        query = query.where('timestamp', isGreaterThan: deletedAtTimestamp);
        debugPrint('🔍 Filtering messages after: ${deletedAtTimestamp.toDate()}');
      }

      return query.snapshots().map((snapshot) =>
          snapshot.docs.map((doc) => MessageModel.fromFirestore(doc)).toList());
    });
  }

  /// Sınıf ID'sine göre chat room'u bul
  Future<String?> getChatRoomIdByClassId(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('chatRooms')
          .where('classId', isEqualTo: classId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      return snapshot.docs.first.id;
    } catch (e) {
      debugPrint('❌ Error finding chat room: $e');
      return null;
    }
  }

  /// Sınıf bilgisini al (öğrenci mentor bilgisi için)
  Future<Map<String, dynamic>?> getClassById(String classId) async {
    try {
      final doc = await _firestore.collection('classes').doc(classId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('❌ Error getting class: $e');
      return null;
    }
  }

  /// Kullanıcı profil bilgisini al
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('❌ Error getting user profile: $e');
      return null;
    }
  }

  /// Sınıf öğrencilerini al
  Future<List<Map<String, dynamic>>> getClassStudents(String classId) async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where('classId', isEqualTo: classId)
          .get();

      List<Map<String, dynamic>> students = [];

      for (var doc in snapshot.docs) {
        final studentData = doc.data();
        final userId = studentData['userId'] as String?;

        if (userId != null) {
          // User bilgisini de al
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data()!;
            students.add({
              'id': userId,
              'name': userData['name'] ?? 'Student',
              'email': userData['email'] ?? '',
              'profileImage': userData['profileImage'],
              'classId': classId,
            });
          }
        }
      }

      return students;
    } catch (e) {
      debugPrint('❌ Error getting class students: $e');
      return [];
    }
  }

  /// Chat room'u kullanıcı için sil (WhatsApp tarzı - timestamp ile)
  Future<bool> hideChatRoomForUser(String chatRoomId, String userId) async {
    try {
      // deletedAt timestamp'i kaydet
      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'deletedAt.$userId': FieldValue.serverTimestamp(),
        'unreadCount.$userId': 0,
        'hiddenFor': FieldValue.arrayUnion([userId]),
      });

      debugPrint('✅ Chat deleted for user: $userId with timestamp');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting chat for user: $e');
      return false;
    }
  }

  /// Chat room bilgilerini getir
  Future<Map<String, dynamic>?> getChatRoomData(String chatRoomId) async {
    try {
      final doc = await _firestore.collection('chatRooms').doc(chatRoomId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      debugPrint('❌ Error getting chat room data: $e');
      return null;
    }
  }

  String _getFileType(String extension) {
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      return 'image';
    } else if (['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'].contains(extension)) {
      return 'document';
    } else if (['mp4', 'mov', 'avi'].contains(extension)) {
      return 'video';
    }
    return 'file';
  }
}