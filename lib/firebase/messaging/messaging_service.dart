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
  Future<String?> createDirectChatRoom({
    required String mentorId,
    required String mentorName,
    String? mentorImageUrl,
    required String studentId,
    required String studentName,
    String? studentImageUrl,
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

      // Yeni oda oluştur
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
      });

      debugPrint('✅ Direct chat room created: ${chatRoom.id}');
      return chatRoom.id;
    } catch (e) {
      debugPrint('❌ Error creating direct chat room: $e');
      return null;
    }
  }

  /// Mesaj gönder
  Future<bool> sendMessage({
    required String chatRoomId,
    required String senderId,
    required String senderName,
    String? senderImageUrl,
    required String messageText,
    File? file,
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
          return false;
        }
      }

      // Mesajı kaydet
      await _firestore
          .collection('chatRooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'chatRoomId': chatRoomId,
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
          .doc(chatRoomId)
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

      await _firestore.collection('chatRooms').doc(chatRoomId).update({
        'lastMessage': lastMessagePreview,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCount': unreadCount,
      });

      debugPrint('✅ Message sent');
      return true;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return false;
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

  /// Kullanıcının chat roomlarını getir
  Stream<List<ChatRoomModel>> getUserChatRooms(String userId) {
    return _firestore
        .collection('chatRooms')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => ChatRoomModel.fromFirestore(doc))
        .toList());
  }

  /// Chat room mesajlarını getir
  Stream<List<MessageModel>> getChatMessages(String chatRoomId) {
    return _firestore
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => MessageModel.fromFirestore(doc))
        .toList());
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