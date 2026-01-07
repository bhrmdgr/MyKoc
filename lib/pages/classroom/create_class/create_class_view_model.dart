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

  // Kullanıcının premium olup olmadığını kontrol eder
  bool get isPremium {
    final mentorData = _localStorage.getMentorData();
    return mentorData?['subscriptionTier'] == 'premium';
  }

  // Maksimum sınıf limitini döner (UI bilgilendirmesi için)
  int get maxClassLimit {
    final mentorData = _localStorage.getMentorData();
    return mentorData?['maxClasses'] ?? 1;
  }

  // Hata mesajlarını UI'da göstermek için (Opsiyonel)
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

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
    'Career Coaching',
    'Exam Prep',
    'Personal Development',
    'Entrepreneurship',
    'Psychology',
    'Marketing',
    'Study Techniques',
    'Project Management',
    'Public Speaking',
    'Soft Skills',
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
    _errorMessage = null;
    notifyListeners();

    try {
      final uid = _localStorage.getUid();
      final userData = _localStorage.getUserData();

      if (uid == null || userData == null) {
        throw 'User not found';
      }

      final mentorName = userData['name'] ?? 'Unknown';

      // Service kullanarak sınıf oluştur (Limit kontrolü artık servis içinde yapılıyor)
      final classId = await _classroomService.createClass(
        mentorId: uid,
        mentorName: mentorName,
        className: classNameController.text.trim(),
        classType: _selectedClassType,
        emoji: _selectedEmoji,
      );

      if (classId != null) {
        // Yeni sınıf verisini modelleyerek local'e ekle
        final newClassMap = {
          'id': classId,
          'mentorId': uid,
          'mentorName': mentorName,
          'className': classNameController.text.trim(),
          'classType': _selectedClassType,
          'emoji': _selectedEmoji,
          'imageUrl': null,
          'classCode': '...', // Gerekiyorsa servisten dönen koda göre güncellenebilir
          'studentCount': 0,
          'taskCount': 0,
          'createdAt': DateTime.now().toIso8601String(),
        };

        // Mevcut listeye ekle ve kaydet
        final currentClasses = _localStorage.getClassesList() ?? [];
        currentClasses.insert(0, newClassMap);
        await _localStorage.saveClassesList(currentClasses);

        debugPrint('✅ Yeni sınıf local ve uzak sunucuya başarıyla kaydedildi.');
        return true;
      }

      return false;
    } catch (e) {
      // Servis katmanından gelen spesifik limit hatasını yakalıyoruz
      if (e.toString().contains('LIMIT_REACHED')) {
        _errorMessage = 'LIMIT_REACHED';
        debugPrint('⚠️ Kullanıcı sınıf limitine ulaştı.');
      } else {
        _errorMessage = e.toString();
        debugPrint('❌ Create class error: $e');
      }
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