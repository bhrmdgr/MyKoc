// lib/pages/communication/chat_room/chat_room_view_model.dart
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

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserImageUrl;

  String? get currentUserId => _currentUserId;

  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  bool _isDisposed = false;

  Map<String, dynamic>? _chatRoomData;
  Map<String, dynamic>? get chatRoomData => _chatRoomData;

  // Chat room ID'sini sakla
  String? _currentChatRoomId;

  void initialize(String chatRoomId, {String? otherUserName, String? otherUserImageUrl}) {
    _currentUserId = _localStorage.getUid();
    final userData = _localStorage.getUserData();
    _currentUserName = userData?['name'] ?? 'User';
    _currentUserImageUrl = userData?['profileImage'];

    // Chat room ID'sini sakla
    _currentChatRoomId = chatRoomId;

    // YENİ: userId parametresi ile mesajları dinle (deletedAt filtresi için)
    _listenToMessages(chatRoomId, _currentUserId!);
    _markMessagesAsRead(chatRoomId);
    _loadChatRoomData(chatRoomId, otherUserName: otherUserName, otherUserImageUrl: otherUserImageUrl);
  }

  Future<void> _loadChatRoomData(String chatRoomId, {String? otherUserName, String? otherUserImageUrl}) async {
    try {
      // Temporary ID ise gerçek chat room henüz yok
      if (chatRoomId.startsWith('direct_')) {
        // Temporary ID formatı: direct_{userId1}_{userId2}
        final parts = chatRoomId.split('_');
        String? otherUserId;
        String? otherUserRole;

        if (parts.length >= 3) {
          final id1 = parts[1];
          final id2 = parts[2];

          // Karşı tarafın ID'sini bul
          otherUserId = (_currentUserId == id1) ? id2 : id1;

          // Role bilgisini Firestore'dan al
          try {
            final userDoc = await _messagingService.getUserProfile(otherUserId);
            otherUserRole = userDoc?['role'] as String?;
          } catch (e) {
            debugPrint('⚠️ Could not fetch user role: $e');
            otherUserRole = null;
          }
        }

        _chatRoomData = {
          'id': chatRoomId,
          'type': 'direct',
          'isTemporary': true,
          'otherUserName': otherUserName,
          'otherUserImageUrl': otherUserImageUrl,
          'participantIds': [_currentUserId, otherUserId],
          'participantDetails': {
            if (otherUserId != null)
              otherUserId: {
                'name': otherUserName ?? 'User',
                'imageUrl': otherUserImageUrl,
                'role': otherUserRole ?? 'student', // Default student
              }
          },
        };
        if (!_isDisposed) {
          notifyListeners();
        }
        return;
      }

      _chatRoomData = await _messagingService.getChatRoomData(chatRoomId);
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error loading chat room data: $e');
    }
  }

  void _listenToMessages(String chatRoomId, String userId) {
    _messagesSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    if (!_isDisposed) notifyListeners();

    _messagesSubscription = _messagingService
        .getChatMessages(chatRoomId, userId) // ← YENİ: userId parametresi eklendi
        .listen(
          (messages) {
        if (_isDisposed) return;

        _messages = messages;
        _isLoading = false;
        _errorMessage = null;
        if (!_isDisposed) notifyListeners();
      },
      onError: (error) {
        if (_isDisposed) return;

        debugPrint('❌ Messages listen error: $error');
        _errorMessage = "Failed to load messages: $error";
        _isLoading = false;
        if (!_isDisposed) notifyListeners();
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
    required String messageText,
    File? file,
  }) async {
    if (_currentUserId == null || _currentUserName == null) return false;
    if (messageText.trim().isEmpty && file == null) return false;
    if (_isDisposed) return false;
    if (_currentChatRoomId == null) return false;

    _isSending = true;
    if (!_isDisposed) notifyListeners();

    try {
      String? mentorId, mentorName, mentorImageUrl;
      String? studentId, studentName, studentImageUrl;

      if (_currentChatRoomId!.startsWith('direct_')) {
        // Temporary ID formatı: direct_{mentorId}_{studentId}
        final parts = _currentChatRoomId!.split('_');
        if (parts.length >= 3) {
          mentorId = parts[1];
          studentId = parts[2];

          final currentUserRole = _localStorage.getUserRole();
          final userData = _localStorage.getUserData();

          if (currentUserRole == 'mentor') {
            mentorName = userData?['name'] ?? 'Mentor';
            mentorImageUrl = userData?['profileImage'];
            if (_chatRoomData != null && _chatRoomData!['otherUserName'] != null) {
              studentName = _chatRoomData!['otherUserName'];
              studentImageUrl = _chatRoomData!['otherUserImageUrl'];
            } else {
              studentName = 'Student';
            }
          } else {
            studentName = userData?['name'] ?? 'Student';
            studentImageUrl = userData?['profileImage'];
            if (_chatRoomData != null && _chatRoomData!['otherUserName'] != null) {
              mentorName = _chatRoomData!['otherUserName'];
              mentorImageUrl = _chatRoomData!['otherUserImageUrl'];
            } else {
              mentorName = 'Mentor';
            }
          }
        }
      }

      // sendMessage artık gerçek chat room ID'sini döndürüyor
      final realChatRoomId = await _messagingService.sendMessage(
        chatRoomId: _currentChatRoomId!,
        senderId: _currentUserId!,
        senderName: _currentUserName!,
        senderImageUrl: _currentUserImageUrl,
        messageText: messageText.trim(),
        file: file,
        mentorId: mentorId,
        mentorName: mentorName,
        mentorImageUrl: mentorImageUrl,
        studentId: studentId,
        studentName: studentName,
        studentImageUrl: studentImageUrl,
      );

      if (realChatRoomId != null) {
        // Eğer chat room ID değiştiyse (temporary → gerçek) listener'ı güncelle
        if (realChatRoomId != _currentChatRoomId) {
          debugPrint('🔄 Switching from temporary to real chat room: $_currentChatRoomId → $realChatRoomId');
          _currentChatRoomId = realChatRoomId;
          _listenToMessages(realChatRoomId, _currentUserId!);
          _loadChatRoomData(realChatRoomId);
        }
        return true;
      }

      return false;
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