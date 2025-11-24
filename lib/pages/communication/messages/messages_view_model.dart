// lib/pages/communication/messages/messages_view_model.dart
import 'package:flutter/material.dart';
import 'package:mykoc/pages/communication/messages/message_model.dart';
import 'package:mykoc/firebase/messaging/messaging_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';
import 'dart:async';

class MessagesViewModel extends ChangeNotifier {
  final MessagingService _messagingService = MessagingService();
  final LocalStorageService _localStorage = LocalStorageService();

  List<ChatRoomModel> _chatRooms = [];
  List<ChatRoomModel> get chatRooms => _chatRooms;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _currentUserId;
  String? _currentUserRole;

  String? get currentUserId => _currentUserId;

  StreamSubscription<List<ChatRoomModel>>? _chatRoomsSubscription;

  // DÜZELTME: Dispose kontrolü
  bool _isDisposed = false;

  void initialize() {
    _currentUserId = _localStorage.getUid();
    _currentUserRole = _localStorage.getUserRole();

    if (_currentUserId != null) {
      _listenToChatRooms();
    }
  }

  void _listenToChatRooms() {
    // Sayfa kapalıysa işlem yapma
    if (_isDisposed) return;

    _isLoading = true;
    notifyListeners();

    _chatRoomsSubscription?.cancel();

    _chatRoomsSubscription = _messagingService
        .getUserChatRooms(_currentUserId!)
        .listen(
          (rooms) {
        // DÜZELTME: Veri geldiğinde sayfa hala açık mı kontrol et
        if (_isDisposed) return;

        _chatRooms = rooms;
        _isLoading = false;
        notifyListeners();
      },
      onError: (error) {
        if (_isDisposed) return;

        debugPrint('❌ Chat rooms listen error: $error');
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Direkt mesaj odası aç
  Future<String?> openDirectChat({
    required String otherUserId,
    required String otherUserName,
    String? otherUserImageUrl,
  }) async {
    final userData = _localStorage.getUserData();
    final currentUserName = userData?['name'] ?? 'User';
    final currentUserImageUrl = userData?['profileImage'];

    if (_currentUserRole == 'mentor') {
      return await _messagingService.createDirectChatRoom(
        mentorId: _currentUserId!,
        mentorName: currentUserName,
        mentorImageUrl: currentUserImageUrl,
        studentId: otherUserId,
        studentName: otherUserName,
        studentImageUrl: otherUserImageUrl,
      );
    } else {
      return await _messagingService.createDirectChatRoom(
        mentorId: otherUserId,
        mentorName: otherUserName,
        mentorImageUrl: otherUserImageUrl,
        studentId: _currentUserId!,
        studentName: currentUserName,
        studentImageUrl: currentUserImageUrl,
      );
    }
  }

  /// Sınıf grubunu aç
  Future<String?> openClassChat(String classId) async {
    return await _messagingService.getChatRoomIdByClassId(classId);
  }

  String getOtherParticipantName(ChatRoomModel chatRoom) {
    if (chatRoom.type == 'class_group') {
      return chatRoom.name;
    }

    for (var participantId in chatRoom.participantIds) {
      if (participantId != _currentUserId) {
        return chatRoom.participantDetails[participantId]?['name'] ?? 'User';
      }
    }
    return 'Chat';
  }

  String? getOtherParticipantImage(ChatRoomModel chatRoom) {
    if (chatRoom.type == 'class_group') {
      return chatRoom.imageUrl;
    }

    for (var participantId in chatRoom.participantIds) {
      if (participantId != _currentUserId) {
        return chatRoom.participantDetails[participantId]?['imageUrl'];
      }
    }
    return null;
  }

  String getOtherParticipantInitials(ChatRoomModel chatRoom) {
    final name = getOtherParticipantName(chatRoom);
    final parts = name.split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  String getRelativeTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'No messages yet';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _chatRoomsSubscription?.cancel();
    super.dispose();
  }
}