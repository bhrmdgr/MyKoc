import 'package:flutter/material.dart';
import 'package:mykoc/pages/communication/messages/message_model.dart';
import 'package:mykoc/firebase/messaging/messaging_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'dart:io';
import 'dart:async';

class ChatRoomViewModel extends ChangeNotifier {
  final MessagingService _messagingService = MessagingService();
  final LocalStorageService _localStorage = LocalStorageService();

  List<MessageModel> _messages = [];
  List<MessageModel> get messages => _messages;

  // Yükleme ve Hata Durumları
  bool _isLoading = true; // Başlangıçta true olsun
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserImageUrl;

  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  bool _isDisposed = false;

  void initialize(String chatRoomId) {
    _currentUserId = _localStorage.getUid();
    final userData = _localStorage.getUserData();
    _currentUserName = userData?['name'] ?? 'User';
    _currentUserImageUrl = userData?['profileImage'];

    _listenToMessages(chatRoomId);
    _markMessagesAsRead(chatRoomId);
  }

  void _listenToMessages(String chatRoomId) {
    _messagesSubscription?.cancel();
    _isLoading = true; // Yükleme başladı
    _errorMessage = null; // Hata sıfırla
    notifyListeners();

    _messagesSubscription = _messagingService
        .getChatMessages(chatRoomId)
        .listen(
          (messages) {
        if (_isDisposed) return;

        _messages = messages;
        _isLoading = false; // Yükleme bitti
        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        if (_isDisposed) return;

        debugPrint('❌ Messages listen error: $error');
        _errorMessage = "Mesajlar yüklenemedi: $error";
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _markMessagesAsRead(String chatRoomId) async {
    if (_currentUserId != null) {
      try {
        await _messagingService.markMessagesAsRead(chatRoomId, _currentUserId!);
      } catch (e) {
        debugPrint("Read status error: $e");
      }
    }
  }

  Future<bool> sendMessage({
    required String chatRoomId,
    required String messageText,
    File? file,
  }) async {
    if (_currentUserId == null || _currentUserName == null) return false;
    if (messageText.trim().isEmpty && file == null) return false;
    if (_isDisposed) return false;

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
    } catch (e) {
      debugPrint("Send message error: $e");
      return false;
    } finally {
      if (!_isDisposed) {
        _isSending = false;
        notifyListeners();
      }
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

  @override
  void dispose() {
    _isDisposed = true;
    _messagesSubscription?.cancel();
    super.dispose();
  }
}