// lib/pages/communication/messages/messages_view_model.dart
import 'package:easy_localization/easy_localization.dart'; // ← EKLENDİ
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
  String? get currentUserRole => _currentUserRole;

  StreamSubscription<List<ChatRoomModel>>? _chatRoomsSubscription;

  // Dispose kontrolü
  bool _isDisposed = false;

  void initialize() {
    _currentUserId = _localStorage.getUid();
    _currentUserRole = _localStorage.getUserRole();

    if (_currentUserId != null) {
      _listenToChatRooms();

      // Sadece öğrenci için otomatik mentor ile direkt mesaj oluştur
      if (_currentUserRole == 'student') {
        _ensureStudentMentorChat();
      }
    }
  }

  void _listenToChatRooms() {
    // Önce dispose kontrolü
    if (_isDisposed) {
      debugPrint('⚠️ ViewModel already disposed, skipping listener');
      return;
    }

    _isLoading = true;
    _safeNotifyListeners();

    _chatRoomsSubscription?.cancel();

    _chatRoomsSubscription = _messagingService
        .getUserChatRooms(_currentUserId!)
        .listen(
          (rooms) {
        // Veri geldiğinde tekrar kontrol et
        if (_isDisposed) {
          debugPrint('⚠️ Data received after dispose, ignoring');
          return;
        }

        _chatRooms = rooms;
        _isLoading = false;
        _safeNotifyListeners();
      },
      onError: (error) {
        if (_isDisposed) return;

        debugPrint('❌ Chat rooms listen error: $error');
        _isLoading = false;
        _safeNotifyListeners();
      },
    );
  }

  // Helper metod
  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Öğrenci için mentor ile otomatik direkt mesajlaşma oluştur
  Future<void> _ensureStudentMentorChat() async {
    try {
      final studentClasses = _localStorage.getStudentClasses();
      if (studentClasses == null || studentClasses.isEmpty) {
        debugPrint('❌ Student has no classes');
        return;
      }

      // İlk sınıfın mentorü ile chat oluştur
      final activeClassId = _localStorage.getActiveClassId();
      Map<String, dynamic>? targetClass;

      if (activeClassId != null) {
        targetClass = studentClasses.firstWhere(
              (c) => c['id'] == activeClassId,
          orElse: () => studentClasses.first,
        );
      } else {
        targetClass = studentClasses.first;
      }

      final mentorId = targetClass['mentorId'] as String?;

      if (mentorId == null || _currentUserId == null) {
        debugPrint('❌ Mentor info not found');
        return;
      }

      // Sadece ID oluştur, gerçek chat room ilk mesajda oluşacak
      await _messagingService.getOrCreateDirectChatRoomId(
        mentorId: mentorId,
        studentId: _currentUserId!,
      );

      debugPrint('✅ Student-mentor chat ID ensured');
    } catch (e) {
      debugPrint('❌ Error ensuring student-mentor chat: $e');
    }
  }

  /// Direkt mesaj odası aç
  Future<String?> openDirectChat({
    required String otherUserId,
    required String otherUserName,
    String? otherUserImageUrl,
  }) async {
    final userData = _localStorage.getUserData();
    final currentUserName = userData?['name'] ?? 'user_placeholder'.tr(); // ← GÜNCELLENDİ
    final currentUserImageUrl = userData?['profileImage'];

    String mentorId, mentorName, studentId, studentName;
    String? mentorImageUrl, studentImageUrl;

    if (_currentUserRole == 'mentor') {
      mentorId = _currentUserId!;
      mentorName = currentUserName;
      mentorImageUrl = currentUserImageUrl;
      studentId = otherUserId;
      studentName = otherUserName;
      studentImageUrl = otherUserImageUrl;
    } else {
      mentorId = otherUserId;
      mentorName = otherUserName;
      mentorImageUrl = otherUserImageUrl;
      studentId = _currentUserId!;
      studentName = currentUserName;
      studentImageUrl = currentUserImageUrl;
    }

    return await _messagingService.getOrCreateDirectChatRoomId(
      mentorId: mentorId,
      studentId: studentId,
    );
  }

  /// Sınıf grubunu aç
  Future<String?> openClassChat(String classId) async {
    return await _messagingService.getChatRoomIdByClassId(classId);
  }

  /// Mentor için öğrenci listesini al
  Future<List<Map<String, dynamic>>> getMentorStudents() async {
    if (_currentUserRole != 'mentor') return [];

    try {
      final mentorClasses = _localStorage.getClassesList();
      if (mentorClasses == null || mentorClasses.isEmpty) {
        return [];
      }

      List<Map<String, dynamic>> allStudents = [];
      Set<String> addedStudentIds = {};

      for (var classData in mentorClasses) {
        final classId = classData['id'] as String?;
        if (classId == null) continue;

        final students = await _messagingService.getClassStudents(classId);

        for (var student in students) {
          final studentId = student['id'] as String?;
          if (studentId != null && !addedStudentIds.contains(studentId)) {
            allStudents.add(student);
            addedStudentIds.add(studentId);
          }
        }
      }

      debugPrint('✅ Found ${allStudents.length} unique students');
      return allStudents;
    } catch (e) {
      debugPrint('❌ Error getting mentor students: $e');
      return [];
    }
  }

  String getOtherParticipantName(ChatRoomModel chatRoom) {
    if (chatRoom.type == 'class_group') {
      return chatRoom.name;
    }

    for (var participantId in chatRoom.participantIds) {
      if (participantId != _currentUserId) {
        return chatRoom.participantDetails[participantId]?['name'] ?? 'user_placeholder'.tr(); // ← GÜNCELLENDİ
      }
    }
    return 'chat_placeholder'.tr(); // ← GÜNCELLENDİ
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
      return 'no_messages_yet'.tr(); // ← GÜNCELLENDİ
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just_now'.tr(); // ← GÜNCELLENDİ
    } else if (difference.inMinutes < 60) {
      return 'minutes_ago'.tr(args: [difference.inMinutes.toString()]); // ← GÜNCELLENDİ
    } else if (difference.inHours < 24) {
      return 'hours_ago'.tr(args: [difference.inHours.toString()]); // ← GÜNCELLENDİ
    } else if (difference.inDays == 1) {
      return 'yesterday'.tr(); // ← GÜNCELLENDİ
    } else if (difference.inDays < 7) {
      return 'days_ago'.tr(args: [difference.inDays.toString()]); // ← GÜNCELLENDİ
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  /// Chat room'u sil (herkes kendi direkt mesajlarını silebilir)
  Future<bool> deleteChatRoom(String chatRoomId, String chatRoomType) async {
    // Sadece direkt mesajlar silinebilir
    if (chatRoomType != 'direct') {
      debugPrint('❌ Only direct chats can be deleted');
      return false;
    }

    try {
      final success = await _messagingService.hideChatRoomForUser(
        chatRoomId,
        _currentUserId!,
      );
      if (success) {
        debugPrint('✅ Chat room hidden');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error hiding chat room: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _chatRoomsSubscription?.cancel();
    super.dispose();
  }
}