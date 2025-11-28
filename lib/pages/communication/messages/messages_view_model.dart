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
  String? get currentUserRole => _currentUserRole;

  StreamSubscription<List<ChatRoomModel>>? _chatRoomsSubscription;

  // DÜZELTME: Dispose kontrolü
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
      // Mentor için otomatik sohbet oluşturma KALDIRILDI
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

  /// Öğrenci için mentor ile otomatik direkt mesajlaşma oluştur
  Future<void> _ensureStudentMentorChat() async {
    try {
      final studentClasses = _localStorage.getStudentClasses();
      if (studentClasses == null || studentClasses.isEmpty) {
        debugPrint('❌ Student has no classes');
        return;
      }

      // İlk sınıfın mentorü ile chat oluştur (multiple class varsa aktif olanı kullan)
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
      final mentorName = targetClass['mentorName'] as String?;

      if (mentorId == null || mentorName == null) {
        debugPrint('❌ Mentor info not found');
        return;
      }

      // Mentor profil resmini al
      String? mentorImageUrl;
      try {
        final mentorDoc = await _messagingService.getUserProfile(mentorId);
        mentorImageUrl = mentorDoc?['profileImage'];
      } catch (e) {
        debugPrint('⚠️ Could not fetch mentor image: $e');
      }

      final userData = _localStorage.getUserData();
      final currentUserName = userData?['name'] ?? 'Student';
      final currentUserImageUrl = userData?['profileImage'];

      await _messagingService.createDirectChatRoom(
        mentorId: mentorId,
        mentorName: mentorName,
        mentorImageUrl: mentorImageUrl,
        studentId: _currentUserId!,
        studentName: currentUserName,
        studentImageUrl: currentUserImageUrl,
      );

      debugPrint('✅ Student-mentor chat ensured');
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

  /// Mentor için öğrenci listesini al (tüm sınıflardan)
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

  /// Chat room'u sil (sadece mentor için direkt mesajlaşmalarda)
  Future<bool> deleteChatRoom(String chatRoomId, String chatRoomType) async {
    // Sadece mentor direkt mesajları silebilir
    if (_currentUserRole != 'mentor' || chatRoomType != 'direct') {
      debugPrint('❌ Only mentor can delete direct chats');
      return false;
    }

    try {
      final success = await _messagingService.deleteChatRoom(chatRoomId);
      if (success) {
        debugPrint('✅ Chat room deleted');
        // Liste otomatik güncellenecek (Stream sayesinde)
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Error deleting chat room: $e');
      return false;
    }
  }

  /// Öğrencinin sohbet durumunu kontrol et (mentor listesi için)
  bool hasExistingChat(String studentId) {
    return _chatRooms.any((room) {
      if (room.type != 'direct') return false;
      return room.participantIds.contains(studentId);
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _chatRoomsSubscription?.cancel();
    super.dispose();
  }
}