// lib/pages/communication/chat_room/chat_room_view_model.dart
import 'package:flutter/material.dart';
import 'package:mykoc/pages/communication/messages/message_model.dart';
import 'package:mykoc/firebase/messaging/messaging_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'dart:io';

class ChatRoomViewModel extends ChangeNotifier {
  final MessagingService _messagingService = MessagingService();
  final LocalStorageService _localStorage = LocalStorageService();

  List<MessageModel> _messages = [];
  List<MessageModel> get messages => _messages;

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserImageUrl;

  void initialize(String chatRoomId) {
    _currentUserId = _localStorage.getUid();
    final userData = _localStorage.getUserData();
    _currentUserName = userData?['name'] ?? 'User';
    _currentUserImageUrl = userData?['profileImage'];

    _listenToMessages(chatRoomId);
    _markMessagesAsRead(chatRoomId);
  }

  void _listenToMessages(String chatRoomId) {
    _messagingService.getChatMessages(chatRoomId).listen((messages) {
      _messages = messages;
      notifyListeners();
    });
  }

  Future<void> _markMessagesAsRead(String chatRoomId) async {
    if (_currentUserId != null) {
      await _messagingService.markMessagesAsRead(chatRoomId, _currentUserId!);
    }
  }

  Future<bool> sendMessage({
    required String chatRoomId,
    required String messageText,
    File? file,
  }) async {
    if (_currentUserId == null || _currentUserName == null) return false;
    if (messageText.trim().isEmpty && file == null) return false;

    _isSending = true;
    notifyListeners();

    try {
      final success = await _messagingService.sendMessage(
        chatRoomId: chatRoomId,
        senderId: _currentUserId!,
        senderName: _currentUserName!,
        senderImageUrl: _currentUserImageUrl,
        messageText: messageText.trim(),
        file: file,
      );

      return success;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  bool isMyMessage(MessageModel message) {
    return message.senderId == _currentUserId;
  }

  String getMessageTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  bool shouldShowDateHeader(int index) {
    if (index >= _messages.length - 1) return true;

    final currentMessage = _messages[index];
    final nextMessage = _messages[index + 1];

    final currentDate = DateTime(
      currentMessage.timestamp.year,
      currentMessage.timestamp.month,
      currentMessage.timestamp.day,
    );

    final nextDate = DateTime(
      nextMessage.timestamp.year,
      nextMessage.timestamp.month,
      nextMessage.timestamp.day,
    );

    return currentDate != nextDate;
  }
}