import 'package:flutter/material.dart';
import 'package:mykoc/firebase/classroom/classroom_service.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class CreateClassViewModel extends ChangeNotifier {
  final ClassroomService _classroomService = ClassroomService();
  final LocalStorageService _localStorage = LocalStorageService();

  final TextEditingController classNameController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _selectedEmoji = '📚';
  String get selectedEmoji => _selectedEmoji;

  String _selectedClassType = 'Mathematics';
  String get selectedClassType => _selectedClassType;

  final List<String> availableEmojis = [
    '📚', '📖', '✏️', '📝', '🎨', '🎭', '🎵', '🎸',
    '🔬', '🧪', '🧬', '💻', '🖥️', '📱', '🌍', '🌎',
    '⚽', '🏀', '🎾', '🏐', '🎯', '🎲', '🎮', '🎪',
  ];

  final List<String> classTypes = [
    'Mathematics',
    'Science',
    'Literature',
    'History',
    'Art',
    'Music',
    'Programming',
    'Design',
    'Physics',
    'Chemistry',
    'Biology',
    'Language',
    'Economics',
    'Philosophy',
  ];

  void setEmoji(String emoji) {
    _selectedEmoji = emoji;
    notifyListeners();
  }

  void setClassType(String type) {
    _selectedClassType = type;
    notifyListeners();
  }

  Future<bool> createClass() async {
    _isLoading = true;
    notifyListeners();

    try {
      final uid = _localStorage.getUid();
      final userData = _localStorage.getUserData();

      if (uid == null || userData == null) {
        throw 'User not found';
      }

      final mentorName = userData['name'] ?? 'Unknown';

      // Service kullanarak sınıf oluştur
      final classId = await _classroomService.createClass(
        mentorId: uid,
        mentorName: mentorName,
        className: classNameController.text.trim(),
        classType: _selectedClassType,
        emoji: _selectedEmoji,
      );

      if (classId != null) {
        // Yeni sınıfı local'e ekle
        final newClass = {
          'id': classId,
          'mentorId': uid,
          'mentorName': mentorName,
          'className': classNameController.text.trim(),
          'classType': _selectedClassType,
          'emoji': _selectedEmoji,
          'imageUrl': null,
          'classCode': 'XXXXXX', // TODO: Gerçek kodu al
          'studentCount': 0,
          'taskCount': 0,
          'createdAt': DateTime.now().toIso8601String(),
        };

        // Mevcut listeye ekle
        final currentClasses = _localStorage.getClassesList() ?? [];
        currentClasses.insert(0, newClass);
        await _localStorage.saveClassesList(currentClasses);

        debugPrint('✅ Yeni sınıf local\'e de kaydedildi');
      }

      return classId != null;
    } catch (e) {
      debugPrint('❌ Create class error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    classNameController.dispose();
    super.dispose();
  }
}