import 'package:flutter/material.dart';

class HomeViewModel extends ChangeNotifier {
  // User data
  String _userName = 'Kullanıcı';
  String get userName => _userName;

  // Loading state
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Sessions data
  List<Map<String, String>> _upcomingSessions = [];
  List<Map<String, String>> get upcomingSessions => _upcomingSessions;

  // Load user data
  Future<void> loadUserData() async {
    _setLoading(true);

    try {
      // TODO: API çağrısı yapılacak
      // Simüle edilmiş veri yükleme
      await Future.delayed(const Duration(seconds: 1));

      _userName = 'Mehmet Kaya';
      _upcomingSessions = [
        {
          'mentorName': 'Ahmet Yılmaz',
          'subject': 'Flutter Geliştirme',
          'date': '18 Kasım, 14:00',
        },
        {
          'mentorName': 'Ayşe Demir',
          'subject': 'Kariyer Danışmanlığı',
          'date': '20 Kasım, 16:30',
        },
      ];

      notifyListeners();
    } catch (e) {
      debugPrint('Veri yükleme hatası: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}