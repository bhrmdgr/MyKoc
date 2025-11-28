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
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _isSending = false;
  bool get isSending => _isSending;

  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserImageUrl;

  // Public getters
  String? get currentUserId => _currentUserId;

  StreamSubscription<List<MessageModel>>? _messagesSubscription;
  bool _isDisposed = false;

  // Chat room bilgileri
  Map<String, dynamic>? _chatRoomData;
  Map<String, dynamic>? get chatRoomData => _chatRoomData;

  void initialize(String chatRoomId, {String? otherUserName, String? otherUserImageUrl}) {
    _currentUserId = _localStorage.getUid();
    final userData = _localStorage.getUserData();
    _currentUserName = userData?['name'] ?? 'User';
    _currentUserImageUrl = userData?['profileImage'];

    _listenToMessages(chatRoomId);
    _markMessagesAsRead(chatRoomId);
    _loadChatRoomData(chatRoomId, otherUserName: otherUserName, otherUserImageUrl: otherUserImageUrl);
  }

  /// Chat room bilgilerini yükle
  Future<void> _loadChatRoomData(String chatRoomId, {String? otherUserName, String? otherUserImageUrl}) async {
    try {
      // Temporary ID ise gerçek chat room henüz yok
      if (chatRoomId.startsWith('direct_')) {
        _chatRoomData = {
          'id': chatRoomId,
          'type': 'direct',
          'isTemporary': true,
          'otherUserName': otherUserName,
          'otherUserImageUrl': otherUserImageUrl,
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

  void _listenToMessages(String chatRoomId) {
    _messagesSubscription?.cancel();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _messagesSubscription = _messagingService
        .getChatMessages(chatRoomId)
        .listen(
          (messages) {
        if (_isDisposed) return;

        _messages = messages;
        _isLoading = false;
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
      // Participant bilgilerini hazırla (temporary chat için gerekli)
      String? mentorId, mentorName, mentorImageUrl;
      String? studentId, studentName, studentImageUrl;

      if (chatRoomId.startsWith('direct_')) {
        // Temporary ID formatı: direct_{mentorId}_{studentId}
        final parts = chatRoomId.split('_');
        if (parts.length >= 3) {
          mentorId = parts[1];
          studentId = parts[2];

          // Kullanıcı bilgilerini al
          final currentUserRole = _localStorage.getUserRole();
          final userData = _localStorage.getUserData();

          if (currentUserRole == 'mentor') {
            mentorName = userData?['name'] ?? 'Mentor';
            mentorImageUrl = userData?['profileImage'];
            // Student bilgisini chat room data'dan al (eğer varsa)
            if (_chatRoomData != null && _chatRoomData!['otherUserName'] != null) {
              studentName = _chatRoomData!['otherUserName'];
              studentImageUrl = _chatRoomData!['otherUserImageUrl'];
            } else {
              studentName = 'Student';
            }
          } else {
            studentName = userData?['name'] ?? 'Student';
            studentImageUrl = userData?['profileImage'];
            // Mentor bilgisini chat room data'dan al (eğer varsa)
            if (_chatRoomData != null && _chatRoomData!['otherUserName'] != null) {
              mentorName = _chatRoomData!['otherUserName'];
              mentorImageUrl = _chatRoomData!['otherUserImageUrl'];
            } else {
              mentorName = 'Mentor';
            }
          }
        }
      }

      final success = await _messagingService.sendMessage(
        chatRoomId: chatRoomId,
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

      // İlk mesajdan sonra chat room data'yı yeniden yükle
      if (success && chatRoomId.startsWith('direct_')) {
        await Future.delayed(const Duration(milliseconds: 500));
        // Yeni oluşturulan gerçek chat room ID'sini bul
        // Bu durumda chat room listesi otomatik güncellenecek
      }

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