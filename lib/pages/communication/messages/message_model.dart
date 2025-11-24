// lib/pages/communication/messages/message_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String senderName;
  final String? senderImageUrl;
  final String messageText;
  final String? fileUrl;
  final String? fileName;
  final String? fileType; // 'image', 'document', 'video'
  final DateTime timestamp;
  final List<String> readBy;
  final bool isDeleted;

  MessageModel({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.senderName,
    this.senderImageUrl,
    required this.messageText,
    this.fileUrl,
    this.fileName,
    this.fileType,
    required this.timestamp,
    required this.readBy,
    this.isDeleted = false,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      chatRoomId: data['chatRoomId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderImageUrl: data['senderImageUrl'],
      messageText: data['messageText'] ?? '',
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
      fileType: data['fileType'],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      readBy: List<String>.from(data['readBy'] ?? []),
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatRoomId': chatRoomId,
      'senderId': senderId,
      'senderName': senderName,
      'senderImageUrl': senderImageUrl,
      'messageText': messageText,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': readBy,
      'isDeleted': isDeleted,
    };
  }
}

class ChatRoomModel {
  final String id;
  final String name;
  final String? emoji;
  final String? imageUrl;
  final String type; // 'class_group', 'direct'
  final String? classId;
  final List<String> participantIds;
  final Map<String, dynamic> participantDetails; // uid -> {name, imageUrl}
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, int> unreadCount; // uid -> count
  final DateTime createdAt;

  ChatRoomModel({
    required this.id,
    required this.name,
    this.emoji,
    this.imageUrl,
    required this.type,
    this.classId,
    required this.participantIds,
    required this.participantDetails,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.unreadCount,
    required this.createdAt,
  });

  factory ChatRoomModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatRoomModel(
      id: doc.id,
      name: data['name'] ?? '',
      emoji: data['emoji'],
      imageUrl: data['imageUrl'],
      type: data['type'] ?? 'direct',
      classId: data['classId'],
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantDetails: Map<String, dynamic>.from(data['participantDetails'] ?? {}),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp).toDate(),
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'emoji': emoji,
      'imageUrl': imageUrl,
      'type': type,
      'classId': classId,
      'participantIds': participantIds,
      'participantDetails': participantDetails,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  int getUnreadCountForUser(String userId) {
    return unreadCount[userId] ?? 0;
  }
}