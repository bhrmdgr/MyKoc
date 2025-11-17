import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mykoc/pages/home/homeModel.dart';
import 'package:mykoc/services/storage/local_storage_service.dart';

class HomeViewModel extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalStorageService _localStorage = LocalStorageService();

  HomeModel? _homeData;
  HomeModel? get homeData => _homeData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _loadFromLocalStorage();
      notifyListeners();
      await _loadFromFirestore();
    } catch (e) {
      _errorMessage = 'Veri yüklenirken bir hata oluştu';
      debugPrint('HomeViewModel Error: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadFromLocalStorage() async {
    final userData = _localStorage.getUserData();
    if (userData == null) return;

    final name = userData['name'] ?? 'User';
    final role = userData['role'] ?? 'student';

    _homeData = HomeModel(
      userName: name,
      userInitials: _getInitials(name),
      userRole: role,
      profileImageUrl: userData['profileImage'],
      completedTasks: 1,
      totalTasks: 5,
      upcomingSessions: _getDummySessions(),
    );
  }

  Future<void> _loadFromFirestore() async {
    final uid = _localStorage.getUid();
    if (uid == null) {
      _errorMessage = 'Kullanıcı bulunamadı';
      return;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        _errorMessage = 'Kullanıcı kaydı bulunamadı';
        return;
      }

      final userData = userDoc.data()!;
      final name = userData['name'] ?? 'User';
      final role = userData['role'] ?? 'student';

      // Sessions'ı çekmeye çalış (hata olursa dummy data kullan)
      final sessions = await _fetchUpcomingSessions(uid, role);

      _homeData = HomeModel(
        userName: name,
        userInitials: _getInitials(name),
        userRole: role,
        profileImageUrl: userData['profileImage'],
        completedTasks: 1,
        totalTasks: 5,
        upcomingSessions: sessions,
      );

      // Local storage'ı güncelle (Timestamp'leri String'e çevir)
      final userDataToSave = Map<String, dynamic>.from(userData);
      if (userDataToSave['createdAt'] is Timestamp) {
        userDataToSave['createdAt'] =
            (userDataToSave['createdAt'] as Timestamp).toDate().toIso8601String();
      }

      await _localStorage.saveUserData(userDataToSave);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Veri yüklenirken hata oluştu';
      debugPrint('Error loading from Firestore: $e');
    }
  }

  Future<List<SessionModel>> _fetchUpcomingSessions(String uid, String role) async {
    try {
      // Index hatası olacağını biliyoruz, direkt dummy data dön
      // İleride index oluşturulunca bu kısım aktif edilecek
      return _getDummySessions();

      /* Index oluşturulduktan sonra bu kodu kullan:
      QuerySnapshot snapshot;

      if (role == 'student') {
        snapshot = await _firestore
            .collection('sessions')
            .where('studentId', isEqualTo: uid)
            .where('status', isEqualTo: 'upcoming')
            .orderBy('dateTime', descending: false)
            .limit(5)
            .get();
      } else {
        snapshot = await _firestore
            .collection('sessions')
            .where('mentorId', isEqualTo: uid)
            .where('status', isEqualTo: 'upcoming')
            .orderBy('dateTime', descending: false)
            .limit(5)
            .get();
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return SessionModel(
          id: doc.id,
          mentorName: data['mentorName'] ?? 'Unknown',
          subject: data['subject'] ?? 'No subject',
          dateTime: (data['dateTime'] as Timestamp).toDate(),
          avatar: data['avatar'] ?? '',
          status: data['status'] ?? 'upcoming',
        );
      }).toList();
      */
    } catch (e) {
      debugPrint('Error fetching sessions: $e');
      return _getDummySessions();
    }
  }

  Future<void> refresh() async {
    await _loadFromFirestore();
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  List<SessionModel> _getDummySessions() {
    return [
      SessionModel(
        id: '1',
        mentorName: 'Dr. Sarah Johnson',
        subject: 'Flutter Development',
        dateTime: DateTime.now().add(const Duration(days: 1)),
        avatar: 'SJ',
      ),
      SessionModel(
        id: '2',
        mentorName: 'Prof. Michael Chen',
        subject: 'Career Guidance',
        dateTime: DateTime.now().add(const Duration(days: 3)),
        avatar: 'MC',
      ),
    ];
  }

  @override
  void dispose() {
    super.dispose();
  }
}