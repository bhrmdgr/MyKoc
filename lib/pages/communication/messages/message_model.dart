// lib/pages/communication/messages/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatRoomModel {
  final String id;
  final String name;
  final String type;
  final List<String> participantIds;
  final Map<String, dynamic> participantDetails;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? imageUrl;
  final Map<String, int> unreadCount;

  ChatRoomModel({
    required this.id,
    required this.name,
    required this.type,
    required this.participantIds,
    required this.participantDetails,
    this.lastMessage,
    this.lastMessageTime,
    this.imageUrl,
    this.unreadCount = const {},
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime? lastMessageTime;

    // Timestamp kontrolü
    if (data['lastMessageTime'] != null) {
      if (data['lastMessageTime'] is Timestamp) {
        lastMessageTime = (data['lastMessageTime'] as Timestamp).toDate();
      } else {
        lastMessageTime = DateTime.now();
      }
    }

    Map<String, int> unreadCount = {};
    if (data['unreadCount'] != null && data['unreadCount'] is Map) {
      final rawMap = data['unreadCount'] as Map;
      unreadCount = rawMap.map((key, value) =>
          MapEntry(key.toString(), (value is int) ? value : 0)
      );
    }

    return ChatRoomModel(
      id: doc.id,
      name: data['name'] ?? 'Chat',
      type: data['type'] ?? 'direct',
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantDetails: Map<String, dynamic>.from(data['participantDetails'] ?? {}),
      lastMessage: data['lastMessage'],
      lastMessageTime: lastMessageTime,
      imageUrl: data['imageUrl'],
      unreadCount: unreadCount,
    );
  }

  int getUnreadCountForUser(String userId) {
    return unreadCount[userId] ?? 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'participantIds': participantIds,
      'participantDetails': participantDetails,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'imageUrl': imageUrl,
      'unreadCount': unreadCount,
    };
  }
}

class MessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderImageUrl;
  final String? text;
  final DateTime timestamp;
  final String? fileUrl;
  final String? fileType;
  final String? fileName;
  final List<String> readBy;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderImageUrl,
    this.text,
    required this.timestamp,
    this.fileUrl,
    this.fileType,
    this.fileName,
    this.readBy = const [],
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Timestamp kontrolü
    DateTime timestamp;
    if (data['timestamp'] == null) {
      timestamp = DateTime.now();
    } else if (data['timestamp'] is Timestamp) {
      timestamp = (data['timestamp'] as Timestamp).toDate();
    } else {
      timestamp = DateTime.now();
    }

    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderImageUrl: data['senderImageUrl'],

      // DÜZELTME BURADA YAPILDI:
      // Veritabanında 'messageText' olarak kayıtlı, 'text' değil.
      text: data['messageText'] ?? data['text'], // Her iki ihtimali de kontrol eder

      timestamp: timestamp,
      fileUrl: data['fileUrl'],
      fileType: data['fileType'],
      fileName: data['fileName'],
      readBy: List<String>.from(data['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,

      // Yazarken de tutarlı olması için 'messageText' kullanıyoruz
      'messageText': text,

      'timestamp': Timestamp.fromDate(timestamp),
      'fileUrl': fileUrl,
      'fileType': fileType,
      'fileName': fileName,
      'readBy': readBy,
    };
  }
}